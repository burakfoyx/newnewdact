package push

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/xyidactyl/agent/internal/logging"
)

// APNsProvider sends push notifications via Apple Push Notification service.
type APNsProvider struct {
	keyID      string
	teamID     string
	bundleID   string
	privateKey *ecdsa.PrivateKey
	client     *http.Client

	mu       sync.Mutex
	jwtToken string
	jwtExp   time.Time
}

// NewAPNsProvider creates an APNs push provider.
// keyBase64 is the base64-encoded contents of the .p8 file.
func NewAPNsProvider(keyBase64, keyID, teamID, bundleID string) (*APNsProvider, error) {
	keyBytes, err := base64.StdEncoding.DecodeString(keyBase64)
	if err != nil {
		return nil, fmt.Errorf("decode APNs key: %w", err)
	}

	block, _ := pem.Decode(keyBytes)
	if block == nil {
		return nil, fmt.Errorf("failed to parse PEM block")
	}

	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse private key: %w", err)
	}

	ecKey, ok := key.(*ecdsa.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("key is not ECDSA")
	}

	return &APNsProvider{
		keyID:      keyID,
		teamID:     teamID,
		bundleID:   bundleID,
		privateKey: ecKey,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}, nil
}

// Send delivers a push notification via APNs with retry.
func (a *APNsProvider) Send(ctx context.Context, token string, payload Payload) error {
	apnsPayload := map[string]interface{}{
		"aps": map[string]interface{}{
			"alert": map[string]string{
				"title": payload.Title,
				"body":  payload.Body,
			},
			"sound": "default",
		},
		"user_uuid":  payload.UserUUID,
		"server_id":  payload.ServerID,
		"event_type": payload.EventType,
		"timestamp":  payload.Timestamp,
	}

	body, err := json.Marshal(apnsPayload)
	if err != nil {
		return fmt.Errorf("marshal payload: %w", err)
	}

	// Retry with exponential backoff
	delays := []time.Duration{1 * time.Second, 2 * time.Second, 4 * time.Second}
	var lastErr error

	for attempt := 0; attempt <= len(delays); attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(delays[attempt-1]):
			}
		}

		statusCode, err := a.sendOnce(ctx, token, body)
		if err != nil {
			lastErr = err
			logging.Warn("APNs attempt %d failed: %v", attempt+1, err)
			continue
		}

		if statusCode == http.StatusOK {
			return nil
		}

		if statusCode == http.StatusGone {
			truncLen := len(token)
			if truncLen > 16 {
				truncLen = 16
			}
			logging.Info("APNs token invalid (410 Gone), should remove: %s...", token[:truncLen])
			return fmt.Errorf("token invalid (410)")
		}

		if statusCode >= 500 {
			lastErr = fmt.Errorf("APNs server error: %d", statusCode)
			continue
		}

		return fmt.Errorf("APNs error: %d", statusCode)
	}

	return fmt.Errorf("APNs send failed after retries: %w", lastErr)
}

func (a *APNsProvider) sendOnce(ctx context.Context, token string, body []byte) (int, error) {
	url := fmt.Sprintf("https://api.push.apple.com/3/device/%s", token)

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		return 0, err
	}

	jwt, err := a.getJWT()
	if err != nil {
		return 0, fmt.Errorf("get JWT: %w", err)
	}

	req.Header.Set("authorization", "bearer "+jwt)
	req.Header.Set("apns-topic", a.bundleID)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("apns-priority", "10")

	resp, err := a.client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	io.ReadAll(resp.Body)

	return resp.StatusCode, nil
}

func (a *APNsProvider) getJWT() (string, error) {
	a.mu.Lock()
	defer a.mu.Unlock()

	if a.jwtToken != "" && time.Now().Before(a.jwtExp) {
		return a.jwtToken, nil
	}

	now := time.Now()
	token, err := a.signJWT(now)
	if err != nil {
		return "", err
	}

	a.jwtToken = token
	a.jwtExp = now.Add(45 * time.Minute)
	return token, nil
}

func (a *APNsProvider) signJWT(now time.Time) (string, error) {
	headerJSON := fmt.Sprintf(`{"alg":"ES256","kid":"%s"}`, a.keyID)
	claimsJSON := fmt.Sprintf(`{"iss":"%s","iat":%d}`, a.teamID, now.Unix())

	header := base64.RawURLEncoding.EncodeToString([]byte(headerJSON))
	claims := base64.RawURLEncoding.EncodeToString([]byte(claimsJSON))
	signingInput := header + "." + claims

	hash := sha256.Sum256([]byte(signingInput))
	r, s, err := ecdsa.Sign(rand.Reader, a.privateKey, hash[:])
	if err != nil {
		return "", fmt.Errorf("sign: %w", err)
	}

	// ES256 signature: r || s, each padded to 32 bytes
	curveBits := a.privateKey.Curve.Params().BitSize
	keyBytes := curveBits / 8
	if curveBits%8 > 0 {
		keyBytes++
	}

	sig := make([]byte, 2*keyBytes)
	rBytes := r.Bytes()
	sBytes := s.Bytes()
	copy(sig[keyBytes-len(rBytes):keyBytes], rBytes)
	copy(sig[2*keyBytes-len(sBytes):2*keyBytes], sBytes)

	return signingInput + "." + base64.RawURLEncoding.EncodeToString(sig), nil
}

// Name returns the provider name.
func (a *APNsProvider) Name() string {
	return "apns"
}
