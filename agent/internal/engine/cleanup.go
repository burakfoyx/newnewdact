package engine

import (
	"time"

	"github.com/xyidactyl/agent/internal/database"
	"github.com/xyidactyl/agent/internal/logging"
)

// Cleanup runs the data retention cleanup job.
type Cleanup struct {
	db            *database.DB
	retentionDays int
	stopCh        chan struct{}
}

// NewCleanup creates a new cleanup job.
func NewCleanup(db *database.DB, retentionDays int) *Cleanup {
	return &Cleanup{
		db:            db,
		retentionDays: retentionDays,
		stopCh:        make(chan struct{}),
	}
}

// Start begins the daily cleanup loop.
func (c *Cleanup) Start() {
	logging.Info("Cleanup job started (retention: %d days)", c.retentionDays)

	// Run once at startup
	c.run()

	go func() {
		ticker := time.NewTicker(24 * time.Hour)
		defer ticker.Stop()

		for {
			select {
			case <-c.stopCh:
				return
			case <-ticker.C:
				c.run()
			}
		}
	}()
}

// Stop halts the cleanup loop.
func (c *Cleanup) Stop() {
	close(c.stopCh)
}

func (c *Cleanup) run() {
	deleted, err := c.db.CleanupOlderThan(c.retentionDays)
	if err != nil {
		logging.Error("Cleanup failed: %v", err)
		return
	}
	if deleted > 0 {
		logging.Info("🧹 Cleanup: deleted %d records older than %d days", deleted, c.retentionDays)
	} else {
		logging.Debug("Cleanup: no records to delete")
	}
}
