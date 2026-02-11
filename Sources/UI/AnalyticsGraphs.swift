import SwiftUI
import Charts

// MARK: - Reusable Liquid Graph Component

struct LiquidLineChart: View {
    let data: [Double]
    let color: Color
    let title: String
    let value: String
    let limit: String?
    
    // Smooth curve interpolation
    private var normalizedData: [Double] {
        guard let max = data.max(), max > 0 else { return data }
        return data.map { $0 / max }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    if let limit = limit {
                        Text("/ \(limit)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Value", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(color)
                    
                    AreaMark(
                        x: .value("Time", index),
                        y: .value("Value", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 60)
        }
        .padding()
        .liquidGlassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Resource Usage View

// MARK: - Resource Usage View

struct ServerResourceUsageView: View {
    let stats: ServerStats
    let limits: ServerLimits
    
    // We use a StateObject to hold history so it persists across updates of 'stats'
    @StateObject private var history = ResourceHistory()
    
    var body: some View {
        VStack(spacing: 16) {
            // Summary Status
            HStack {
                StatusBadge(state: stats.currentState)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(formatUptime(stats.resources.uptime ?? 0))
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            
            // CPU
            PremiumGraphCard(
                title: "CPU Load",
                value: String(format: "%.1f%%", stats.resources.cpuAbsolute),
                limit: limits.cpu.map { "\($0)%" },
                data: history.cpu,
                color: .blue
            )
            
            // RAM
            PremiumGraphCard(
                title: "Memory",
                value: formatBytes(stats.resources.memoryBytes),
                limit: limits.memory.map { "\($0)MB" },
                data: history.memory,
                color: .purple
            )
            
            // Network
            PremiumGraphCard(
                title: "Network",
                value: formatBytes(stats.resources.networkRxBytes + stats.resources.networkTxBytes),
                limit: nil,
                data: history.network,
                color: .cyan
            )
        }
        .onChange(of: stats.resources.cpuAbsolute) { _, newValue in
            history.add(cpu: newValue)
        }
        .onChange(of: stats.resources.memoryBytes) { _, newValue in
            history.add(memory: Double(newValue))
        }
        .onChange(of: stats.resources.networkRxBytes) { _, _ in
            let total = Double(stats.resources.networkRxBytes + stats.resources.networkTxBytes)
            history.add(network: total)
        }
        .onAppear {
             // Initial population if needed
             if history.cpu.allSatisfy({ $0 == 0 }) {
                 history.add(cpu: stats.resources.cpuAbsolute)
                 history.add(memory: Double(stats.resources.memoryBytes))
                 history.add(network: Double(stats.resources.networkRxBytes + stats.resources.networkTxBytes))
             }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatUptime(_ milliseconds: Int64) -> String {
        let seconds = milliseconds / 1000
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

class ResourceHistory: ObservableObject {
    @Published var cpu: [Double] = Array(repeating: 0, count: 30)
    @Published var memory: [Double] = Array(repeating: 0, count: 30)
    @Published var network: [Double] = Array(repeating: 0, count: 30)
    
    func add(cpu value: Double) {
        addTo(&cpu, value)
    }
    
    func add(memory value: Double) {
        addTo(&memory, value)
    }
    
    func add(network value: Double) {
        addTo(&network, value)
    }
    
    private func addTo(_ array: inout [Double], _ value: Double) {
        if array.count >= 30 {
            array.removeFirst()
        }
        array.append(value)
    }
}

struct PremiumGraphCard: View {
    let title: String
    let value: String
    let limit: String?
    let data: [Double]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    if let limit = limit {
                        Text("/ \(limit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Value", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(color)
                    
                    AreaMark(
                        x: .value("Time", index),
                        y: .value("Value", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 60)
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct StatusBadge: View {
    let state: String
    
    var color: Color {
        switch state {
        case "running": return .green
        case "starting": return .yellow
        case "stopping": return .orange
        case "offline": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(state.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
