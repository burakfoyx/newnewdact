import Foundation
import Combine
import BackgroundTasks

// MARK: - Resource Collector
/// Collects and stores resource usage data periodically
/// Note: Since Pterodactyl Client API doesn't have a direct resources endpoint,
/// we collect from WebSocket stats updates when the user views a server.
@MainActor
class ResourceCollector: ObservableObject {
    static let shared = ResourceCollector()
    
    @Published var isCollecting = false
    @Published var lastCollectionTime: Date?
    @Published var snapshotCount: Int = 0
    
    private let store = ResourceStore.shared
    
    // Track last collection per server to avoid hitting the store for every stats update
    private var lastCollectionPerServer: [String: Date] = [:]
    
    // Polling Timer
    private var pollingTimer: Timer?
    
    // Collection settings based on tier
    var collectionInterval: TimeInterval {
        switch SubscriptionManager.shared.currentTier {
        case .free:
            return 60   // 1 minute for free tier (still useful for testing)
        case .pro, .host:
            return 30   // 30 seconds for paid tiers
        }
    }
    
    private init() {}
    
    // MARK: - Polling Logic
    func startPolling() {
        stopPolling()
        print("Starting background polling (Interval: \(collectionInterval)s)...")
        pollingTimer = Timer.scheduledTimer(withTimeInterval: collectionInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollServers()
            }
        }
        // Trigger immediate poll
        Task { @MainActor in
            await pollServers()
            // Sync history from agent to fill gaps
            _ = await syncHistoricalMetrics()
        }
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("Stopped background polling")
    }
    
    private func pollServers() async {
        do {
            // 1. Fetch all servers
            let servers = try await PterodactylClient.shared.fetchServers()
            
            // 2. Iterate and fetch resources
            for server in servers {
                do {
                    let stats = try await PterodactylClient.shared.fetchResources(serverId: server.identifier)
                    
                    let memoryLimit = Int64((server.limits.memory ?? 0) * 1024 * 1024)
                    let diskLimit = Int64((server.limits.disk ?? 0) * 1024 * 1024)
                    
                    recordFromStats(
                        serverId: server.identifier,
                        panelId: "app", // Tag as app data (polled)
                        cpu: stats.resources.cpuAbsolute,
                        memory: stats.resources.memoryBytes,
                        memoryLimit: memoryLimit,
                        disk: stats.resources.diskBytes,
                        diskLimit: diskLimit,
                        networkRx: stats.resources.networkRxBytes,
                        networkTx: stats.resources.networkTxBytes,
                        uptimeMs: stats.resources.uptime ?? 0
                    )
                    
                    // Check Alerts
                    let alertManager = AlertManager(serverId: server.identifier)
                    AlertEngine.shared.checkAlerts(
                        server: server,
                        stats: stats.resources,
                        state: stats.currentState,
                        rules: alertManager.rules
                    )
                    
                } catch {
                    print("Failed to poll stats for server \(server.name): \(error)")
                }
            }
        } catch {
            print("Failed to poll server list: \(error)")
        }
    }
    
    // MARK: - Record Snapshot (called from ConsoleView when stats are received)
    /// Call this when WebSocket stats are received
    func recordSnapshot(
        serverId: String,
        panelId: String,
        cpuPercent: Double,
        memoryUsedBytes: Int64,
        memoryLimitBytes: Int64,
        diskUsedBytes: Int64,
        diskLimitBytes: Int64,
        networkRxBytes: Int64,
        networkTxBytes: Int64,
        uptimeMs: Int64
    ) {
        // Check in-memory cache first (faster than hitting store)
        if let lastCollection = lastCollectionPerServer[serverId] {
            let timeSinceLastCollection = Date().timeIntervalSince(lastCollection)
            if timeSinceLastCollection < collectionInterval {
                // Skip - too soon since last snapshot
                return
            }
        }
        
        print("📊 Recording snapshot for server \(serverId): CPU=\(cpuPercent)%")
        
        let snapshot = ResourceSnapshot(
            serverId: serverId,
            panelId: panelId,
            timestamp: Date(),
            cpuPercent: cpuPercent,
            memoryUsedBytes: memoryUsedBytes,
            memoryLimitBytes: memoryLimitBytes,
            diskUsedBytes: diskUsedBytes,
            diskLimitBytes: diskLimitBytes,
            networkRxBytes: networkRxBytes,
            networkTxBytes: networkTxBytes,
            uptimeMs: uptimeMs
        )
        
        store.save(snapshot)
        lastCollectionTime = Date()
        lastCollectionPerServer[serverId] = Date()
        snapshotCount += 1
        isCollecting = true
        
        print("📊 Snapshot saved! Total count: \(snapshotCount)")
        
        // Cleanup old data periodically (not on every save)
        if snapshotCount % 10 == 0 {
            let retentionDays = dataRetentionDays()
            store.cleanupOldData(retentionDays: retentionDays)
        }
    }
    
    // MARK: - Record from Server Stats
    /// Convenience method to record from ConsoleViewModel stats
    func recordFromStats(
        serverId: String,
        panelId: String,
        cpu: Double,
        memory: Int64,
        memoryLimit: Int64,
        disk: Int64,
        diskLimit: Int64,
        networkRx: Int64,
        networkTx: Int64,
        uptimeMs: Int64
    ) {
        recordSnapshot(
            serverId: serverId,
            panelId: panelId,
            cpuPercent: cpu,
            memoryUsedBytes: memory,
            memoryLimitBytes: memoryLimit,
            diskUsedBytes: disk,
            diskLimitBytes: diskLimit,
            networkRxBytes: networkRx,
            networkTxBytes: networkTx,
            uptimeMs: uptimeMs
        )
    }
    
    // MARK: - Force Record (ignores interval)
    func forceRecord(
        serverId: String,
        panelId: String,
        cpu: Double,
        memory: Int64,
        memoryLimit: Int64,
        disk: Int64,
        diskLimit: Int64
    ) {
        // Clear the cache for this server to force recording
        lastCollectionPerServer.removeValue(forKey: serverId)
        
        recordFromStats(
            serverId: serverId,
            panelId: panelId,
            cpu: cpu,
            memory: memory,
            memoryLimit: memoryLimit,
            disk: disk,
            diskLimit: diskLimit,
            networkRx: 0,
            networkTx: 0,
            uptimeMs: 0
        )
    }
    
    // MARK: - Data Retention Policy
    private func dataRetentionDays() -> Int {
        switch SubscriptionManager.shared.currentTier {
        case .free:
            return 1    // Free tier: 24 hours only
        case .pro:
            return 7    // Pro tier: 7 days
        case .host:
            return 30   // Host tier: 30 days
        }
    }
    
    // MARK: - Historical Sync
    
    /// Syncs historical metrics from the agent's metrics.json file
    func syncHistoricalMetrics() async -> (Int, Error?) {
        guard let fm = AgentManager.shared.getFileManager() else { 
            return (0, NSError(domain: "Agent", code: 404, userInfo: [NSLocalizedDescriptionKey: "Agent file manager not available"]))
        }
        
        print("🔄 Syncing historical metrics from agent...")
        do {
            // 1. Read JSON (Network IO)
            let export = try await fm.readMetrics()
            let myPanelId = "agent"
            
            print("📦 Read metrics export with \(export.servers.count) servers")
            
            var newSnapshots: [ResourceSnapshot] = []
            var total scanned = 0
            
            // 2. Process in memory
            for (serverId, optSnapshots) in export.servers {
                guard let snapshots = optSnapshots else { continue }
                
                // Get latest timestamp for this server to avoid duplicates
                // Note: database access is fast enough here since it's one query per server
                let latest = store.fetchLatestSnapshot(serverId: serverId, panelId: "agent")
                let latestTime = latest?.timestamp ?? Date.distantPast
                
                print("🔹 Server \(serverId): Found \(snapshots.count) snapshots. Latest DB: \(latestTime)")
                
                for snap in snapshots {
                    scanned += 1
                    if snap.timestamp > latestTime {
                        let snapshot = ResourceSnapshot(
                            serverId: serverId,
                            panelId: myPanelId,
                            timestamp: snap.timestamp,
                            cpuPercent: snap.cpuPercent,
                            memoryUsedBytes: snap.memBytes,
                            memoryLimitBytes: snap.memLimit,
                            diskUsedBytes: snap.diskBytes,
                            diskLimitBytes: snap.diskLimit,
                            networkRxBytes: snap.netRx,
                            networkTxBytes: snap.netTx,
                            uptimeMs: snap.uptimeMs
                        )
                        newSnapshots.append(snapshot)
                    }
                }
            }
            
            // 3. Batch Save (Database IO)
            if !newSnapshots.isEmpty {
                print("💾 Batch saving \(newSnapshots.count) records...")
                store.saveBatch(newSnapshots)
                print("✅ Synced \(newSnapshots.count) new data points")
            } else {
                print("✨ No new data to sync (scanned \(scanned) points)")
            }
            
            return (newSnapshots.count, nil)
            
        } catch {
            print("❌ Failed to sync historical metrics: \(error)")
            return (0, error)
        }
    }
    
    // MARK: - Background Task Registration (for future use)
    static func registerBackgroundTasks() {
        // Register background fetch task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.xyidactyl.resourcecollection",
            using: nil
        ) { task in
            handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
    }
    
    static func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.xyidactyl.resourcecollection")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📊 Scheduled background resource collection")
        } catch {
            print("Failed to schedule background task: \(error)")
        }
    }
    
    private static func handleBackgroundTask(task: BGAppRefreshTask) {
        // Schedule next background task
        scheduleBackgroundTask()
        
        // For now, just complete - background collection requires more infrastructure
        task.setTaskCompleted(success: true)
    }
}
