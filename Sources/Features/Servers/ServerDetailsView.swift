import SwiftUI
import Combine

struct ServerDetailsView: View {
    let server: ServerAttributes
    
    // State
    @StateObject private var viewModel = ServerDetailsViewModel()
    @StateObject private var alertManager: AlertManager
    @State private var selectedTab: ServerTab = .console
    @State private var isToolbarVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var refreshTrigger = UUID() // Trigger for forcing graph refresh
    
    init(server: ServerAttributes) {
        self.server = server
        _alertManager = StateObject(wrappedValue: AlertManager(serverId: server.identifier))
    }
    
    // Environment
    @Environment(\.dismiss) private var dismiss
    
    enum ServerTab: String, CaseIterable, Identifiable {
        case console = "Console"
        case analytics = "Stats"
        case alerts = "Alerts"
        case backups = "Backups"
        case details = "Details"
        // Secondary Tabs
        case files = "Files"
        case network = "Network"
        case databases = "Databases"
        case schedules = "Schedules"
        case users = "Users"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .console: return "terminal"
            case .analytics: return "chart.xyaxis.line"
            case .alerts: return "exclamationmark.triangle"
            case .backups: return "archivebox"
            case .files: return "folder"
            case .network: return "network"
            case .databases: return "cylinder.split.1x2"
            case .schedules: return "clock"
            case .users: return "person.2"
            case .details: return "info.circle"
            }
        }
        
        // Helper to determine if it's a primary tab (Toolbar vs TabBar)
        var isPrimary: Bool {
            switch self {
            case .console, .analytics, .alerts, .backups, .details: return true
            default: return false
            }
        }
    }
    var body: some View {
        ZStack {
            // 1. Main Content using TabView
            TabView(selection: $selectedTab) {
                ForEach(ServerTab.allCases.filter { $0.isPrimary }) { tab in
                    primaryTabContent(for: tab)
                    .navigationTitle(server.name)
                    .navigationBarTitleDisplayMode(.large)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
                }
            }

            .onReceive(viewModel.$currentStats.debounce(for: .seconds(2), scheduler: RunLoop.main)) { stats in
                if let stats = stats {
                    alertManager.checkStats(stats, limits: server.limits)
                    
                    Task { @MainActor in
                        ResourceCollector.shared.recordFromStats(
                            serverId: server.identifier,
                            panelId: "current",
                            cpu: stats.resources.cpuAbsolute,
                            memory: stats.resources.memoryBytes,
                            memoryLimit: Int64((server.limits.memory ?? 0) * 1024 * 1024),
                            disk: stats.resources.diskBytes,
                            diskLimit: Int64((server.limits.disk ?? 0) * 1024 * 1024),
                            networkRx: stats.resources.networkRxBytes,
                            networkTx: stats.resources.networkTxBytes,
                            uptimeMs: stats.resources.uptime ?? 0
                        )
                    }
                }
            }
            
            // 2. Alert Overlay
            if !alertManager.activeAlerts.isEmpty {
                VStack {
                    ServerAlertOverlay(manager: alertManager)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Menu {
                            Button {
                                viewModel.sendPowerSignal(signal: "start")
                            } label: {
                                Label("Start", systemImage: "play.fill")
                            }
                            
                            Button {
                                viewModel.sendPowerSignal(signal: "restart")
                            } label: {
                                Label("Restart", systemImage: "arrow.clockwise")
                            }
                            
                            Button {
                                viewModel.sendPowerSignal(signal: "stop")
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            
                            Button(role: .destructive) {
                                viewModel.sendPowerSignal(signal: "kill")
                            } label: {
                                Label("Kill", systemImage: "flame.fill")
                            }
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                        
                        Menu {
                            ForEach(ServerTab.allCases.filter { !$0.isPrimary }) { tab in
                                NavigationLink(value: tab) {
                                    Label(tab.rawValue, systemImage: tab.icon)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(for: ServerTab.self) { tab in
            secondaryTabContent(for: tab)
            .navigationTitle(tab.rawValue)
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task {
                await viewModel.connect(to: server)
            }
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
    
    // MARK: - Tab Content Helpers (broken out to help Swift type-checker)
    
    @ViewBuilder
    private func primaryTabContent(for tab: ServerTab) -> some View {
        switch tab {
        case .console:
            ConsoleSection(server: server, viewModel: viewModel)
        case .analytics:
            ScrollView { AnalyticsSection(server: server, viewModel: viewModel, refreshTrigger: $refreshTrigger) }
        case .alerts:
            ScrollView { AlertsSection(manager: alertManager) }
        case .backups:
            ScrollView { BackupSection(server: server) }
        case .details:
            ServerDetailsInfoView(server: server, viewModel: viewModel)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func secondaryTabContent(for tab: ServerTab) -> some View {
        switch tab {
        case .files:
            FileManagerView(server: server)
        case .network:
            ScrollView { NetworkSection(server: server) }
        case .databases:
            ScrollView { DatabaseSection(server: server) }
        case .schedules:
            ScrollView { ScheduleSection(server: server) }
        case .users:
            ScrollView { UserSection(server: server) }
        default:
            EmptyView()
        }
    }
    
    // Custom header view removed in favor of standard navigation bar
}

// MARK: - Sub-Sections

struct ConsoleSection: View {
    let server: ServerAttributes
    @ObservedObject var viewModel: ServerDetailsViewModel
    @FocusState private var isInputFocused: Bool
    
    // Smart auto-scroll state
    @State private var isAutoScrollEnabled = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Terminal")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.secondary)
                Spacer()
                
                // Auto-Scroll Toggle
                Button {
                    isAutoScrollEnabled.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isAutoScrollEnabled ? "arrow.down.to.line" : "pause.circle.fill")
                        Text(isAutoScrollEnabled ? "Auto" : "Paused")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(isAutoScrollEnabled ? .blue : .orange)
                    .background(
                        isAutoScrollEnabled ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1),
                        in: Capsule()
                    )
                }
                
                if viewModel.isConnected {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Live")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1), in: Capsule())
                } else {
                     HStack(spacing: 6) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("Offline")
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1), in: Capsule())
                }
            }
            .padding()
            .padding()
            .background(.regularMaterial)
            
            // Console Output (Scrollable)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.consoleLines) { line in
                            Text(line.text)
                                .font(.custom("Menlo", size: 12))
                                .foregroundStyle(.white)
                                // Text selection must be on the individual Text views
                                // or the container, usually works best on the container in LazyVStack
                        }
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .id("bottom")
                }
                .onChange(of: viewModel.consoleLines.count) { _, _ in
                    if isAutoScrollEnabled {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onTapGesture {
                    isInputFocused = false
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            
            // Input Area
            HStack {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                TextField("Enter command...", text: $viewModel.commandInput)
                    .focused($isInputFocused)
                    .onSubmit {
                        viewModel.sendCommand()
                        isInputFocused = true
                    }
                    .submitLabel(.send)
                    .foregroundStyle(.primary)
                    .font(.custom("Menlo", size: 14))
            }
            .padding()
            .padding()
            .background(.regularMaterial)
        }

        .cornerRadius(12)
        .padding(16)
        .padding(.bottom, isInputFocused ? 0 : 0)
    }
}



struct AnalyticsSection: View {
    let server: ServerAttributes
    @ObservedObject var viewModel: ServerDetailsViewModel
    @Binding var refreshTrigger: UUID
    
    @State private var showingSyncAlert = false
    @State private var syncResultTitle = ""
    @State private var syncResultMessage = ""
    @State private var isSyncing = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with Sync Button
            HStack {
                Text("Analytics")
                    .font(.headline)
                Spacer()
                
                Button {
                    guard !isSyncing else { return }
                    isSyncing = true
                    
                    Task {
                        // Feedback vibration
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Force Sync
                        let (count, error) = await ResourceCollector.shared.syncHistoricalMetrics()
                        
                        // Force Refresh Graph
                        await MainActor.run {
                            if let error = error {
                                syncResultTitle = "Sync Failed"
                                syncResultMessage = error.localizedDescription
                            } else {
                                syncResultTitle = "Sync Complete"
                                syncResultMessage = "Imported \(count) new data points from Agent."
                            }
                            
                            isSyncing = false
                            showingSyncAlert = true
                            refreshTrigger = UUID()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isSyncing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(isSyncing ? "Syncing..." : "Sync Agent")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white)
                }
                .disabled(isSyncing)
            }
            .alert(syncResultTitle, isPresented: $showingSyncAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(syncResultMessage)
            }

            if let stats = viewModel.currentStats {
                ServerResourceUsageView(
                    stats: stats,
                    limits: server.limits,
                    serverId: server.identifier,
                    refreshTrigger: refreshTrigger
                )
            } else {
                ProgressView()
                    .frame(height: 200)
            }
        }
        .padding(16)
    }
}

struct PlaceholderSection: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
            Text(description)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - ViewModel

// MARK: - ViewModel

class ServerDetailsViewModel: ObservableObject {
    struct ConsoleLine: Identifiable, Equatable {
        let id = UUID()
        let text: AttributedString
    }
    
    @Published var consoleLines: [ConsoleLine] = []
    @Published var commandInput: String = ""
    @Published var currentStats: ServerStats?
    @Published var isConnected = false
    @Published var errorMessage: String?
    
    // Console line buffer — accumulates lines and flushes to @Published every 150ms
    private var lineBuffer: [ConsoleLine] = []
    private var flushTimer: Timer?
    
    private var serverId: String?
    private var cancellables = Set<AnyCancellable>()
    
    func connect(to server: ServerAttributes) async {
        self.serverId = server.identifier
        
        await MainActor.run {
            self.consoleLines = [ConsoleLine(text: AttributedString("Connecting to \(server.name)..."))]
            self.isConnected = false
            self.errorMessage = nil
            // Don't clear currentStats immediately to avoid flickering if re-connecting
        }
        
        // 0. Fetch Initial Stats via HTTP (Fast load)
        Task {
            do {
                let stats = try await PterodactylClient.shared.fetchResources(serverId: server.identifier)
                await MainActor.run {
                    self.currentStats = stats
                }
            } catch {
                print("Failed to fetch initial stats: \(error)")
            }
        }
        
        do {
            // 1. Get Websocket Credentials
            let (socketUrl, token) = try await PterodactylClient.shared.fetchWebsocketDetails(serverId: server.identifier)
            
            // 2. Connect Websocket
            guard let url = URL(string: socketUrl) else {
                throw PterodactylError.serializationError
            }
            
            // Get Panel URL for Origin header
            let origin = await PterodactylClient.shared.getPanelURL()?.absoluteString
            
            WebSocketClient.shared.connect(url: url, token: token, origin: origin)
            
            // 3. Subscribe to events
            setupSubscriptions()
            
            await MainActor.run {
                self.isConnected = true
            }
            
        } catch {
            await MainActor.run {
                self.consoleLines.append(ConsoleLine(text: AttributedString("Connection failed: \(error.localizedDescription)")))
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func disconnect() {
        WebSocketClient.shared.disconnect()
        cancellables.removeAll()
        flushTimer?.invalidate()
        flushTimer = nil
        isConnected = false
    }
    
    /// Flushes buffered lines to @Published, collapsing multiple mutations into one
    private func flushLineBuffer() {
        guard !lineBuffer.isEmpty else { return }
        consoleLines.append(contentsOf: lineBuffer)
        lineBuffer.removeAll(keepingCapacity: true)
        if consoleLines.count > 1000 {
            consoleLines.removeFirst(consoleLines.count - 1000)
        }
    }
    
    private func setupSubscriptions() {
        // Start flush timer — fires every 150ms to batch console updates
        flushTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flushLineBuffer()
            }
        }
        
        WebSocketClient.shared.eventPublisher
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .consoleOutput(let text):
                    Task.detached {
                        let newLines = text.components(separatedBy: .newlines).map { line in
                            ConsoleLine(text: AnsiParser.parse(line))
                        }
                        await MainActor.run {
                            self.lineBuffer.append(contentsOf: newLines)
                        }
                    }
                case .stats(let json):
                    Task.detached {
                        self.parseStats(json)
                    }
                case .status(let status):
                    Task { @MainActor in
                        self.updateStatus(status)
                    }
                case .connected:
                    Task { @MainActor in
                        self.lineBuffer.append(ConsoleLine(text: AttributedString("[System] Connected to server stream.")))
                        self.isConnected = true
                    }
                case .disconnected:
                    Task { @MainActor in
                        self.lineBuffer.append(ConsoleLine(text: AttributedString("[System] Disconnected.")))
                        self.isConnected = false
                    }
                case .installOutput(let text):
                    Task { @MainActor in
                        self.lineBuffer.append(ConsoleLine(text: AttributedString("[Install] \(text)")))
                    }
                case .daemonError(let error):
                    Task { @MainActor in
                        self.lineBuffer.append(ConsoleLine(text: AttributedString("[Error] \(error)")))
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func parseStats(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        // Manual parsing since the WS JSON structure might differ slightly or we want to map to ServerStats
        // Expected format: {"memory_bytes":..., "cpu_absolute":..., "disk_bytes":..., "network": { "rx_bytes":..., "tx_bytes":... }, "state":..., "uptime":...}
        
        let memory = (json["memory_bytes"] as? Int64) ?? 0
        let cpu = (json["cpu_absolute"] as? Double) ?? 0.0
        let disk = (json["disk_bytes"] as? Int64) ?? 0
        let state = (json["state"] as? String) ?? "unknown"
        let uptime = (json["uptime"] as? Int64) ?? 0
        
        var rx: Int64 = 0
        var tx: Int64 = 0
        
        if let network = json["network"] as? [String: Any] {
            rx = (network["rx_bytes"] as? Int64) ?? 0
            tx = (network["tx_bytes"] as? Int64) ?? 0
        }
        
        let resources = ResourceUsage(
            memoryBytes: memory,
            cpuAbsolute: cpu,
            diskBytes: disk,
            networkRxBytes: rx,
            networkTxBytes: tx,
            uptime: uptime
        )
        
        self.currentStats = ServerStats(
            currentState: state,
            isSuspended: false,
            resources: resources
        )
    }
    
    private func updateStatus(_ status: String) {
        // Only update status in current stats if we have stats, or create a placeholder
        if let stats = currentStats {
            // Need to create new struct since it's immutable
            self.currentStats = ServerStats(
                currentState: status,
                isSuspended: stats.isSuspended,
                resources: stats.resources
            )
        }
    }
    
    func sendCommand() {
        guard !commandInput.isEmpty else { return }
        let cmd = commandInput
        commandInput = "" // clear input immediately
        
        WebSocketClient.shared.sendCommand(cmd)
    }
    
    func sendPowerSignal(signal: String) {
        WebSocketClient.shared.sendPowerAction(signal)
    }
}

struct AlertsSection: View {
    @ObservedObject var manager: AlertManager
    @State private var showingAlertConfig = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 1. Configuration Link
            Button {
                showingAlertConfig = true
            } label: {
                HStack {
                    Text("Manage Rules")
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            .sheet(isPresented: $showingAlertConfig) {
                AlertRulesView(manager: manager)
            }
            
            Text("Set up custom triggers for CPU, RAM, and Disk usage.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding(16)
    }
}
