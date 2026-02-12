package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds all agent configuration loaded from environment variables.
type Config struct {
	AgentUUID        string
	AgentSecret      string
	PanelURL         string
	PanelAPIKey      string
	SamplingInterval int    // seconds, default 30
	RetentionDays    int    // max 30
	LogLevel         string // "debug", "info", "warn", "error"
	MaxConcurrent    int    // max concurrent automation actions
	ControlFilePath  string // path to control.json
	DataDir          string // path to data directory
	APNsKeyBase64    string
	APNsKeyID        string
	APNsTeamID       string
	APNsBundleID     string
	PushProvider     string // "apns" or "dev"
}

// Load reads configuration from environment variables with sensible defaults.
func Load() (*Config, error) {
	cfg := &Config{
		AgentUUID:        os.Getenv("AGENT_UUID"),
		AgentSecret:      os.Getenv("AGENT_SECRET"),
		PanelURL:         os.Getenv("PANEL_URL"),
		PanelAPIKey:      os.Getenv("PANEL_API_KEY"),
		SamplingInterval: envInt("SAMPLING_INTERVAL", 30),
		RetentionDays:    envInt("RETENTION_DAYS", 30),
		LogLevel:         envStr("LOG_LEVEL", "info"),
		MaxConcurrent:    envInt("MAX_CONCURRENT_ACTIONS", 5),
		ControlFilePath:  envStr("CONTROL_FILE_PATH", "./control/control.json"),
		DataDir:          envStr("DATA_DIR", "./data"),
		APNsKeyBase64:    os.Getenv("APNS_KEY_BASE64"),
		APNsKeyID:        os.Getenv("APNS_KEY_ID"),
		APNsTeamID:       os.Getenv("APNS_TEAM_ID"),
		APNsBundleID:     os.Getenv("APNS_BUNDLE_ID"),
		PushProvider:     envStr("PUSH_PROVIDER", "dev"),
	}

	// Validate required fields
	if cfg.AgentUUID == "" {
		return nil, fmt.Errorf("AGENT_UUID is required")
	}
	if cfg.AgentSecret == "" {
		return nil, fmt.Errorf("AGENT_SECRET is required")
	}
	if cfg.PanelURL == "" {
		return nil, fmt.Errorf("PANEL_URL is required")
	}
	if cfg.PanelAPIKey == "" {
		return nil, fmt.Errorf("PANEL_API_KEY is required")
	}

	// Clamp retention
	if cfg.RetentionDays > 30 {
		cfg.RetentionDays = 30
	}
	if cfg.RetentionDays < 1 {
		cfg.RetentionDays = 1
	}

	// Clamp sampling
	if cfg.SamplingInterval < 5 {
		cfg.SamplingInterval = 5
	}

	return cfg, nil
}

func envStr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func envInt(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}
