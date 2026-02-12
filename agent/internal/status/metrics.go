package status

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/xyidactyl/agent/internal/database"
	"github.com/xyidactyl/agent/internal/logging"
	"github.com/xyidactyl/agent/internal/models"
)

// MetricsExport represents the structure of the metrics.json file.
type MetricsExport struct {
	GeneratedAt time.Time                            `json:"generated_at"`
	Servers     map[string][]models.ResourceSnapshot `json:"servers"` // server_id -> snapshots
}

// MetricsWriter handles exporting recent metrics to a JSON file.
type MetricsWriter struct {
	mu       sync.Mutex
	filePath string
	db       *database.DB
}

// NewMetricsWriter creates a new metrics writer.
func NewMetricsWriter(dataDir string, db *database.DB) *MetricsWriter {
	return &MetricsWriter{
		filePath: filepath.Join(dataDir, "metrics.json"),
		db:       db,
	}
}

// Update queries recent history for the given servers and writes to metrics.json.
// limit per server (e.g., 120 = last 1 hour at 30s interval).
func (w *MetricsWriter) Update(serverIDs []string, limit int) {
	w.mu.Lock()
	defer w.mu.Unlock()

	export := MetricsExport{
		GeneratedAt: time.Now(),
		Servers:     make(map[string][]models.ResourceSnapshot),
	}

	for _, id := range serverIDs {
		snaps, err := w.db.GetRecentSnapshots(id, limit)
		if err != nil {
			logging.Warn("Failed to get recent snapshots for %s: %v", id, err)
			continue
		}
		export.Servers[id] = snaps
	}

	data, err := json.Marshal(export)
	if err != nil {
		logging.Error("Failed to marshal metrics export: %v", err)
		return
	}

	// atomic write
	tmpPath := w.filePath + ".tmp"
	if err := os.WriteFile(tmpPath, data, 0644); err != nil {
		logging.Error("Failed to write metrics.json: %v", err)
		return
	}
	if err := os.Rename(tmpPath, w.filePath); err != nil {
		logging.Error("Failed to rename metrics.json: %v", err)
	}
}
