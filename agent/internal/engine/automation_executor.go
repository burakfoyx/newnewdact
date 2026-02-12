package engine

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/xyidactyl/agent/internal/database"
	"github.com/xyidactyl/agent/internal/logging"
	"github.com/xyidactyl/agent/internal/models"
	"github.com/xyidactyl/agent/internal/pterodactyl"
	"github.com/xyidactyl/agent/internal/push"
)

// AutomationExecutor evaluates automation rules and executes actions.
type AutomationExecutor struct {
	db           *database.DB
	pteroClient  *pterodactyl.Client
	pushProvider push.Provider
	maxConcurrent int

	mu              sync.Mutex
	lastExecutedAt  map[string]time.Time // rule_id -> last execution time
}

// NewAutomationExecutor creates a new automation executor.
func NewAutomationExecutor(db *database.DB, pteroClient *pterodactyl.Client, pushProvider push.Provider, maxConcurrent int) *AutomationExecutor {
	return &AutomationExecutor{
		db:             db,
		pteroClient:    pteroClient,
		pushProvider:   pushProvider,
		maxConcurrent:  maxConcurrent,
		lastExecutedAt: make(map[string]time.Time),
	}
}

// Evaluate checks automation rules for a server and executes triggered actions.
func (ae *AutomationExecutor) Evaluate(ctx context.Context, user models.ControlUser, apiKey string, snapshot *models.ResourceSnapshot, rules []models.AutomationRule) {
	ae.mu.Lock()
	defer ae.mu.Unlock()

	for _, rule := range rules {
		ae.evaluateRule(ctx, user, apiKey, snapshot, rule)
	}
}

func (ae *AutomationExecutor) evaluateRule(ctx context.Context, user models.ControlUser, apiKey string, snapshot *models.ResourceSnapshot, rule models.AutomationRule) {
	// Check cooldown
	if lastExec, ok := ae.lastExecutedAt[rule.ID]; ok {
		if time.Since(lastExec) < time.Duration(rule.Cooldown)*time.Second {
			return
		}
	}

	// Evaluate trigger
	triggered := ae.evaluateTrigger(rule, snapshot)
	if !triggered {
		return
	}

	// Permission check: verify server is in user's allowed list
	if !isServerAllowed(user, rule.ServerID) {
		logging.Warn("Automation %s: server %s not in user %s allowed_servers, skipping",
			rule.ID, rule.ServerID, user.UserUUID)
		return
	}

	// Execute action
	logging.Info("⚡ Automation triggered: rule=%s trigger=%s action=%s server=%s",
		rule.ID, rule.TriggerType, rule.Action, rule.ServerID)

	err := ae.executeAction(ctx, apiKey, rule)

	// Log execution
	result := "success"
	errMsg := ""
	if err != nil {
		result = "failure"
		errMsg = err.Error()
		logging.Error("Automation %s failed: %v", rule.ID, err)
	}

	ae.lastExecutedAt[rule.ID] = time.Now()

	ae.db.InsertAutomationLog(models.AutomationLogEntry{
		RuleID:   rule.ID,
		UserUUID: rule.UserUUID,
		ServerID: rule.ServerID,
		Action:   rule.Action,
		Result:   result,
		ErrorMsg: errMsg,
	})

	// Send push notification about automation
	title := fmt.Sprintf("⚡ Automation: %s", rule.Action)
	body := fmt.Sprintf("Executed '%s' on server (trigger: %s)", rule.Action, rule.TriggerType)
	if err != nil {
		body = fmt.Sprintf("Failed to execute '%s': %s", rule.Action, errMsg)
	}

	payload := push.Payload{
		Title:     title,
		Body:      body,
		UserUUID:  rule.UserUUID,
		ServerID:  rule.ServerID,
		EventType: "automation",
		Timestamp: time.Now().Format(time.RFC3339),
	}

	for _, token := range user.DeviceTokens {
		if pushErr := ae.pushProvider.Send(ctx, token, payload); pushErr != nil {
			logging.Error("Failed to send automation push to token: %v", pushErr)
		}
	}
}

func (ae *AutomationExecutor) evaluateTrigger(rule models.AutomationRule, snapshot *models.ResourceSnapshot) bool {
	switch rule.TriggerType {
	case "cpu_threshold":
		threshold, ok := getFloat(rule.TriggerConfig, "threshold")
		if !ok {
			return false
		}
		return snapshot.CPUPercent > threshold

	case "ram_threshold":
		threshold, ok := getFloat(rule.TriggerConfig, "threshold")
		if !ok || snapshot.MemLimit == 0 {
			return false
		}
		memPercent := float64(snapshot.MemBytes) / float64(snapshot.MemLimit) * 100
		return memPercent > threshold

	case "disk_threshold":
		threshold, ok := getFloat(rule.TriggerConfig, "threshold")
		if !ok || snapshot.DiskLimit == 0 {
			return false
		}
		diskPercent := float64(snapshot.DiskBytes) / float64(snapshot.DiskLimit) * 100
		return diskPercent > threshold

	case "server_offline":
		return snapshot.PowerState == "offline" || snapshot.PowerState == "stopped"

	case "server_crash":
		return snapshot.PowerState == "offline" // Distinguish from "stopped" (intentional)

	default:
		logging.Warn("Unknown automation trigger type: %s", rule.TriggerType)
		return false
	}
}

func (ae *AutomationExecutor) executeAction(ctx context.Context, apiKey string, rule models.AutomationRule) error {
	switch rule.Action {
	case "restart":
		return ae.pteroClient.SendPowerSignal(apiKey, rule.ServerID, "restart")

	case "stop":
		return ae.pteroClient.SendPowerSignal(apiKey, rule.ServerID, "stop")

	case "start":
		return ae.pteroClient.SendPowerSignal(apiKey, rule.ServerID, "start")

	case "command":
		cmd, ok := rule.ActionConfig["command"].(string)
		if !ok || cmd == "" {
			return fmt.Errorf("missing command in action_config")
		}
		return ae.pteroClient.SendCommand(apiKey, rule.ServerID, cmd)

	case "backup":
		return ae.pteroClient.CreateBackup(apiKey, rule.ServerID)

	default:
		return fmt.Errorf("unknown action: %s", rule.Action)
	}
}

func isServerAllowed(user models.ControlUser, serverID string) bool {
	for _, s := range user.AllowedServers {
		if s == serverID {
			return true
		}
	}
	return false
}

func getFloat(m map[string]interface{}, key string) (float64, bool) {
	v, ok := m[key]
	if !ok {
		return 0, false
	}
	switch n := v.(type) {
	case float64:
		return n, true
	case int:
		return float64(n), true
	case int64:
		return float64(n), true
	default:
		return 0, false
	}
}
