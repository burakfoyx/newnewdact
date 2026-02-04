import Foundation
import Combine
import BackgroundTasks

// MARK: - Resource Collector
/// Collects and stores resource usage data periodically
@MainActor
class ResourceCollector: ObservableObject {
    static let shared = ResourceCollector()
    
    @Published var isCollecting = false
    @Published var lastCollectionTime: Date?
    @Published var collectionErrors: [String] = []
    
    private var collectionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let store = ResourceStore.shared
    
    // Collection settings based on tier
    var collectionInterval: TimeInterval {
        switch SubscriptionManager.shared.currentTier {
        case .free:
            return 300  // 5 minutes for free tier (limited storage)
        case .pro, .host:
            return 60   // 1 minute for paid tiers
        }
    }
    
    private init() {}
    
    // MARK: - Start Collection
    func startCollecting() {
        guard !isCollecting else { return }
        
        isCollecting = true
        print("📊 Starting resource collection every \(collectionInterval)s")
        
        // Collect immediately
        Task {
            await collectAllServers()
        }
        
        // Schedule periodic collection
        collectionTimer = Timer.scheduledTimer(
            withTimeInterval: collectionInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.collectAllServers()
            }
        }
    }
    
    // MARK: - Stop Collection
    func stopCollecting() {
        collectionTimer?.invalidate()
        collectionTimer = nil
        isCollecting = false
        print("📊 Stopped resource collection")
    }
    
    // MARK: - Collect All Servers
    func collectAllServers() async {
        let accounts = AccountManager.shared.accounts
        
        for account in accounts {
            await collectForPanel(account: account)
        }
        
        lastCollectionTime = Date()
        
        // Cleanup old data based on tier
        let retentionDays = dataRetentionDays()
        store.cleanupOldData(retentionDays: retentionDays)
    }
    
    // MARK: - Collect for Single Panel
    private func collectForPanel(account: PanelAccount) async {
        do {
            // Configure client for this panel
            PterodactylClient.shared.configure(
                baseURL: account.panelURL,
                apiKey: account.apiKey
            )
            
            // Fetch all servers
            let servers = try await PterodactylClient.shared.listServers()
            
            for server in servers {
                await collectForServer(server: server, panelId: account.id.uuidString)
            }
        } catch {
            collectionErrors.append("Panel \(account.panelName): \(error.localizedDescription)")
            // Keep only last 10 errors
            if collectionErrors.count > 10 {
                collectionErrors.removeFirst()
            }
        }
    }
    
    // MARK: - Collect for Single Server
    private func collectForServer(server: Server, panelId: String) async {
        do {
            let resources = try await PterodactylClient.shared.getServerResources(identifier: server.identifier)
            
            let snapshot = ResourceSnapshot(
                serverId: server.identifier,
                panelId: panelId,
                timestamp: Date(),
                cpuPercent: resources.cpuAbsolute,
                memoryUsedBytes: resources.memoryBytes,
                memoryLimitBytes: resources.memoryLimitBytes,
                diskUsedBytes: resources.diskBytes,
                diskLimitBytes: resources.diskLimitBytes,
                networkRxBytes: resources.networkRxBytes,
                networkTxBytes: resources.networkTxBytes
            )
            
            store.save(snapshot)
        } catch {
            // Silent fail for individual servers - don't spam errors
            print("Failed to collect for server \(server.name): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Retention Policy
    private func dataRetentionDays() -> Int {
        switch SubscriptionManager.shared.currentTier {
        case .free:
            return 1    // Free tier: 24 hours only
        case .pro:
            return 30   // Pro tier: 30 days
        case .host:
            return 180  // Host tier: 180 days
        }
    }
    
    // MARK: - Background Task Registration
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
        
        let operationTask = Task {
            await ResourceCollector.shared.collectAllServers()
        }
        
        task.expirationHandler = {
            operationTask.cancel()
        }
        
        Task {
            _ = await operationTask.result
            task.setTaskCompleted(success: true)
        }
    }
}

// MARK: - Server Resource Extension
extension ServerResources {
    var memoryLimitBytes: Int64 {
        // Get from server limits or use a default
        // This should come from server.limits in real implementation
        4 * 1024 * 1024 * 1024 // Default 4GB
    }
    
    var diskLimitBytes: Int64 {
        // Get from server limits
        50 * 1024 * 1024 * 1024 // Default 50GB
    }
}
