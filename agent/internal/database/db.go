package database

import (
	"database/sql"
	"fmt"
	"path/filepath"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"github.com/xyidactyl/agent/internal/logging"
	"github.com/xyidactyl/agent/internal/models"
)

// DB wraps the SQLite database connection.
type DB struct {
	conn *sql.DB
}

// Open creates or opens the SQLite database and runs migrations.
func Open(dataDir string) (*DB, error) {
	dbPath := filepath.Join(dataDir, "agent.db")
	conn, err := sql.Open("sqlite3", dbPath+"?_journal_mode=WAL&_busy_timeout=5000")
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}

	conn.SetMaxOpenConns(1) // SQLite single-writer
	conn.SetMaxIdleConns(1)

	db := &DB{conn: conn}
	if err := db.migrate(); err != nil {
		conn.Close()
		return nil, fmt.Errorf("migrate: %w", err)
	}

	logging.Info("Database opened at %s", dbPath)
	return db, nil
}

// Close closes the database connection.
func (db *DB) Close() error {
	return db.conn.Close()
}

func (db *DB) migrate() error {
	migrations := []string{
		`CREATE TABLE IF NOT EXISTS resource_snapshots (
			id          INTEGER PRIMARY KEY AUTOINCREMENT,
			server_id   TEXT NOT NULL,
			timestamp   DATETIME NOT NULL,
			power_state TEXT,
			cpu_percent REAL,
			mem_bytes   INTEGER,
			mem_limit   INTEGER,
			disk_bytes  INTEGER,
			disk_limit  INTEGER,
			net_rx      INTEGER,
			net_tx      INTEGER,
			uptime_ms   INTEGER
		)`,
		`CREATE INDEX IF NOT EXISTS idx_snap_server_time ON resource_snapshots(server_id, timestamp)`,

		`CREATE TABLE IF NOT EXISTS automation_log (
			id          INTEGER PRIMARY KEY AUTOINCREMENT,
			rule_id     TEXT NOT NULL,
			user_uuid   TEXT NOT NULL,
			server_id   TEXT NOT NULL,
			action      TEXT NOT NULL,
			result      TEXT NOT NULL,
			error_msg   TEXT,
			executed_at DATETIME DEFAULT CURRENT_TIMESTAMP
		)`,

		`CREATE TABLE IF NOT EXISTS alert_history (
			id           INTEGER PRIMARY KEY AUTOINCREMENT,
			rule_id      TEXT NOT NULL,
			user_uuid    TEXT NOT NULL,
			server_id    TEXT NOT NULL,
			condition    TEXT NOT NULL,
			value        REAL,
			triggered_at DATETIME DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE INDEX IF NOT EXISTS idx_alert_hist_time ON alert_history(triggered_at)`,

		`CREATE TABLE IF NOT EXISTS agent_state (
			key   TEXT PRIMARY KEY,
			value TEXT
		)`,
	}

	for _, m := range migrations {
		if _, err := db.conn.Exec(m); err != nil {
			return fmt.Errorf("execute migration: %w", err)
		}
	}
	return nil
}

