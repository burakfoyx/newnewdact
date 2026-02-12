package control

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/xyidactyl/agent/internal/logging"
	"github.com/xyidactyl/agent/internal/models"
)

// Loader watches control.json and reloads configuration when the version changes.
type Loader struct {
	mu          sync.RWMutex
	filePath    string
	current     *models.ControlFile
	version     int
	pollInterval time.Duration
	stopCh      chan struct{}
}

// NewLoader creates a new control file loader.
func NewLoader(filePath string) *Loader {
	return &Loader{
		filePath:     filePath,
		pollInterval: 15 * time.Second,
		stopCh:       make(chan struct{}),
	}
}

// LoadInitial performs the first load of control.json. Returns error if file doesn't exist or is invalid.
func (l *Loader) LoadInitial() error {
	cf, err := l.readFile()
	if err != nil {
		// If file doesn't exist, start with empty config
		if os.IsNotExist(err) {
			logging.Info("No control.json found, starting with empty configuration")
			l.mu.Lock()
			l.current = &models.ControlFile{Version: 0}
			l.version = 0
			l.mu.Unlock()
			return nil
		}
		return fmt.Errorf("initial load: %w", err)
	}

	l.mu.Lock()
	l.current = cf
	l.version = cf.Version
	l.mu.Unlock()

	logging.Info("Loaded control.json version %d (%d users, %d alerts, %d automations)",
		cf.Version, len(cf.Users), len(cf.Alerts), len(cf.Automations))
	return nil
}

// Start begins the periodic polling loop.
func (l *Loader) Start() {
	go l.pollLoop()
}

// Stop halts the polling loop.
func (l *Loader) Stop() {
	close(l.stopCh)
}

// Get returns the current control file (thread-safe).
func (l *Loader) Get() *models.ControlFile {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.current
}

// Version returns the current loaded version.
func (l *Loader) Version() int {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.version
}

func (l *Loader) pollLoop() {
	ticker := time.NewTicker(l.pollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-l.stopCh:
			return
		case <-ticker.C:
			l.checkForUpdate()
		}
	}
}

func (l *Loader) checkForUpdate() {
	// Quick version check: read file and compare version only
	cf, err := l.readFile()
	if err != nil {
		if !os.IsNotExist(err) {
			logging.Warn("Failed to read control.json: %v", err)
		}
		return
	}

	l.mu.RLock()
	currentVersion := l.version
	l.mu.RUnlock()

	if cf.Version == currentVersion {
		return // No change
	}

	// Validate before accepting
	if err := l.validate(cf); err != nil {
		logging.Error("Invalid control.json version %d: %v", cf.Version, err)
		return
	}

	l.mu.Lock()
	l.current = cf
	l.version = cf.Version
	l.mu.Unlock()

	logging.Info("Reloaded control.json: version %d → %d (%d users, %d alerts, %d automations)",
		currentVersion, cf.Version, len(cf.Users), len(cf.Alerts), len(cf.Automations))
}

func (l *Loader) readFile() (*models.ControlFile, error) {
	data, err := os.ReadFile(l.filePath)
	if err != nil {
		return nil, err
	}

	var cf models.ControlFile
	if err := json.Unmarshal(data, &cf); err != nil {
		return nil, fmt.Errorf("parse control.json: %w", err)
	}

	return &cf, nil
}

func (l *Loader) validate(cf *models.ControlFile) error {
	// Basic structural validation
	for i, u := range cf.Users {
		if u.UserUUID == "" {
			return fmt.Errorf("user[%d]: empty user_uuid", i)
		}
		if u.APIKeyEncrypted == "" {
			return fmt.Errorf("user[%d] (%s): empty api_key_encrypted", i, u.UserUUID)
		}
	}

	for i, a := range cf.Alerts {
		if a.ID == "" {
			return fmt.Errorf("alert[%d]: empty id", i)
		}
		if a.UserUUID == "" {
			return fmt.Errorf("alert[%d] (%s): empty user_uuid", i, a.ID)
		}
		if a.ServerID == "" {
			return fmt.Errorf("alert[%d] (%s): empty server_id", i, a.ID)
		}
	}

	for i, a := range cf.Automations {
		if a.ID == "" {
			return fmt.Errorf("automation[%d]: empty id", i)
		}
		if a.UserUUID == "" {
			return fmt.Errorf("automation[%d] (%s): empty user_uuid", i, a.ID)
		}
		if a.ServerID == "" {
			return fmt.Errorf("automation[%d] (%s): empty server_id", i, a.ID)
		}
	}

	return nil
}
