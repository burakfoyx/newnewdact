package status

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"

	"github.com/xyidactyl/agent/internal/logging"
)

// AgentStatus represents the agent's health data written to status.json.
type AgentStatus struct {
	AgentVersion      string   `json:"agent_version"`
	UptimeSeconds     int64    `json:"uptime_seconds"`
	LastSampleAt      string   `json:"last_sample_at"`
	ControlVersion    int      `json:"control_version"`
	UsersCount        int      `json:"users_count"`
	ActiveAlerts      int      `json:"active_alerts"`
	ActiveAutomations int      `json:"active_automations"`
	ServersMonitored  int      `json:"servers_monitored"`
	DBSizeBytes       int64    `json:"db_size_bytes,omitempty"`
	Errors            []string `json:"errors,omitempty"`
}

// Writer writes status.json to the data directory for the iOS app to read.
type Writer struct {
	mu       sync.Mutex
	filePath string
}

// NewWriter creates a new status writer.
func NewWriter(dataDir string) *Writer {
	return &Writer{
		filePath: filepath.Join(dataDir, "status.json"),
	}
}

// Update writes the current agent status to status.json.
func (w *Writer) Update(s AgentStatus) {
	w.mu.Lock()
	defer w.mu.Unlock()

	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		logging.Error("Failed to marshal status: %v", err)
		return
	}

	// Write to temp file then rename for atomicity
	tmpPath := w.filePath + ".tmp"
	if err := os.WriteFile(tmpPath, data, 0644); err != nil {
		logging.Error("Failed to write status.json: %v", err)
		return
	}

	if err := os.Rename(tmpPath, w.filePath); err != nil {
		logging.Error("Failed to rename status.json: %v", err)
	}
}
