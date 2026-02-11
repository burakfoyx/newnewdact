import SwiftUI
import Combine

struct AlertConfig: Codable, Equatable {
    var cpuThreshold: Double
    var memoryThreshold: Double
    var diskThreshold: Double
    var isEnabled: Bool
    var statusAlerts: Bool
    
    init() {
        self.cpuThreshold = 90.0
        self.memoryThreshold = 90.0
        self.diskThreshold = 90.0
        self.isEnabled = true
        self.statusAlerts = true
    }
}

class AlertManager: ObservableObject {
    @Published var config: AlertConfig {
        didSet {
            save()
        }
    }
    @Published var activeAlerts: [String] = []
    
    private let serverId: String
    private let saveKey: String
    
    init(serverId: String) {
        self.serverId = serverId
        self.saveKey = "alert_config_\(serverId)"
        
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let saved = try? JSONDecoder().decode(AlertConfig.self, from: data) {
            self.config = saved
        } else {
            self.config = AlertConfig()
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    func checkStats(_ stats: ServerStats, limits: ServerLimits) {
        guard config.isEnabled else {
             activeAlerts = []
             return
        }
        
        var newAlerts: [String] = []
        
        // Status
        if config.statusAlerts && (stats.currentState == "offline" || stats.currentState == "stopping") {
            newAlerts.append("Server is \(stats.currentState)")
        }
        
        // CPU
        if stats.resources.cpuAbsolute > config.cpuThreshold {
            newAlerts.append("High CPU: \(Int(stats.resources.cpuAbsolute))%")
        }
        
        // Memory
        if let memoryLimit = limits.memory, memoryLimit > 0 {
            let limitBytes = Int64(memoryLimit) * 1024 * 1024
            let usagePercent = (Double(stats.resources.memoryBytes) / Double(limitBytes)) * 100
             if usagePercent > config.memoryThreshold {
                newAlerts.append("High Memory: \(Int(usagePercent))%")
            }
        }
        
        // Disk
        if let diskLimit = limits.disk, diskLimit > 0 {
            let limitBytes = Int64(diskLimit) * 1024 * 1024
            let usagePercent = (Double(stats.resources.diskBytes) / Double(limitBytes)) * 100
            if usagePercent > config.diskThreshold {
                newAlerts.append("High Disk Usage: \(Int(usagePercent))%")
            }
        }
        
        DispatchQueue.main.async {
            self.activeAlerts = newAlerts
        }
    }
}

struct AlertConfigView: View {
    @ObservedObject var manager: AlertManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Alerts", isOn: $manager.config.isEnabled)
                }
                
                if manager.config.isEnabled {
                    Section("Triggers") {
                         Toggle("Status Changes", isOn: $manager.config.statusAlerts)
                    }
                    
                    Section("Thresholds") {
                        VStack(alignment: .leading) {
                            Text("CPU Limit: \(Int(manager.config.cpuThreshold))%")
                            Slider(value: $manager.config.cpuThreshold, in: 50...200, step: 10)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Memory Limit: \(Int(manager.config.memoryThreshold))%")
                            Slider(value: $manager.config.memoryThreshold, in: 50...100, step: 5)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Disk Limit: \(Int(manager.config.diskThreshold))%")
                            Slider(value: $manager.config.diskThreshold, in: 50...100, step: 5)
                        }
                    }
                }
            }
            .navigationTitle("Alert Configuration")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

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
