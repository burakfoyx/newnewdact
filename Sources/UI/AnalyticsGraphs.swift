import SwiftUI
import Charts
import Combine

// MARK: - Resource Types
enum ResourceType: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case network = "Network"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .cpu: return .blue
        case .memory: return .purple
        case .network: return .cyan
        }
    }
    
    var unit: String {
        switch self {
        case .cpu: return "%"
        case .memory: return "MB"
        case .network: return "MB/s"
        }
    }
}

// MARK: - View Model
@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var selectedResource: ResourceType = .cpu
    @Published var selectedRange: AnalyticsTimeRange = .hour24
    @Published var history: [ResourceSnapshot] = []
    
    // Derived Stats for Grid
    @Published var avgCPU: Double = 0
    @Published var peakCPU: Double = 0
    @Published var avgRAM: Double = 0
    @Published var peakRAM: Double = 0
    
    // Insights
    @Published var insightText: String = "Analyzing server behavior..."
    
    private var serverId: String
    private var timer: Timer?
    
    init(serverId: String) {
        self.serverId = serverId
        loadHistory()
    }
    
    func refresh() {
        loadHistory()
    }
    
    private func loadHistory() {
        // Fetch from ResourceStore
        let snapshots = ResourceStore.shared.fetchSnapshots(
            serverId: serverId,
            from: Date().addingTimeInterval(-selectedRange.duration)
        )
        self.history = snapshots
        calculateStats()
        generateInsights()
    }
    
    /// Efficiently adds a live snapshot to the graph without reloading from DB
    func appendLiveSnapshot(_ stats: ServerStats) {
        let snapshot = ResourceSnapshot(
            serverId: serverId,
            panelId: "app",
            timestamp: Date(),
            cpuPercent: stats.resources.cpuAbsolute,
            memoryUsedBytes: stats.resources.memoryBytes,
            memoryLimitBytes: 0, // Not critical for graph
            diskUsedBytes: stats.resources.diskBytes,
            diskLimitBytes: 0,
            networkRxBytes: stats.resources.networkRxBytes,
            networkTxBytes: stats.resources.networkTxBytes,
            uptimeMs: stats.resources.uptime ?? 0
        )
        
        self.history.append(snapshot)
        
        // Trim history if it gets too long (keep last 24h worth roughly)
        // 1 point per sec = 86400 points max, reasonable to trim if needed
        if history.count > 5000 {
            history.removeFirst(history.count - 5000)
        }
        
        calculateStats()
        // Skip insights generation on every tick to save CPU
    }
    
    private func calculateStats() {
        guard !history.isEmpty else {
            avgCPU = 0; peakCPU = 0; avgRAM = 0; peakRAM = 0
            return
        }
        
        var sumCPU: Double = 0
        var maxCPU: Double = 0
        var sumRAM: Double = 0
        var maxRAM: Double = 0
        
        for item in history {
            let cpu = item.cpuPercent
            sumCPU += cpu
            if cpu > maxCPU { maxCPU = cpu }
            
            let ram = Double(item.memoryUsedBytes) / 1024 / 1024
            sumRAM += ram
            if ram > maxRAM { maxRAM = ram }
        }
        
        avgCPU = sumCPU / Double(history.count)
        peakCPU = maxCPU
        avgRAM = sumRAM / Double(history.count)
        peakRAM = maxRAM
    }
    
    private func generateInsights() {
        guard !history.isEmpty else {
            insightText = "Not enough data to generate insights."
            return
        }
        
        // Logic:
        // 1. Idle: Avg CPU < 5% and Avg RAM < 20% (assuming simplified RAM check for now)
        // 2. Capped: Peak CPU > 95% frequently
        // 3. Underutilized RAM: Peak RAM < 20% of limit? (We don't have limit handy here easily without snapshot context, but snapshot has limit)
        // Let's use simplified logic based on user request.
        
        if avgCPU < 5.0 {
            insightText = "This server is idle. Consider consolidating workloads."
        } else if peakCPU > 95.0 {
            insightText = "This server is capped by the CPU. Performance degradation may occur."
        } else if avgRAM < 512 && peakRAM < 512 { // Arbitrary low threshold example
             insightText = "This server is under-utilizing RAM. Consider lowering allocation."
        } else {
            insightText = "Server resource usage is within normal parameters."
        }
        
        // Refine based on selected range
        insightText += " (Based on \(selectedRange.displayName))"
    }
    
    var yAxisMax: Double {
        switch selectedResource {
        case .cpu:
            return max(100.0, peakCPU * 1.1)
        case .memory:
            return max(100.0, peakRAM * 1.2) // Add 20% padding above peak
        case .network:
            let peak = history.map { Double($0.networkRxBytes + $0.networkTxBytes) / 1024 / 1024 }.max() ?? 0
            return max(1.0, peak * 1.2) // At least 1 MB/s scale
        }
    }
    
    var chartData: [ChartDataPoint] {
        // Optimization: Downsample if we have too many points
        let maxPoints = 60
        let stride = max(1, history.count / maxPoints)
        
        // Filter history based on stride
        let visibleSnapshots: [ResourceSnapshot]
        if stride > 1 {
            visibleSnapshots = history.enumerated()
                .filter { $0.offset % stride == 0 }
                .map { $0.element }
        } else {
            visibleSnapshots = history
        }
        
        return visibleSnapshots.map { snapshot in
            let value: Double
            switch selectedResource {
            case .cpu: value = snapshot.cpuPercent
            case .memory: value = Double(snapshot.memoryUsedBytes) / 1024 / 1024
            case .network: value = Double(snapshot.networkRxBytes + snapshot.networkTxBytes) / 1024 / 1024
            }
            return ChartDataPoint(
                timestamp: snapshot.timestamp, 
                value: value, 
                origin: snapshot.dataOrigin
            )
        }
    }
}


