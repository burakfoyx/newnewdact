package engine

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/xyidactyl/agent/internal/database"
	"github.com/xyidactyl/agent/internal/logging"
	"github.com/xyidactyl/agent/internal/models"
	"github.com/xyidactyl/agent/internal/push"
)

// AlertEvaluator checks alert rules against resource snapshots
// and triggers push notifications when conditions are met.
type AlertEvaluator struct {
	db           *database.DB
	pushProvider push.Provider

	// In-memory state for duration-based tracking and cooldowns
	mu               sync.Mutex
	firstExceededAt  map[string]time.Time // rule_id -> when condition first became true
	lastTriggeredAt  map[string]time.Time // rule_id -> last trigger time
	previousStates   map[string]string    // server_id -> last known power state
	restartTracker   map[string][]time.Time // server_id -> list of recent restart timestamps
}

// NewAlertEvaluator creates a new alert evaluator.
func NewAlertEvaluator(db *database.DB, pushProvider push.Provider) *AlertEvaluator {
	return &AlertEvaluator{
		db:              db,
		pushProvider:    pushProvider,
		firstExceededAt: make(map[string]time.Time),
		lastTriggeredAt: make(map[string]time.Time),
		previousStates:  make(map[string]string),
		restartTracker:  make(map[string][]time.Time),
	}
}

// Evaluate checks all alert rules for a specific server snapshot.
func (ae *AlertEvaluator) Evaluate(ctx context.Context, user models.ControlUser, snapshot *models.ResourceSnapshot, rules []models.AlertRule) {
	ae.mu.Lock()
	defer ae.mu.Unlock()

	// Read previous state BEFORE updating it
	prevState := ae.previousStates[snapshot.ServerID]

	for _, rule := range rules {
		ae.evaluateRule(ctx, user, snapshot, rule)
	}

	// Track restarts (transition from offline/stopped to running)
	if (prevState == "offline" || prevState == "stopped") && snapshot.PowerState == "running" {
		ae.restartTracker[snapshot.ServerID] = append(ae.restartTracker[snapshot.ServerID], time.Now())
	}

	// Update previous state for next cycle
	ae.previousStates[snapshot.ServerID] = snapshot.PowerState
}

