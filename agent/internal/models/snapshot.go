package models

import "time"

// ResourceSnapshot represents a single point-in-time sample of server resources.
type ResourceSnapshot struct {
	ID         int64     `json:"id"`
	ServerID   string    `json:"server_id"`
	Timestamp  time.Time `json:"timestamp"`
	PowerState string    `json:"power_state"`
	CPUPercent float64   `json:"cpu_percent"`
	MemBytes   int64     `json:"mem_bytes"`
	MemLimit   int64     `json:"mem_limit"`
	DiskBytes  int64     `json:"disk_bytes"`
	DiskLimit  int64     `json:"disk_limit"`
	NetRx      int64     `json:"net_rx"`
	NetTx      int64     `json:"net_tx"`
	UptimeMs   int64     `json:"uptime_ms"`
}