// MARK: - Main View
struct ServerResourceUsageView: View {
    let stats: ServerStats
    let limits: ServerLimits
    let serverId: String
    let refreshTrigger: UUID // Trigger for external refresh
    
    @StateObject private var vm: AnalyticsViewModel
    
    init(stats: ServerStats, limits: ServerLimits, serverId: String, refreshTrigger: UUID = UUID()) {
        self.stats = stats
        self.limits = limits
        self.serverId = serverId
        self.refreshTrigger = refreshTrigger
        _vm = StateObject(wrappedValue: AnalyticsViewModel(serverId: serverId))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            
            // 1. Uptime Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.pink)
                Text("Uptime")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatUptime(stats.resources.uptime ?? 0))
                    .font(.title2.monospaced().bold())
                    .foregroundStyle(.white)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            // 2. 2x2 Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatBox(title: "Avg CPU", value: String(format: "%.1f%%", vm.avgCPU), icon: "cpu", color: .blue)
                StatBox(title: "Peak CPU", value: String(format: "%.1f%%", vm.peakCPU), icon: "waveform.path.ecg", color: .red)
                StatBox(title: "Avg RAM", value: String(format: "%.0f MB", vm.avgRAM), icon: "memorychip", color: .purple)
                StatBox(title: "Peak RAM", value: String(format: "%.0f MB", vm.peakRAM), icon: "chart.bar.fill", color: .orange)
            }
            
            // 3. Charts Section
            VStack(spacing: 16) {
                // Controls
                HStack {
                    Picker("Resource", selection: $vm.selectedResource) {
                        ForEach(ResourceType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Menu {
                        ForEach(AnalyticsTimeRange.allCases) { range in
                            Button {
                                vm.selectedRange = range
                                vm.refresh()
                            } label: {
                                Label(range.displayName, systemImage: "clock")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Chart
                Group {
                    if vm.chartData.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Gathering Data...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Chart(vm.chartData) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Source", point.origin.rawValue.capitalized))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Source", point.origin.rawValue.capitalized))
                    .opacity(0.3)
                    
                    // Only show points if density is low enough for readability/performance
                    if vm.chartData.count <= 40 {
                        PointMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(by: .value("Source", point.origin.rawValue.capitalized))
                    }
                }
                .chartForegroundStyleScale([
                    "App": vm.selectedResource.color,
                    "Agent": .green
                ])
                .chartYScale(domain: 0...vm.yAxisMax)
                .animation(.easeInOut, value: vm.chartData)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                if vm.selectedRange == .days7 || vm.selectedRange == .days30 {
                                    Text(date, format: .dateTime.month().day())
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(date, format: .dateTime.hour().minute())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.secondary.opacity(0.2))
                        if let doubleValue = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(doubleValue))\(vm.selectedResource.unit)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                    } // End else
                } // End Group
                .frame(height: 250)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            
            // 4. Insights Footer
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Resource Insight")
                        .font(.headline)
                }
                
                Text(vm.insightText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .onAppear {
            vm.refresh()
        }
        .onChange(of: vm.selectedRange) { _, _ in
            vm.refresh()
        }
        .onChange(of: stats.resources.cpuAbsolute) { _, _ in
             // Efficiently update graph with live data without hitting DB
             Task { @MainActor in
                 vm.appendLiveSnapshot(stats)
             }
        }
        .onChange(of: refreshTrigger) { _, _ in
            vm.refresh()
        }
    }
    
    private func formatUptime(_ milliseconds: Int64) -> String {
        let seconds = milliseconds / 1000
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title3.bold())
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
