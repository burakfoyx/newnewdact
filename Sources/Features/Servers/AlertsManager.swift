import SwiftUI
import Combine

// MARK: - Alert Models


struct AlertRule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var metric: AlertMetric
    var condition: AlertCondition
    var threshold: Double
    var isEnabled: Bool = true
    
    var description: String {
        "\(metric.rawValue) \(condition.symbol) \(Int(threshold))\(metric.unit)"
    }
}

// MARK: - Alert Manager

class AlertManager: ObservableObject {
    @Published var rules: [AlertRule] = [] {
        didSet {
            save()
        }
    }
    @Published var activeAlerts: [String] = []
    
    // Global toggle for all alerts
    @Published var areAlertsEnabled: Bool = true {
        didSet {
            save()
        }
    }
    
    // Status alerts (Server Offline/Starting etc) - separate from rules for now, or could be a rule type?
    // User requested specific metrics, but "Server Status" is still useful. 
    // I'll keep a simple boolean for "Status Notifications" alongside rules.
    @Published var statusAlertsEnabled: Bool = true {
        didSet {
            save()
        }
    }
    
    private let serverId: String
    private let saveKey: String
    
    init(serverId: String) {
        self.serverId = serverId
        self.saveKey = "alert_rules_\(serverId)"
        load()
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let savedState = try? JSONDecoder().decode(AlertManagerState.self, from: data) {
            self.rules = savedState.rules
            self.areAlertsEnabled = savedState.areAlertsEnabled
            self.statusAlertsEnabled = savedState.statusAlertsEnabled
        }
    }
    
    func save() {
        let state = AlertManagerState(rules: rules, areAlertsEnabled: areAlertsEnabled, statusAlertsEnabled: statusAlertsEnabled)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    func addRule(_ rule: AlertRule) {
        rules.append(rule)
    }
    
    func deleteRule(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
    }
    
    func checkStats(_ stats: ServerStats, limits: ServerLimits) {
        guard areAlertsEnabled else {
             activeAlerts = []
             return
        }
        
        var newAlerts: [String] = []
        
        // 1. Status Check
        if statusAlertsEnabled && (stats.currentState == "offline" || stats.currentState == "stopping") {
            newAlerts.append("Server is \(stats.currentState)")
        }
        
        // 2. Rules Check
        for rule in rules where rule.isEnabled {
            if checkRule(rule, stats: stats, limits: limits) {
                newAlerts.append(rule.description)
            }
        }
        
        // Update UI logic
        DispatchQueue.main.async {
            self.activeAlerts = newAlerts
        }
    }
    
    private func checkRule(_ rule: AlertRule, stats: ServerStats, limits: ServerLimits) -> Bool {
        let value = getValue(for: rule.metric, stats: stats, limits: limits)
        
        switch rule.condition {
        case .above:
            return value > rule.threshold
        case .below:
            return value < rule.threshold
        }
    }
    
    private func getValue(for metric: AlertMetric, stats: ServerStats, limits: ServerLimits) -> Double {
        switch metric {
        case .cpu:
            return stats.resources.cpuAbsolute
        case .memory:
            // Calculate percentage
            guard let limit = limits.memory, limit > 0 else { return 0 } // Cannot calc % without limit
            let used = Double(stats.resources.memoryBytes) / 1024 / 1024
            return (used / Double(limit)) * 100
        case .disk:
            guard let limit = limits.disk, limit > 0 else { return 0 }
            let used = Double(stats.resources.diskBytes) / 1024 / 1024
            return (used / Double(limit)) * 100
        case .network:
            // MB/s
            let totalBytes = stats.resources.networkRxBytes + stats.resources.networkTxBytes
            return Double(totalBytes) / 1024 / 1024
        case .offline:
            return stats.currentState.lowercased() == "offline" ? 1.0 : 0.0
        }
    }
}

// Helper struct for persistence
struct AlertManagerState: Codable {
    var rules: [AlertRule]
    var areAlertsEnabled: Bool
    var statusAlertsEnabled: Bool
}

// MARK: - Legacy Overlay (Kept for compatibility, updated to use manager)
struct ServerAlertOverlay: View {
    @ObservedObject var manager: AlertManager
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(manager.activeAlerts, id: \.self) { alert in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                    Text(alert)
                        .foregroundStyle(.white)
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .background(Color.red.opacity(0.6))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.3)))
            }
        }
        .padding(.top, 60) // Safe area padding estimate
        .animation(.spring, value: manager.activeAlerts)
    }
}
