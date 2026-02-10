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

struct ServerResourceUsageView: View {
    let stats: ServerStats
    let limits: ServerLimits
    
    // Mock history data for now - in a real app this would come from a view model history buffer
    // using random generation based on current value to simulate history
    @State private var cpuHistory: [Double] = Array(repeating: 0, count: 20)
    @State private var memoryHistory: [Double] = Array(repeating: 0, count: 20)
    @State private var networkHistory: [Double] = Array(repeating: 0, count: 20)
    
    var body: some View {
        VStack(spacing: 16) {
            // Summary Status
            HStack {
                StatusBadge(state: stats.currentState)
                Spacer()
                Text("Uptime: " + (formatUptime(stats.resources.uptime ?? 0)))
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, 8)
            
            // CPU
            LiquidLineChart(
                data: cpuHistory,
                color: .blue,
                title: "CPU Load",
                value: String(format: "%.1f%%", stats.resources.cpuAbsolute),
                limit: limits.cpu.map { "\($0)%" } ?? "∞"
            )
            
            // RAM
            LiquidLineChart(
                data: memoryHistory,
                color: .purple,
                title: "Memory",
                value: formatBytes(stats.resources.memoryBytes),
                limit: limits.memory.map { "\($0)MB" }
            )
            
            // Network (I/O)
            LiquidLineChart(
                data: networkHistory,
                color: .cyan,
                title: "Network I/O",
                value: formatBytes(stats.resources.networkRxBytes + stats.resources.networkTxBytes),
                limit: nil
            )
        }
        .onChange(of: stats.resources.cpuAbsolute) { _, newValue in
            updateHistory(array: &cpuHistory, newValue: newValue)
        }
        .onChange(of: stats.resources.memoryBytes) { _, newValue in
            updateHistory(array: &memoryHistory, newValue: Double(newValue))
        }
        .onChange(of: stats.resources.networkRxBytes) { _, _ in
             // Simplify network to total traffic for the graph
            let total = Double(stats.resources.networkRxBytes + stats.resources.networkTxBytes)
            updateHistory(array: &networkHistory, newValue: total)
        }
        .onAppear {
             // Initialize with current values
             updateHistory(array: &cpuHistory, newValue: stats.resources.cpuAbsolute)
             updateHistory(array: &memoryHistory, newValue: Double(stats.resources.memoryBytes))
             let total = Double(stats.resources.networkRxBytes + stats.resources.networkTxBytes)
             updateHistory(array: &networkHistory, newValue: total)
        }
    }
    
    private func updateHistory(array: inout [Double], newValue: Double) {
        withAnimation(.easeInOut) {
            if array.count >= 20 {
                array.removeFirst()
            }
            array.append(newValue)
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
                .shadow(color: color.opacity(0.5), radius: 4)
            
            Text(state.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule().strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
