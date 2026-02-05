import Foundation
import SwiftData

// MARK: - SwiftData Model for Resource Snapshots
@Model
final class ResourceSnapshotEntity {
    var id: UUID
    var serverId: String
    var panelId: String
    var timestamp: Date
    
    var cpuPercent: Double
    var memoryUsedBytes: Int64
    var memoryLimitBytes: Int64
    var diskUsedBytes: Int64
    var diskLimitBytes: Int64
    var networkRxBytes: Int64
    var networkTxBytes: Int64
    var uptimeMs: Int64
    
    init(
        id: UUID = UUID(),
        serverId: String,
        panelId: String,
        timestamp: Date = Date(),
        cpuPercent: Double,
        memoryUsedBytes: Int64,
        memoryLimitBytes: Int64,
        diskUsedBytes: Int64,
        diskLimitBytes: Int64,
        networkRxBytes: Int64,
        networkTxBytes: Int64,
        uptimeMs: Int64
    ) {
        self.id = id
        self.serverId = serverId
        self.panelId = panelId
        self.timestamp = timestamp
        self.cpuPercent = cpuPercent
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryLimitBytes = memoryLimitBytes
        self.diskUsedBytes = diskUsedBytes
        self.diskLimitBytes = diskLimitBytes
        self.networkRxBytes = networkRxBytes
        self.networkTxBytes = networkTxBytes
        self.uptimeMs = uptimeMs
    }
    
    /// Convert to value type
    func toSnapshot() -> ResourceSnapshot {
        ResourceSnapshot(
            id: id,
            serverId: serverId,
            panelId: panelId,
            timestamp: timestamp,
            cpuPercent: cpuPercent,
            memoryUsedBytes: memoryUsedBytes,
            memoryLimitBytes: memoryLimitBytes,
            diskUsedBytes: diskUsedBytes,
            diskLimitBytes: diskLimitBytes,
            networkRxBytes: networkRxBytes,
            networkTxBytes: networkTxBytes,
            uptimeMs: uptimeMs
        )
    }
}

// MARK: - Resource Store
@MainActor
class ResourceStore: ObservableObject {
    static let shared = ResourceStore()
    
    private var modelContainer: ModelContainer?
    var modelContext: ModelContext?
    
    private init() {
        setupContainer()
    }
    
