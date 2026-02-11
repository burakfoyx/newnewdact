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
        case .network: return "MB/s" // Rate
        }
    }
}

// MARK: - Persistence Manager
class AnalyticsPersistence {
    static let shared = AnalyticsPersistence()
    private let fileManager = FileManager.default
    
    func save(history: ResourceHistoryData, serverId: String) {
        let url = getFileURL(serverId: serverId)
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: url)
        } catch {
            print("Failed to save analytics: \(error)")
        }
    }
    
    func load(serverId: String) -> ResourceHistoryData? {
        let url = getFileURL(serverId: serverId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ResourceHistoryData.self, from: data)
    }
    
    private func getFileURL(serverId: String) -> URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("analytics_\(serverId).json")
    }
}

struct ResourceHistoryData: Codable {
    var points: [HistoryPoint]
}

struct HistoryPoint: Codable, Identifiable {
    let id: Date
    let cpu: Double
    let memory: Double
    let networkIn: Double
    let networkOut: Double
    
    var totalNetwork: Double { networkIn + networkOut }
}

// MARK: - View Model
class AnalyticsViewModel: ObservableObject {
    @Published var selectedResource: ResourceType = .cpu
    @Published var selectedRange: GraphRange = .oneHour
    @Published var history: [HistoryPoint] = []
    
    // Default to Free plan for now, could be injected
    var userPlan: UserPlan = .free 
    
    private var serverId: String
    private var timer: AnyCancellable?
    
    init(serverId: String) {
        self.serverId = serverId
        loadHistory()
        
        // Auto-save periodically
        timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.saveHistory()
        }
    }
    
    func addPoint(stats: ServerStats) {
        let point = HistoryPoint(
            id: Date(),
            cpu: stats.resources.cpuAbsolute,
            memory: Double(stats.resources.memoryBytes) / 1024 / 1024, // MB
            networkIn: Double(stats.resources.networkRxBytes) / 1024 / 1024,
            networkOut: Double(stats.resources.networkTxBytes) / 1024 / 1024
        )
        history.append(point)
        pruneHistory()
    }
    
    private func pruneHistory() {
        let maxAge = userPlan.retentionPeriod
        let cutoff = Date().addingTimeInterval(-maxAge)
        if let firstIndex = history.firstIndex(where: { $0.id >= cutoff }) {
            if firstIndex > 0 {
                history.removeFirst(firstIndex)
            }
        }
    }
    
    private func loadHistory() {
        if let data = AnalyticsPersistence.shared.load(serverId: serverId) {
            self.history = data.points
            pruneHistory()
        }
    }
    
    func saveHistory() {
        let data = ResourceHistoryData(points: history)
        AnalyticsPersistence.shared.save(history: data, serverId: serverId)
    }
    
    var filteredData: [HistoryPoint] {
        let cutoff = Date().addingTimeInterval(-selectedRange.duration)
        return history.filter { $0.id >= cutoff }
    }
}

// MARK: - Main View
struct ServerResourceUsageView: View {
    let stats: ServerStats
    let limits: ServerLimits
    
    @StateObject private var vm: AnalyticsViewModel
    
    init(stats: ServerStats, limits: ServerLimits, serverId: String) {
        self.stats = stats
        self.limits = limits
        _vm = StateObject(wrappedValue: AnalyticsViewModel(serverId: serverId)) 
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Summary Badges
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
            
            // Main Chart Card
            VStack(spacing: 16) {
                // Controls
                ChartControls(vm: vm)
                
                // Chart
                ResourceChartView(data: vm.filteredData, resourceType: vm.selectedResource)
                    .frame(height: 250)
                
                // Current Value Display
                HStack {
                    Text("Current:")
                        .foregroundStyle(.secondary)
                    Text(getCurrentValueString())
                        .font(.headline.monospaced())
                        .foregroundStyle(.white)
                    Spacer()
                    if let limit = getLimitString() {
                        Text("Limit: \(limit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .liquidGlassEffect()
        }
        .onChange(of: stats.resources.cpuAbsolute) { _, _ in
            vm.addPoint(stats: stats)
        }
        .onAppear {
             // In a real app we would pass the actual server ID
             // For now we might reset or load basics
        }
    }
    
    func getCurrentValueString() -> String {
        switch vm.selectedResource {
        case .cpu: return String(format: "%.1f%%", stats.resources.cpuAbsolute)
        case .memory: return formatBytes(stats.resources.memoryBytes)
        case .network: 
            let total = stats.resources.networkRxBytes + stats.resources.networkTxBytes
            return formatBytes(total) + "/s" // Assuming rate
        }
    }
    
    func getLimitString() -> String? {
        switch vm.selectedResource {
        case .cpu: return limits.cpu.map { "\($0)%" }
        case .memory: return limits.memory.map { "\($0)MB" }
        case .network: return nil
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

private struct ChartControls: View {
    @ObservedObject var vm: AnalyticsViewModel
    
    var body: some View {
        HStack {
            Picker("Resource", selection: $vm.selectedResource) {
                ForEach(ResourceType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            Spacer()
            
            Menu {
                ForEach(vm.userPlan.availableRanges) { range in
                    Button {
                        vm.selectedRange = range
                    } label: {
                        Label(range.rawValue, systemImage: "clock")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.selectedRange.rawValue)
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Material.thin)
                .clipShape(Capsule())
            }
        }
    }
}

private struct ResourceChartView: View {
    let data: [HistoryPoint]
    let resourceType: ResourceType
    
    var body: some View {
        Chart(data) { point in
            let value = getValue(for: point, type: resourceType)
            
            LineMark(
                x: .value("Time", point.id),
                y: .value("Value", value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(resourceType.color)
            
            AreaMark(
                x: .value("Time", point.id),
                y: .value("Value", value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [resourceType.color.opacity(0.3), resourceType.color.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.hour().minute())
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.white.opacity(0.1))
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
    
    func getValue(for point: HistoryPoint, type: ResourceType) -> Double {
        switch type {
        case .cpu: return point.cpu
        case .memory: return point.memory
        case .network: return point.totalNetwork
        }
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
