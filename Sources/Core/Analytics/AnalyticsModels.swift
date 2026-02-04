import Foundation
import CoreData

// MARK: - Resource Snapshot Model
/// Represents a single snapshot of server resource usage
struct ResourceSnapshot: Identifiable, Codable {
    let id: UUID
    let serverId: String
    let panelId: String
    let timestamp: Date
    
    // Resource metrics
    let cpuPercent: Double          // 0-100
    let memoryUsedBytes: Int64
    let memoryLimitBytes: Int64
    let diskUsedBytes: Int64
    let diskLimitBytes: Int64
    let networkRxBytes: Int64
    let networkTxBytes: Int64
    let uptimeMs: Int64
    
    // Computed properties
    var memoryPercent: Double {
        guard memoryLimitBytes > 0 else { return 0 }
        return Double(memoryUsedBytes) / Double(memoryLimitBytes) * 100
    }
    
    var diskPercent: Double {
        guard diskLimitBytes > 0 else { return 0 }
        return Double(diskUsedBytes) / Double(diskLimitBytes) * 100
    }
    
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
}

// MARK: - Peak Usage Record
/// Records peak usage for a specific time period
struct PeakUsageRecord: Identifiable, Codable {
    let id: UUID
    let serverId: String
    let date: Date
    let period: PeakPeriod
    
    let peakCPU: Double
    let peakMemoryPercent: Double
    let peakDiskPercent: Double
    let peakNetworkRxRate: Int64     // bytes/second
    let peakNetworkTxRate: Int64
    
    enum PeakPeriod: String, Codable {
        case hourly
        case daily
        case weekly
    }
}

// MARK: - Usage Trend
enum UsageTrend: String, Codable {
    case increasing     // Consistently going up
    case decreasing     // Consistently going down  
    case stable         // Roughly the same
    case volatile       // High variance
    
    var icon: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .volatile: return "waveform.path"
        }
    }
    
    var color: String {
        switch self {
        case .increasing: return "red"
        case .decreasing: return "green"
        case .stable: return "blue"
        case .volatile: return "orange"
        }
    }
}

// MARK: - Server Analytics Summary
/// Aggregated analytics for a server
struct ServerAnalyticsSummary {
    let serverId: String
    let serverName: String
    let periodStart: Date
    let periodEnd: Date
    
    // Averages
    let avgCPU: Double
    let avgMemoryPercent: Double
    let avgDiskPercent: Double
    let uptimeAvailability: Double // 0-100%
    
    // Peaks
    let peakCPU: Double
    let peakMemoryPercent: Double
    let peakDiskPercent: Double
    
    // Trends
    let cpuTrend: UsageTrend
    let memoryTrend: UsageTrend
    
    // Insights
    let isUnderutilized: Bool       // Low avg usage
    let isOverallocated: Bool       // Consistently near limits
    let totalNetworkRx: Int64
    let totalNetworkTx: Int64
    
    // Idle detection
    var idleHoursPerDay: Double {
        // Hours per day where CPU < 5%
        0 // Calculated from snapshots
    }
}

// MARK: - Chart Data Point
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let label: String?
    
    init(timestamp: Date, value: Double, label: String? = nil) {
        self.timestamp = timestamp
        self.value = value
        self.label = label
    }
}

// MARK: - Analytics Time Range
enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case hour1 = "1H"
    case hour6 = "6H"
    case hour24 = "24H"
    case days7 = "7D"
    case days30 = "30D"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .hour1: return "1 Hour"
        case .hour6: return "6 Hours"
        case .hour24: return "24 Hours"
        case .days7: return "7 Days"
        case .days30: return "30 Days"
        }
    }
    
    var seconds: TimeInterval {
        switch self {
        case .hour1: return 3600
        case .hour6: return 3600 * 6
        case .hour24: return 3600 * 24
        case .days7: return 3600 * 24 * 7
        case .days30: return 3600 * 24 * 30
        }
    }
    
    var startDate: Date {
        Date().addingTimeInterval(-seconds)
    }
    
    /// Minimum tier required to access this range
    var requiredTier: UserTier {
        switch self {
        case .hour1, .hour6, .hour24:
            return .free    // Free users get 24h
        case .days7:
            return .pro     // Pro gets 7 days
        case .days30:
            return .pro     // Pro gets 30 days
        }
    }
}
