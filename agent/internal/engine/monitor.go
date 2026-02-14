package engine

import (
	"context"
	"sync"
	"time"

	"github.com/xyidactyl/agent/internal/control"
	"github.com/xyidactyl/agent/internal/database"
	"github.com/xyidactyl/agent/internal/logging"
	"github.com/xyidactyl/agent/internal/models"
	"github.com/xyidactyl/agent/internal/pterodactyl"
	"github.com/xyidactyl/agent/internal/security"
	"github.com/xyidactyl/agent/internal/status"
)

// Monitor runs the main sampling loop: polls Pterodactyl for server resources,
// stores snapshots, and triggers alert/automation evaluation.
type Monitor struct {
	interval       time.Duration
	pteroClient    *pterodactyl.Client
	db             *database.DB
	controlLoader  *control.Loader
	crypto         *security.Crypto
	alertEvaluator *AlertEvaluator
	autoExecutor   *AutomationExecutor
	statusWriter   *status.Writer
	metricsWriter  *status.MetricsWriter
	stopCh         chan struct{}
	startTime      time.Time

	// Permission cache: user_uuid -> decrypted API key
	mu                 sync.RWMutex
	apiKeyCache        map[string]string
	lastControlVersion int
}

// NewMonitor creates a new monitoring engine.
func NewMonitor(
	intervalSec int,
	pteroClient *pterodactyl.Client,
	db *database.DB,
	controlLoader *control.Loader,
	crypto *security.Crypto,
	alertEval *AlertEvaluator,
	autoExec *AutomationExecutor,
	sw *status.Writer,
	mw *status.MetricsWriter,
) *Monitor {
	return &Monitor{
		interval:       time.Duration(intervalSec) * time.Second,
		pteroClient:    pteroClient,
		db:             db,
		controlLoader:  controlLoader,
		crypto:         crypto,
		alertEvaluator: alertEval,
		autoExecutor:   autoExec,
		statusWriter:   sw,
		metricsWriter:  mw,
		stopCh:         make(chan struct{}),
		startTime:      time.Now(),
		apiKeyCache:    make(map[string]string),
	}
}

// Start begins the monitoring loop.
func (m *Monitor) Start() {
	logging.Info("Monitoring engine started (interval: %s)", m.interval)
	go m.loop()
}

// Stop halts the monitoring loop.
func (m *Monitor) Stop() {
	close(m.stopCh)
}

func (m *Monitor) loop() {
	// Run immediately once, then on ticker
	m.sample()

	ticker := time.NewTicker(m.interval)
	defer ticker.Stop()

	for {
		select {
		case <-m.stopCh:
			logging.Info("Monitoring engine stopped")
			return
		case <-ticker.C:
			m.sample()
		}
	}
}

func (m *Monitor) sample() {
	cf := m.controlLoader.Get()
	if cf == nil || len(cf.Users) == 0 {
		logging.Debug("No users configured, skipping sample")
		m.updateStatus(cf, 0)
		return
	}

	// Invalidate API key cache if control file updated (e.g. key rotation)
	if cf.Version > m.lastControlVersion {
		logging.Info("Control version changed (%d -> %d), invalidating API key cache", m.lastControlVersion, cf.Version)
		m.InvalidateKeyCache()
		m.lastControlVersion = cf.Version
	}

	serversMonitored := 0

	for _, user := range cf.Users {
		apiKey, err := m.getAPIKey(user)
		if err != nil {
			logging.Error("Failed to decrypt API key for user %s: %v", user.UserUUID, err)
			continue
		}

		for _, serverID := range user.AllowedServers {
			snapshot, err := m.collectServer(apiKey, serverID)
			if err != nil {
				logging.Warn("Failed to collect server %s for user %s: %v", serverID, user.UserUUID, err)
				continue
			}

			// Store snapshot
			if err := m.db.InsertSnapshot(*snapshot); err != nil {
				logging.Error("Failed to store snapshot for server %s: %v", serverID, err)
				continue
			}

			serversMonitored++

			// Evaluate alerts for this server
			userAlerts := filterAlerts(cf.Alerts, user.UserUUID, serverID)
			m.alertEvaluator.Evaluate(context.Background(), user, snapshot, userAlerts)

			// Evaluate automations for this server
			userAutos := filterAutomations(cf.Automations, user.UserUUID, serverID)
			m.autoExecutor.Evaluate(context.Background(), user, apiKey, snapshot, userAutos)
		}
	}

	logging.Debug("Sampling cycle complete: %d servers monitored", serversMonitored)
	m.updateStatus(cf, serversMonitored)

	// Export metrics to metrics.json (last 1 hour = 120 points at 30s)
	uniqueServers := make(map[string]bool)
	for _, user := range cf.Users {
		for _, sid := range user.AllowedServers {
			uniqueServers[sid] = true
		}
	}
	serverIDs := make([]string, 0, len(uniqueServers))
	for sid := range uniqueServers {
		serverIDs = append(serverIDs, sid)
	}

	if len(serverIDs) > 0 {
		// Export last 24 hours of data (24 * 60 * 60 / 30s = 2880 points)
		// This ensures graph history is available immediately to the app.
		m.metricsWriter.Update(serverIDs, 2880)
	}
}

