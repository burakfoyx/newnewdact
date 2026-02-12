package models

// ControlFile represents the entire control.json structure
// written by the iOS app and read by the agent.
type ControlFile struct {
	Version     int              `json:"version"`
	UpdatedAt   int64            `json:"updated_at"`
	Users       []ControlUser    `json:"users"`
	Alerts      []AlertRule      `json:"alerts"`
	Automations []AutomationRule `json:"automations"`
}

// ControlUser represents a registered user in the control plane.
type ControlUser struct {
	UserUUID        string   `json:"user_uuid"`
	APIKeyEncrypted string   `json:"api_key_encrypted"`
	IsAdmin         bool     `json:"is_admin"`
	AllowedServers  []string `json:"allowed_servers"`
	DeviceTokens    []string `json:"device_tokens"`
}

// AlertRule defines a monitoring alert condition.
type AlertRule struct {
	ID            string  `json:"id"`
	UserUUID      string  `json:"user_uuid"`
	ServerID      string  `json:"server_id"`
	ConditionType string  `json:"condition_type"` // cpu_threshold, ram_threshold, disk_threshold, power_state_change, offline_duration, restart_loop
	Threshold     float64 `json:"threshold"`
	Duration      int     `json:"duration"`  // seconds the condition must hold
	Cooldown      int     `json:"cooldown"`  // seconds between triggers
	Enabled       bool    `json:"enabled"`
}

// AutomationRule defines an automated action triggered by conditions.
type AutomationRule struct {
	ID            string                 `json:"id"`
	UserUUID      string                 `json:"user_uuid"`
	ServerID      string                 `json:"server_id"`
	TriggerType   string                 `json:"trigger_type"`
	TriggerConfig map[string]interface{} `json:"trigger_config"`
	Action        string                 `json:"action"` // restart, stop, command, backup
	ActionConfig  map[string]interface{} `json:"action_config"`
	Cooldown      int                    `json:"cooldown"`
	Enabled       bool                   `json:"enabled"`
}
