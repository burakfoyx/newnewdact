import Foundation
import SwiftData

@MainActor
class AlertEngine: ObservableObject {
    static let shared = AlertEngine()
    
    private init() {}
    
    func checkAlerts(server: ServerAttributes, stats: ResourceUsage, state: String, context: ModelContext) {
        // Fetch rules for this server
        let serverId = server.identifier
        
        // Note: Predicate inside FetchDescriptor in SwiftData has limitations on capturing variables.
        // We often have to fetch all and filter or use simpler predicates.
        // For now, let's try direct predicate.
        
        let descriptor = FetchDescriptor<AlertRule>(
            predicate: #Predicate<AlertRule> { rule in
                rule.serverId == serverId && rule.isEnabled == true
            }
        )
        
        do {
            let rules = try context.fetch(descriptor)
            for rule in rules {
                evaluate(rule: rule, server: server, stats: stats, state: state)
            }
        } catch {
            print("Failed to fetch alert rules: \(error)")
        }
    }
    
    private func evaluate(rule: AlertRule, server: ServerAttributes, stats: ResourceUsage, state: String) {
        // Basic cooldown check (e.g., don't alert again for 30 mins)
        if let last = rule.lastTriggeredAt {
            if Date().timeIntervalSince(last) < 1800 { return }
        }
        
        var isTriggered = false
        var currentValue: Double = 0
        
        switch rule.metric {
        case .cpu:
            currentValue = stats.cpuAbsolute
        case .memory:
            // Calculate %
            let limit = Double(server.limits.memory ?? 0) * 1024 * 1024
            let used = Double(stats.memoryBytes)
            if limit > 0 { currentValue = (used / limit) * 100 }
        case .disk:
            let limit = Double(server.limits.disk ?? 0) * 1024 * 1024
            let used = Double(stats.diskBytes)
            if limit > 0 { currentValue = (used / limit) * 100 }
        case .offline:
            if state == "offline" || state == "stopped" { isTriggered = true }
        }
        
        if rule.metric != .offline {
            if rule.condition == .above && currentValue > rule.threshold {
                isTriggered = true
            } else if rule.condition == .below && currentValue < rule.threshold {
                isTriggered = true
            }
        }
        
        if isTriggered {
            trigger(rule: rule, value: currentValue)
        }
    }
    
    private func trigger(rule: AlertRule, value: Double) {
        let title = "Alert: \(rule.serverName)"
        var body = ""
        
        switch rule.metric {
        case .cpu:
            body = "CPU usage is \(Int(value))% (Threshold: \(Int(rule.threshold))%)"
        case .memory:
            body = "Memory usage is \(Int(value))% (Threshold: \(Int(rule.threshold))%)"
        case .disk:
            body = "Disk usage is \(Int(value))% (Threshold: \(Int(rule.threshold))%)"
        case .offline:
            body = "Server is detected offline/stopped."
        }
        
        print("🔔 Alert Triggered: \(title) - \(body)")
        NotificationService.shared.sendNotification(title: title, body: body)
        
        rule.lastTriggeredAt = Date()
    }
}
