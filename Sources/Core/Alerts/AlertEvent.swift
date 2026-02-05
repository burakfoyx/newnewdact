import Foundation
import SwiftData

@Model
final class AlertEvent {
    var id: UUID
    var ruleId: UUID? // Optional in case rule is deleted
    var serverId: String
    var serverName: String
    var metric: AlertMetric
    var value: Double
    var threshold: Double
    var timestamp: Date
    var message: String
    
    init(
        id: UUID = UUID(),
        ruleId: UUID?,
        serverId: String,
        serverName: String,
        metric: AlertMetric,
        value: Double,
        threshold: Double,
        timestamp: Date = Date(),
        message: String
    ) {
        self.id = id
        self.ruleId = ruleId
        self.serverId = serverId
        self.serverName = serverName
        self.metric = metric
        self.value = value
        self.threshold = threshold
        self.timestamp = timestamp
        self.message = message
    }
}
