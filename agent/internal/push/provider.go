package push

import "context"

// Payload represents a push notification to send.
type Payload struct {
	Title     string `json:"title"`
	Body      string `json:"body"`
	UserUUID  string `json:"user_uuid"`
	ServerID  string `json:"server_id"`
	EventType string `json:"event_type"` // "alert" or "automation"
	Timestamp string `json:"timestamp"`
}

// Provider defines the interface for sending push notifications.
type Provider interface {
	// Send delivers a push notification to the given device token.
	Send(ctx context.Context, token string, payload Payload) error
	// Name returns the provider name for logging.
	Name() string
}