    private func setupContainer() {
        do {
            let schema = Schema([ResourceSnapshotEntity.self, AlertRule.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: config)
            if let container = modelContainer {
                modelContext = ModelContext(container)
            }
        } catch {
            print("Failed to setup SwiftData: \(error)")
        }
    }
    
    // MARK: - Save Snapshot
    func save(_ snapshot: ResourceSnapshot) {
        guard let context = modelContext else { return }
        
        let entity = ResourceSnapshotEntity(
            id: snapshot.id,
            serverId: snapshot.serverId,
            panelId: snapshot.panelId,
            timestamp: snapshot.timestamp,
            cpuPercent: snapshot.cpuPercent,
            memoryUsedBytes: snapshot.memoryUsedBytes,
            memoryLimitBytes: snapshot.memoryLimitBytes,
            diskUsedBytes: snapshot.diskUsedBytes,
            diskLimitBytes: snapshot.diskLimitBytes,
            networkRxBytes: snapshot.networkRxBytes,
            networkTxBytes: snapshot.networkTxBytes,
            uptimeMs: snapshot.uptimeMs
        )
        
        context.insert(entity)
        
        do {
            try context.save()
        } catch {
            print("Failed to save snapshot: \(error)")
        }
    }
    
    // MARK: - Fetch Snapshots
    func fetchSnapshots(
        serverId: String,
        from startDate: Date,
        to endDate: Date = Date()
    ) -> [ResourceSnapshot] {
        guard let context = modelContext else { return [] }
        
        let predicate = #Predicate<ResourceSnapshotEntity> { entity in
            entity.serverId == serverId &&
            entity.timestamp >= startDate &&
            entity.timestamp <= endDate
        }
        
        let descriptor = FetchDescriptor<ResourceSnapshotEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        do {
            let entities = try context.fetch(descriptor)
            return entities.map { $0.toSnapshot() }
        } catch {
            print("Failed to fetch snapshots: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch Latest Snapshot
    func fetchLatestSnapshot(serverId: String) -> ResourceSnapshot? {
        guard let context = modelContext else { return nil }
        
        let predicate = #Predicate<ResourceSnapshotEntity> { entity in
            entity.serverId == serverId
        }
        
        var descriptor = FetchDescriptor<ResourceSnapshotEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        do {
            let entities = try context.fetch(descriptor)
            return entities.first?.toSnapshot()
        } catch {
            print("Failed to fetch latest snapshot: \(error)")
            return nil
        }
    }
    
    // MARK: - Calculate Analytics
    func calculateSummary(
        serverId: String,
        serverName: String,
        timeRange: AnalyticsTimeRange
    ) -> ServerAnalyticsSummary? {
        let snapshots = fetchSnapshots(
            serverId: serverId,
            from: timeRange.startDate
        )
        
        guard !snapshots.isEmpty else { return nil }
        
        // Calculate averages
        let avgCPU = snapshots.map(\.cpuPercent).reduce(0, +) / Double(snapshots.count)
        let avgMemory = snapshots.map(\.memoryPercent).reduce(0, +) / Double(snapshots.count)
        let avgDisk = snapshots.map(\.diskPercent).reduce(0, +) / Double(snapshots.count)
        
        // Calculate availability
        let upCount = snapshots.filter { $0.uptimeMs > 0 }.count
        let uptimeAvailability = Double(upCount) / Double(snapshots.count) * 100
        
        // Calculate peaks
        let peakCPU = snapshots.map(\.cpuPercent).max() ?? 0
        let peakMemory = snapshots.map(\.memoryPercent).max() ?? 0
        let peakDisk = snapshots.map(\.diskPercent).max() ?? 0
        
        // Calculate trends
        let cpuTrend = calculateTrend(values: snapshots.map(\.cpuPercent))
        let memoryTrend = calculateTrend(values: snapshots.map(\.memoryPercent))
        
        // Network totals
        let totalRx = snapshots.map(\.networkRxBytes).max() ?? 0
        let totalTx = snapshots.map(\.networkTxBytes).max() ?? 0
        
        // Insights
        let isUnderutilized = avgCPU < 10 && avgMemory < 20
        let isOverallocated = peakCPU > 90 || peakMemory > 90
        
        return ServerAnalyticsSummary(
            serverId: serverId,
            serverName: serverName,
            periodStart: timeRange.startDate,
            periodEnd: Date(),
            avgCPU: avgCPU,
            avgMemoryPercent: avgMemory,
            avgDiskPercent: avgDisk,
            uptimeAvailability: uptimeAvailability,
            peakCPU: peakCPU,
            peakMemoryPercent: peakMemory,
            peakDiskPercent: peakDisk,
            cpuTrend: cpuTrend,
            memoryTrend: memoryTrend,
            isUnderutilized: isUnderutilized,
            isOverallocated: isOverallocated,
            totalNetworkRx: totalRx,
            totalNetworkTx: totalTx,
            currentUptimeMs: snapshots.last?.uptimeMs ?? 0
        )
    }
    
    private func calculateTrend(values: [Double]) -> UsageTrend {
        guard values.count >= 3 else { return .stable }
        
        // Simple linear regression to determine trend
        let n = Double(values.count)
        let xMean = (n - 1) / 2
        let yMean = values.reduce(0, +) / n
        
        var numerator: Double = 0
        var denominator: Double = 0
        
        for (i, y) in values.enumerated() {
            let x = Double(i)
            numerator += (x - xMean) * (y - yMean)
            denominator += (x - xMean) * (x - xMean)
        }
        
        guard denominator != 0 else { return .stable }
        let slope = numerator / denominator
        
        // Calculate variance for volatility detection
        let variance = values.map { pow($0 - yMean, 2) }.reduce(0, +) / n
        let stdDev = sqrt(variance)
        
        if stdDev > yMean * 0.5 {
            return .volatile
        } else if slope > 0.5 {
            return .increasing
        } else if slope < -0.5 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    // MARK: - Chart Data
    func getChartData(
        serverId: String,
        metric: AnalyticsMetric,
        timeRange: AnalyticsTimeRange
    ) -> [ChartDataPoint] {
        let snapshots = fetchSnapshots(
            serverId: serverId,
            from: timeRange.startDate
        )
        
        return snapshots.map { snapshot in
            let value: Double
            switch metric {
            case .cpu:
                value = snapshot.cpuPercent
            case .memory:
                value = snapshot.memoryPercent
            case .disk:
                value = snapshot.diskPercent
            case .networkRx:
                value = Double(snapshot.networkRxBytes) / 1_000_000 // MB
            case .networkTx:
                value = Double(snapshot.networkTxBytes) / 1_000_000 // MB
            case .uptime:
                value = Double(snapshot.uptimeMs) / 3_600_000 // Hours
            }
            return ChartDataPoint(timestamp: snapshot.timestamp, value: value)
        }
    }
    
    // MARK: - Cleanup Old Data
    func cleanupOldData(retentionDays: Int) {
        guard let context = modelContext else { return }
        
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: Date()
        ) ?? Date()
        
        let predicate = #Predicate<ResourceSnapshotEntity> { entity in
            entity.timestamp < cutoffDate
        }
        
        do {
            try context.delete(model: ResourceSnapshotEntity.self, where: predicate)
            try context.save()
            print("Cleaned up snapshots older than \(retentionDays) days")
        } catch {
            print("Failed to cleanup old data: \(error)")
        }
    }
}

// MARK: - Analytics Metric
enum AnalyticsMetric: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case networkRx = "Network In"
    case networkTx = "Network Out"
    case uptime = "Uptime"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .networkRx: return "arrow.down.circle"
        case .networkTx: return "arrow.up.circle"
        case .uptime: return "clock.arrow.circlepath"
        }
    }
    
    var unit: String {
        switch self {
        case .cpu, .memory, .disk: return "%"
        case .networkRx, .networkTx: return "MB"
        case .uptime: return "Hr"
        }
    }
    
    var color: String {
        switch self {
        case .cpu: return "blue"
        case .memory: return "purple"
        case .disk: return "orange"
        case .networkRx: return "green"
        case .networkTx: return "teal"
        case .uptime: return "pink"
        }
    }
}
