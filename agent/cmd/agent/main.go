package main

import (
	"os"
	"os/signal"
	"syscall"

	"github.com/xyidactyl/agent/internal/config"
	"github.com/xyidactyl/agent/internal/control"
	"github.com/xyidactyl/agent/internal/database"
	"github.com/xyidactyl/agent/internal/engine"
	"github.com/xyidactyl/agent/internal/logging"
	"github.com/xyidactyl/agent/internal/pterodactyl"
	"github.com/xyidactyl/agent/internal/push"
	"github.com/xyidactyl/agent/internal/security"
	"github.com/xyidactyl/agent/internal/status"
)

const version = "1.0.0"

func main() {
	// --- Load Config ---
	cfg, err := config.Load()
	if err != nil {
		logging.Error("Failed to load config: %v", err)
		os.Exit(1)
	}

	// --- Init Logging ---
	if err := logging.Init(cfg.DataDir, cfg.LogLevel); err != nil {
		logging.Error("Failed to init logging: %v", err)
		os.Exit(1)
	}
	defer logging.Close()

	logging.Info("========================================")
	logging.Info("  XYIDactyl Agent v%s", version)
	logging.Info("  Panel: %s", cfg.PanelURL)
	logging.Info("  Sampling: %ds | Retention: %dd", cfg.SamplingInterval, cfg.RetentionDays)
	logging.Info("  Push provider: %s", cfg.PushProvider)
	logging.Info("========================================")

	// --- Init Database ---
	db, err := database.Open(cfg.DataDir)
	if err != nil {
		logging.Error("Failed to open database: %v", err)
		os.Exit(1)
	}
	defer db.Close()

	// --- Init Crypto ---
	crypto, err := security.NewCrypto(cfg.AgentSecret)
	if err != nil {
		logging.Error("Failed to init crypto: %v", err)
		os.Exit(1)
	}
	logging.Info("Crypto initialized")

	// --- Init Control Loader ---
	loader := control.NewLoader(cfg.ControlFilePath)
	if err := loader.LoadInitial(); err != nil {
		logging.Error("Failed to load control.json: %v", err)
		os.Exit(1)
	}
	loader.Start()
	defer loader.Stop()

	// --- Init Push Provider ---
	var pushProvider push.Provider
	switch cfg.PushProvider {
	case "apns":
		if cfg.APNsKeyBase64 == "" || cfg.APNsKeyID == "" || cfg.APNsTeamID == "" || cfg.APNsBundleID == "" {
			logging.Error("APNs configuration incomplete. Set APNS_KEY_BASE64, APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID")
			os.Exit(1)
		}
		apns, err := push.NewAPNsProvider(cfg.APNsKeyBase64, cfg.APNsKeyID, cfg.APNsTeamID, cfg.APNsBundleID)
		if err != nil {
			logging.Error("Failed to init APNs provider: %v", err)
			os.Exit(1)
		}
		pushProvider = apns
		logging.Info("APNs push provider initialized")
	default:
		pushProvider = push.NewDevProvider()
		logging.Info("Dev push provider initialized (push notifications logged to console)")
	}

	// --- Init Pterodactyl Client ---
	pteroClient := pterodactyl.NewClient(cfg.PanelURL)

	// --- Init Status Writer ---
	statusWriter := status.NewWriter(cfg.DataDir)

	// --- Init Engines ---
	alertEvaluator := engine.NewAlertEvaluator(db, pushProvider)
	automationExecutor := engine.NewAutomationExecutor(db, pteroClient, pushProvider, cfg.MaxConcurrent)

	monitor := engine.NewMonitor(
		cfg.SamplingInterval,
		pteroClient,
		db,
		loader,
		crypto,
		alertEvaluator,
		automationExecutor,
		statusWriter,
	)

	cleanup := engine.NewCleanup(db, cfg.RetentionDays)

	// --- Start ---
	monitor.Start()
	cleanup.Start()

	logging.Info("🚀 Agent is running. Waiting for signals...")

	// --- Graceful Shutdown ---
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
	sig := <-sigCh

	logging.Info("Received signal %s, shutting down...", sig)

	monitor.Stop()
	cleanup.Stop()
	loader.Stop()

	logging.Info("Agent stopped gracefully")
}
