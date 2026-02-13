package logging

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Level represents log severity.
type Level int

const (
	LevelDebug Level = iota
	LevelInfo
	LevelWarn
	LevelError
)

func (l Level) String() string {
	switch l {
	case LevelDebug:
		return "DEBUG"
	case LevelInfo:
		return "INFO"
	case LevelWarn:
		return "WARN"
	case LevelError:
		return "ERROR"
	default:
		return "UNKNOWN"
	}
}

// ParseLevel converts a string to Level.
func ParseLevel(s string) Level {
	switch s {
	case "debug":
		return LevelDebug
	case "info":
		return LevelInfo
	case "warn":
		return LevelWarn
	case "error":
		return LevelError
	default:
		return LevelInfo
	}
}

// Logger provides structured logging to stdout and file.
type Logger struct {
	mu       sync.Mutex
	level    Level
	file     *os.File
	filePath string
	maxSize  int64 // bytes
	stdout   *log.Logger
}

var defaultLogger *Logger

// Init creates the global logger.
func Init(dataDir string, level string) error {
	logDir := filepath.Join(dataDir, "logs")
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return fmt.Errorf("create log dir: %w", err)
	}

	logPath := filepath.Join(logDir, "agent.log")
	f, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return fmt.Errorf("open log file: %w", err)
	}

	defaultLogger = &Logger{
		level:    ParseLevel(level),
		file:     f,
		filePath: logPath,
		maxSize:  128 * 1024, // 128KB (Safe for Pterodactyl Panel view)
		stdout:   log.New(os.Stdout, "", 0),
	}
	return nil
}

// Close closes the log file.
func Close() {
	if defaultLogger != nil && defaultLogger.file != nil {
		defaultLogger.file.Close()
	}
}

func logMsg(level Level, format string, args ...interface{}) {
	if defaultLogger == nil {
		// Fallback to stdout before logger is initialized
		msg := fmt.Sprintf(format, args...)
		fmt.Printf("[%s] %s %s\n", level, time.Now().Format(time.RFC3339), msg)
		return
	}
	if level < defaultLogger.level {
		return
	}

	msg := fmt.Sprintf(format, args...)
	ts := time.Now().Format(time.RFC3339)
	line := fmt.Sprintf("[%s] %s %s", level, ts, msg)

	// Always print to stdout (Pterodactyl console)
	defaultLogger.stdout.Println(line)

	// Write to file
	defaultLogger.mu.Lock()
	defer defaultLogger.mu.Unlock()

	if defaultLogger.file != nil {
		fmt.Fprintln(defaultLogger.file, line)
		defaultLogger.maybeRotate()
	}
}

func (l *Logger) maybeRotate() {
	info, err := l.file.Stat()
	if err != nil || info.Size() < l.maxSize {
		return
	}

	l.file.Close()

	// Keep up to 5 rotated files
	for i := 4; i >= 1; i-- {
		old := fmt.Sprintf("%s.%d", l.filePath, i)
		new := fmt.Sprintf("%s.%d", l.filePath, i+1)
		os.Rename(old, new)
	}
	os.Rename(l.filePath, l.filePath+".1")

	f, err := os.OpenFile(l.filePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		l.file = nil
		return
	}
	l.file = f
}

// Writer returns an io.Writer that writes at the given level (for use with standard log).
func Writer(level Level) io.Writer {
	return &logWriter{level: level}
}

type logWriter struct {
	level Level
}

func (w *logWriter) Write(p []byte) (n int, err error) {
	logMsg(w.level, "%s", string(p))
	return len(p), nil
}

// Debug logs at debug level.
func Debug(format string, args ...interface{}) { logMsg(LevelDebug, format, args...) }

// Info logs at info level.
func Info(format string, args ...interface{}) { logMsg(LevelInfo, format, args...) }

// Warn logs at warn level.
func Warn(format string, args ...interface{}) { logMsg(LevelWarn, format, args...) }

// Error logs at error level.
func Error(format string, args ...interface{}) { logMsg(LevelError, format, args...) }
