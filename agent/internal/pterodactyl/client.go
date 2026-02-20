package pterodactyl

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/xyidactyl/agent/internal/logging"
)

// Client communicates with the Pterodactyl API.
type Client struct {
	baseURL    string
	httpClient *http.Client
}

// NewClient creates a Pterodactyl API client.
func NewClient(panelURL string) *Client {
	url := strings.TrimRight(panelURL, "/")
	return &Client{
		baseURL: url,
		httpClient: &http.Client{
			Timeout: 25 * time.Second,
		},
	}
}

// ServerResource holds the resource usage data from the panel API.
type ServerResource struct {
	CurrentState string `json:"current_state"`
	IsSuspended  bool   `json:"is_suspended"`
	Resources    struct {
		MemoryBytes    int64   `json:"memory_bytes"`
		CPUAbsolute    float64 `json:"cpu_absolute"`
		DiskBytes      int64   `json:"disk_bytes"`
		NetworkRxBytes int64   `json:"network_rx_bytes"`
		NetworkTxBytes int64   `json:"network_tx_bytes"`
		Uptime         int64   `json:"uptime"`
	} `json:"resources"`
}

type resourceResponse struct {
	Attributes ServerResource `json:"attributes"`
}

// ServerListItem represents a server from the list endpoint.
type ServerListItem struct {
	Identifier string `json:"identifier"`
	UUID       string `json:"uuid"`
	Name       string `json:"name"`
	Limits     struct {
		Memory int64 `json:"memory"`
		Disk   int64 `json:"disk"`
	} `json:"limits"`
}

type serverListResponse struct {
	Data []struct {
		Attributes ServerListItem `json:"attributes"`
	} `json:"data"`
	Meta struct {
		Pagination struct {
			Total       int `json:"total"`
			CurrentPage int `json:"current_page"`
			TotalPages  int `json:"total_pages"`
		} `json:"pagination"`
	} `json:"meta"`
}

// FetchResources gets resource usage for a specific server.
func (c *Client) FetchResources(apiKey, serverID string) (*ServerResource, error) {
	url := fmt.Sprintf("%s/api/client/servers/%s/resources", c.baseURL, serverID)
	resp, err := c.doRequest("GET", url, apiKey, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result resourceResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode resources: %w", err)
	}
	return &result.Attributes, nil
}

// ListServers gets all servers accessible by the given API key.
func (c *Client) ListServers(apiKey string) ([]ServerListItem, error) {
	var allServers []ServerListItem
	page := 1

	for {
		url := fmt.Sprintf("%s/api/client?page=%d", c.baseURL, page)
		resp, err := c.doRequest("GET", url, apiKey, nil)
		if err != nil {
			return nil, err
		}

		var result serverListResponse
		if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
			resp.Body.Close()
			return nil, fmt.Errorf("decode server list: %w", err)
		}
		resp.Body.Close()

		for _, d := range result.Data {
			allServers = append(allServers, d.Attributes)
		}

		if page >= result.Meta.Pagination.TotalPages {
			break
		}
		page++
	}

	return allServers, nil
}

// SendPowerSignal sends a power action to a server.
func (c *Client) SendPowerSignal(apiKey, serverID, signal string) error {
	url := fmt.Sprintf("%s/api/client/servers/%s/power", c.baseURL, serverID)
	body := fmt.Sprintf(`{"signal":"%s"}`, signal)
	resp, err := c.doRequest("POST", url, apiKey, strings.NewReader(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

// SendCommand sends a console command to a server.
func (c *Client) SendCommand(apiKey, serverID, command string) error {
	url := fmt.Sprintf("%s/api/client/servers/%s/command", c.baseURL, serverID)
	body := fmt.Sprintf(`{"command":"%s"}`, command)
	resp, err := c.doRequest("POST", url, apiKey, strings.NewReader(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

// CreateBackup triggers a backup for a server.
func (c *Client) CreateBackup(apiKey, serverID string) error {
	url := fmt.Sprintf("%s/api/client/servers/%s/backups", c.baseURL, serverID)
	resp, err := c.doRequest("POST", url, apiKey, strings.NewReader("{}"))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

func (c *Client) doRequest(method, url, apiKey string, body io.Reader) (*http.Response, error) {
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("execute request: %w", err)
	}

	if resp.StatusCode >= 400 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		bodyStr := string(bodyBytes)
		if len(bodyStr) > 500 {
			bodyStr = bodyStr[:500] + "... (truncated)"
		}

		// 409 Conflict is common for servers in install/transfer states.
		if resp.StatusCode == 409 {
			logging.Debug("Pterodactyl API %s %s returned 409 (Conflict): %s", method, url, bodyStr)
		} else {
			logging.Warn("Pterodactyl API %s %s returned %d: %s", method, url, resp.StatusCode, bodyStr)
		}

		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, bodyStr)
	}

	return resp, nil
}
