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
                evaluate(rule: rule, server: server, stats: stats, state: state, context: context)
            }
        } catch {
            print("Failed to fetch alert rules: \(error)")
        }
    }
    
    private func evaluate(rule: AlertRule, server: ServerAttributes, stats: ResourceUsage, state: String, context: ModelContext) {
        // Basic cooldown check (e.g., don't alert again for 30 mins)
        if let last = rule.lastTriggeredAt {
            if Date().timeIntervalSince(last) < Double(rule.durationSeconds) { return }
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
            trigger(rule: rule, value: currentValue, context: context)
        }
    }
    
    private func trigger(rule: AlertRule, value: Double, context: ModelContext) {
        // 1. Check Quiet Hours
        if isInQuietHours() {
            print("🔕 Alert suppressed due to Quiet Hours")
            return
        }
        
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
        
        // 2. Send Notification
        NotificationService.shared.sendNotification(title: title, body: body)
        
        // 3. Log Event
        let event = AlertEvent(
            ruleId: rule.id,
            serverId: rule.serverId,
            serverName: rule.serverName,
            metric: rule.metric,
            value: value,
            threshold: rule.threshold,
            message: body
        )
        context.insert(event)
        
        rule.lastTriggeredAt = Date()
    }
    
    private func isInQuietHours() -> Bool {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "quietHoursEnabled") { return false }
        
        // AppStorage stores Date as Double (TimeIntervalSinceReferenceDate)
        let startInterval = defaults.double(forKey: "quietHoursStart")
        let endInterval = defaults.double(forKey: "quietHoursEnd")
        
        let start = Date(timeIntervalSinceReferenceDate: startInterval)
        let end = Date(timeIntervalSinceReferenceDate: endInterval)
        
        let calendar = Calendar.current
        let now = Date()
        
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)
        
        guard let nowMinute = nowComponents.hour.map({ $0 * 60 + (nowComponents.minute ?? 0) }),
              let startMinute = startComponents.hour.map({ $0 * 60 + (startComponents.minute ?? 0) }),
              let endMinute = endComponents.hour.map({ $0 * 60 + (endComponents.minute ?? 0) }) else {
            return false
        }
        
        if startMinute < endMinute {
            // Same day (e.g., 10 AM to 4 PM)
            return nowMinute >= startMinute && nowMinute < endMinute
        } else {
            // Overnight (e.g., 10 PM to 7 AM)
            return nowMinute >= startMinute || nowMinute < endMinute
        }
    }
}