func (ae *AlertEvaluator) evaluateRule(ctx context.Context, user models.ControlUser, snapshot *models.ResourceSnapshot, rule models.AlertRule) {
	// Check cooldown
	if lastTrigger, ok := ae.lastTriggeredAt[rule.ID]; ok {
		if time.Since(lastTrigger) < time.Duration(rule.Cooldown)*time.Second {
			return
		}
	}

	triggered := false
	var currentValue float64

	switch rule.ConditionType {
	case "cpu_threshold":
		currentValue = snapshot.CPUPercent
		triggered = currentValue > rule.Threshold

	case "ram_threshold":
		if snapshot.MemLimit > 0 {
			currentValue = float64(snapshot.MemBytes) / float64(snapshot.MemLimit) * 100
		}
		triggered = currentValue > rule.Threshold

	case "disk_threshold":
		if snapshot.DiskLimit > 0 {
			currentValue = float64(snapshot.DiskBytes) / float64(snapshot.DiskLimit) * 100
		}
		triggered = currentValue > rule.Threshold

	case "power_state_change":
		prevState := ae.previousStates[snapshot.ServerID]
		if prevState != "" && prevState != snapshot.PowerState {
			triggered = true
			currentValue = 0
		}

	case "offline_duration":
		if snapshot.PowerState == "offline" || snapshot.PowerState == "stopped" {
			triggered = true
			currentValue = 0
		}

	case "restart_loop":
		// Check for 3+ restarts in 5 minutes
		recentRestarts := ae.getRecentRestarts(snapshot.ServerID, 5*time.Minute)
		if len(recentRestarts) >= 3 {
			triggered = true
			currentValue = float64(len(recentRestarts))
		}

	default:
		logging.Warn("Unknown alert condition type: %s", rule.ConditionType)
		return
	}

	if !triggered {
		// Condition not met, reset duration tracker
		delete(ae.firstExceededAt, rule.ID)
		return
	}

	// Duration-based check: condition must hold for `duration` seconds
	if rule.Duration > 0 && rule.ConditionType != "power_state_change" && rule.ConditionType != "restart_loop" {
		firstExceeded, exists := ae.firstExceededAt[rule.ID]
		if !exists {
			ae.firstExceededAt[rule.ID] = time.Now()
			return // Start tracking, don't trigger yet
		}

		if time.Since(firstExceeded) < time.Duration(rule.Duration)*time.Second {
			return // Not held long enough
		}
	}

	// TRIGGER!
	ae.lastTriggeredAt[rule.ID] = time.Now()
	delete(ae.firstExceededAt, rule.ID) // Reset duration tracker

	logging.Info("🔔 Alert triggered: rule=%s type=%s server=%s value=%.1f threshold=%.1f",
		rule.ID, rule.ConditionType, rule.ServerID, currentValue, rule.Threshold)

	// Log to database
	ae.db.InsertAlertHistory(models.AlertHistoryEntry{
		RuleID:    rule.ID,
		UserUUID:  rule.UserUUID,
		ServerID:  rule.ServerID,
		Condition: rule.ConditionType,
		Value:     currentValue,
	})

	// Build and send push notification
	title, body := ae.buildNotificationText(rule, currentValue, snapshot)
	payload := push.Payload{
		Title:     title,
		Body:      body,
		UserUUID:  rule.UserUUID,
		ServerID:  rule.ServerID,
		EventType: "alert",
		Timestamp: time.Now().Format(time.RFC3339),
	}

	for _, token := range user.DeviceTokens {
		if err := ae.pushProvider.Send(ctx, token, payload); err != nil {
			truncLen := len(token)
			if truncLen > 16 {
				truncLen = 16
			}
			logging.Error("Failed to send push for alert %s to token %s: %v", rule.ID, token[:truncLen], err)
		}
	}
}

func (ae *AlertEvaluator) buildNotificationText(rule models.AlertRule, value float64, snapshot *models.ResourceSnapshot) (string, string) {
	title := "Server Alert"
	var body string

	switch rule.ConditionType {
	case "cpu_threshold":
		title = "⚠️ CPU Alert"
		body = fmt.Sprintf("CPU usage at %.0f%% (threshold: %.0f%%)", value, rule.Threshold)
	case "ram_threshold":
		title = "⚠️ Memory Alert"
		body = fmt.Sprintf("Memory usage at %.0f%% (threshold: %.0f%%)", value, rule.Threshold)
	case "disk_threshold":
		title = "💾 Disk Alert"
		body = fmt.Sprintf("Disk usage at %.0f%% (threshold: %.0f%%)", value, rule.Threshold)
	case "power_state_change":
		title = "🔄 Power State Changed"
		body = fmt.Sprintf("Server is now: %s", snapshot.PowerState)
	case "offline_duration":
		title = "🔴 Server Offline"
		body = fmt.Sprintf("Server has been offline for %d+ seconds", rule.Duration)
	case "restart_loop":
		title = "🔁 Restart Loop Detected"
		body = fmt.Sprintf("%.0f restarts detected in 5 minutes", value)
	default:
		body = fmt.Sprintf("Condition %s triggered (value: %.1f)", rule.ConditionType, value)
	}

	return title, body
}

func (ae *AlertEvaluator) getRecentRestarts(serverID string, window time.Duration) []time.Time {
	restarts := ae.restartTracker[serverID]
	cutoff := time.Now().Add(-window)

	var recent []time.Time
	for _, t := range restarts {
		if t.After(cutoff) {
			recent = append(recent, t)
		}
	}

	// Clean up old entries
	ae.restartTracker[serverID] = recent
	return recent
}
