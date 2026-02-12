package models

import "time"

// AutomationLogEntry records an automation execution.
type AutomationLogEntry struct {
	ID         int64     `json:"id"`
	RuleID     string    `json:"rule_id"`
	UserUUID   string    `json:"user_uuid"`
	ServerID   string    `json:"server_id"`
	Action     string    `json:"action"`
	Result     string    `json:"result"` // "success" or "failure"
	ErrorMsg   string    `json:"error_msg,omitempty"`
	ExecutedAt time.Time `json:"executed_at"`
}

// AlertHistoryEntry records a triggered alert.
type AlertHistoryEntry struct {
	ID          int64     `json:"id"`
	RuleID      string    `json:"rule_id"`
	UserUUID    string    `json:"user_uuid"`
	ServerID    string    `json:"server_id"`
	Condition   string    `json:"condition"`
	Value       float64   `json:"value"`
	TriggeredAt time.Time `json:"triggered_at"`
}
