package push

import (
	"context"

	"github.com/xyidactyl/agent/internal/logging"
)

// DevProvider logs push notifications to console instead of sending them.
// Used for local development and testing.
type DevProvider struct{}

// NewDevProvider creates a new development push provider.
func NewDevProvider() *DevProvider {
	return &DevProvider{}
}

// Send logs the push notification to console.
func (d *DevProvider) Send(ctx context.Context, token string, payload Payload) error {
	logging.Info("🔔 [DEV PUSH] Push notification triggered")
	logging.Info("   Token:    %s", token)
	logging.Info("   Title:    %s", payload.Title)
	logging.Info("   Body:     %s", payload.Body)
	logging.Info("   User:     %s", payload.UserUUID)
	logging.Info("   Server:   %s", payload.ServerID)
	logging.Info("   Event:    %s", payload.EventType)
	logging.Info("   Time:     %s", payload.Timestamp)
	return nil
}

// Name returns the provider name.
func (d *DevProvider) Name() string {
	return "dev"
}