func (m *Monitor) collectServer(apiKey, serverID string) (*models.ResourceSnapshot, error) {
	res, err := m.pteroClient.FetchResources(apiKey, serverID)
	if err != nil {
		return nil, err
	}

	return &models.ResourceSnapshot{
		ServerID:   serverID,
		Timestamp:  time.Now(),
		PowerState: res.CurrentState,
		CPUPercent: res.Resources.CPUAbsolute,
		MemBytes:   res.Resources.MemoryBytes,
		MemLimit:   0, // Will be populated from server attributes if available
		DiskBytes:  res.Resources.DiskBytes,
		DiskLimit:  0,
		NetRx:      res.Resources.NetworkRxBytes,
		NetTx:      res.Resources.NetworkTxBytes,
		UptimeMs:   res.Resources.Uptime,
	}, nil
}

func (m *Monitor) getAPIKey(user models.ControlUser) (string, error) {
	m.mu.RLock()
	cached, ok := m.apiKeyCache[user.UserUUID]
	m.mu.RUnlock()

	if ok {
		return cached, nil
	}

	decrypted, err := m.crypto.Decrypt(user.APIKeyEncrypted)
	if err != nil {
		return "", err
	}

	m.mu.Lock()
	m.apiKeyCache[user.UserUUID] = decrypted
	m.mu.Unlock()

	return decrypted, nil
}

// InvalidateKeyCache clears cached API keys (called on control.json reload).
func (m *Monitor) InvalidateKeyCache() {
	m.mu.Lock()
	m.apiKeyCache = make(map[string]string)
	m.mu.Unlock()
}

func (m *Monitor) updateStatus(cf *models.ControlFile, serversMonitored int) {
	controlVersion := 0
	usersCount := 0
	alertCount := 0
	autoCount := 0

	if cf != nil {
		controlVersion = cf.Version
		usersCount = len(cf.Users)
		for _, a := range cf.Alerts {
			if a.Enabled {
				alertCount++
			}
		}
		for _, a := range cf.Automations {
			if a.Enabled {
				autoCount++
			}
		}
	}

	m.statusWriter.Update(status.AgentStatus{
		AgentVersion:      "1.0.0",
		UptimeSeconds:     int64(time.Since(m.startTime).Seconds()),
		LastSampleAt:      time.Now().Format(time.RFC3339),
		ControlVersion:    controlVersion,
		UsersCount:        usersCount,
		ActiveAlerts:      alertCount,
		ActiveAutomations: autoCount,
		ServersMonitored:  serversMonitored,
	})
}

func filterAlerts(all []models.AlertRule, userUUID, serverID string) []models.AlertRule {
	var result []models.AlertRule
	for _, a := range all {
		if a.UserUUID == userUUID && a.ServerID == serverID && a.Enabled {
			result = append(result, a)
		}
	}
	return result
}

func filterAutomations(all []models.AutomationRule, userUUID, serverID string) []models.AutomationRule {
	var result []models.AutomationRule
	for _, a := range all {
		if a.UserUUID == userUUID && a.ServerID == serverID && a.Enabled {
			result = append(result, a)
		}
	}
	return result
}