// InsertSnapshot stores a resource snapshot.
func (db *DB) InsertSnapshot(s models.ResourceSnapshot) error {
	_, err := db.conn.Exec(
		`INSERT INTO resource_snapshots (server_id, timestamp, power_state, cpu_percent, mem_bytes, mem_limit, disk_bytes, disk_limit, net_rx, net_tx, uptime_ms)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		s.ServerID, s.Timestamp, s.PowerState, s.CPUPercent,
		s.MemBytes, s.MemLimit, s.DiskBytes, s.DiskLimit,
		s.NetRx, s.NetTx, s.UptimeMs,
	)
	return err
}

// GetLatestSnapshot returns the most recent snapshot for a server.
func (db *DB) GetLatestSnapshot(serverID string) (*models.ResourceSnapshot, error) {
	row := db.conn.QueryRow(
		`SELECT id, server_id, timestamp, power_state, cpu_percent, mem_bytes, mem_limit, disk_bytes, disk_limit, net_rx, net_tx, uptime_ms
		 FROM resource_snapshots WHERE server_id = ? ORDER BY timestamp DESC LIMIT 1`, serverID,
	)
	var s models.ResourceSnapshot
	err := row.Scan(&s.ID, &s.ServerID, &s.Timestamp, &s.PowerState, &s.CPUPercent,
		&s.MemBytes, &s.MemLimit, &s.DiskBytes, &s.DiskLimit, &s.NetRx, &s.NetTx, &s.UptimeMs)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

// GetRecentSnapshots returns the last N snapshots for a server, most recent last.
func (db *DB) GetRecentSnapshots(serverID string, limit int) ([]models.ResourceSnapshot, error) {
	query := `SELECT id, server_id, timestamp, power_state, cpu_percent, mem_bytes, mem_limit, disk_bytes, disk_limit, net_rx, net_tx, uptime_ms
	          FROM resource_snapshots WHERE server_id = ? ORDER BY timestamp DESC LIMIT ?`

	rows, err := db.conn.Query(query, serverID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var snapshots []models.ResourceSnapshot
	for rows.Next() {
		var s models.ResourceSnapshot
		if err := rows.Scan(&s.ID, &s.ServerID, &s.Timestamp, &s.PowerState, &s.CPUPercent,
			&s.MemBytes, &s.MemLimit, &s.DiskBytes, &s.DiskLimit, &s.NetRx, &s.NetTx, &s.UptimeMs); err != nil {
			return nil, err
		}
		snapshots = append(snapshots, s)
	}

	// Reverse to chronological order (oldest first)
	for i, j := 0, len(snapshots)-1; i < j; i, j = i+1, j-1 {
		snapshots[i], snapshots[j] = snapshots[j], snapshots[i]
	}

	return snapshots, nil
}

// InsertAlertHistory logs a triggered alert.
func (db *DB) InsertAlertHistory(entry models.AlertHistoryEntry) error {
	_, err := db.conn.Exec(
		`INSERT INTO alert_history (rule_id, user_uuid, server_id, condition, value) VALUES (?, ?, ?, ?, ?)`,
		entry.RuleID, entry.UserUUID, entry.ServerID, entry.Condition, entry.Value,
	)
	return err
}

// InsertAutomationLog logs an automation execution.
func (db *DB) InsertAutomationLog(entry models.AutomationLogEntry) error {
	_, err := db.conn.Exec(
		`INSERT INTO automation_log (rule_id, user_uuid, server_id, action, result, error_msg) VALUES (?, ?, ?, ?, ?, ?)`,
		entry.RuleID, entry.UserUUID, entry.ServerID, entry.Action, entry.Result, entry.ErrorMsg,
	)
	return err
}

// CleanupOlderThan deletes records older than the given duration.
func (db *DB) CleanupOlderThan(days int) (int64, error) {
	cutoff := time.Now().AddDate(0, 0, -days).Format(time.RFC3339)

	var total int64

	res, err := db.conn.Exec(`DELETE FROM resource_snapshots WHERE timestamp < ?`, cutoff)
	if err != nil {
		return 0, err
	}
	n, _ := res.RowsAffected()
	total += n

	res, err = db.conn.Exec(`DELETE FROM automation_log WHERE executed_at < ?`, cutoff)
	if err != nil {
		return total, err
	}
	n, _ = res.RowsAffected()
	total += n

	res, err = db.conn.Exec(`DELETE FROM alert_history WHERE triggered_at < ?`, cutoff)
	if err != nil {
		return total, err
	}
	n, _ = res.RowsAffected()
	total += n

	return total, nil
}

// GetSnapshotCount returns total number of snapshots in database.
func (db *DB) GetSnapshotCount() (int64, error) {
	var count int64
	err := db.conn.QueryRow(`SELECT COUNT(*) FROM resource_snapshots`).Scan(&count)
	return count, err
}

// GetState reads a value from agent_state.
func (db *DB) GetState(key string) (string, error) {
	var val string
	err := db.conn.QueryRow(`SELECT value FROM agent_state WHERE key = ?`, key).Scan(&val)
	if err == sql.ErrNoRows {
		return "", nil
	}
	return val, err
}

// SetState writes a value to agent_state.
func (db *DB) SetState(key, value string) error {
	_, err := db.conn.Exec(
		`INSERT INTO agent_state (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = ?`,
		key, value, value,
	)
	return err
}
