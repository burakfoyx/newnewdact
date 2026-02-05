import Foundation
import SwiftData

enum AlertMetric: String, Codable, CaseIterable, Identifiable {
    case cpu = "cpu"
    case memory = "memory"
    case disk = "disk"
    case offline = "offline"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cpu: return "CPU Usage"
        case .memory: return "Memory Usage"
        case .disk: return "Disk Usage"
        case .offline: return "Server Offline"
        }
    }
    
    var unit: String {
        switch self {
        case .cpu, .memory, .disk: return "%"
        case .offline: return ""
        }
    }
}

enum AlertCondition: String, Codable, CaseIterable, Identifiable {
    case above = "above"
    case below = "below"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .above: return "Above"
        case .below: return "Below"
        }
    }
}

@Model
final class AlertRule {
    var id: UUID
    var serverId: String
    var serverName: String
    var metric: AlertMetric
    var condition: AlertCondition
    var threshold: Double
    var durationSeconds: Int // Sustained for X seconds
    var isEnabled: Bool
    var lastTriggeredAt: Date?
    var isMuted: Bool
    
    init(
        id: UUID = UUID(),
        serverId: String,
        serverName: String,
        metric: AlertMetric,
        condition: AlertCondition = .above,
        threshold: Double,
        durationSeconds: Int = 300,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.serverId = serverId
        self.serverName = serverName
        self.metric = metric
        self.condition = condition
        self.threshold = threshold
        self.durationSeconds = durationSeconds
        self.isEnabled = isEnabled
        self.lastTriggeredAt = nil
        self.isMuted = false
    }
}
