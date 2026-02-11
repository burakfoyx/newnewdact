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
    
    init(server: ServerAttributes) {
        self.server = server
        _alertManager = StateObject(wrappedValue: AlertManager(serverId: server.identifier))
        
        // Configure transparent TabBar to show LiquidBackground through it
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        // Optional: Add a thin material if text readability is an issue, but "Liquid Glass" usually implies full custom or blur.
        // Let's keep it transparent to show the LiquidBackgroundView.
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Environment
    @Environment(\.dismiss) private var dismiss
    
    enum ServerTab: String, CaseIterable, Identifiable {
        case console = "Console"
        case analytics = "Stats"
        case alerts = "Alerts"
        case backups = "Backups"
        case settings = "Settings"
        // Secondary Tabs
        case files = "Files"
        case network = "Network"
        case databases = "DBs"
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
            case .settings: return "gearshape"
            }
        }
        
        // Helper to determine if it's a primary tab (Toolbar vs TabBar)
        var isPrimary: Bool {
            switch self {
            case .console, .analytics, .alerts, .backups, .settings: return true
            default: return false
            }
        }
    }
    
    var body: some View {
        ZStack {
            // 0. Base Background (Fallback)
            Color.black
                .ignoresSafeArea()
            
            // 1. Global Liquid Background
            LiquidBackgroundView()
                .ignoresSafeArea()
                .onReceive(viewModel.$currentStats) { stats in
                    if let stats = stats {
                        alertManager.checkStats(stats, limits: server.limits)
                    }
                }
            
            // 2. Main Content using TabView
            TabView(selection: $selectedTab) {
                ForEach(ServerTab.allCases) { tab in
                    Group {
                        ZStack {
                            // Scroll Tracking Background
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .global).minY)
                            }
                            
                            switch tab {
                            case .console:
                                ScrollView { ConsoleSection(server: server, viewModel: viewModel) }
                            case .files:
                                FileManagerView(server: server)
                            case .analytics:
                                ScrollView { AnalyticsSection(server: server, viewModel: viewModel) }
                            case .alerts:
                                ScrollView { AlertsSection(manager: alertManager) }
                            case .backups:
                                ScrollView { BackupSection(server: server) }
                            case .network:
                                ScrollView { NetworkSection(server: server) }
                            case .databases:
                                ScrollView { DatabaseSection(server: server) }
                            case .schedules:
                                ScrollView { ScheduleSection(server: server) }
                            case .users:
                                ScrollView { UserSection(server: server) }
                            case .settings:
                                ScrollView { SettingsSection(server: server, alertManager: alertManager) }
                            }
                        }
                    }
                    .navigationTitle(server.name)
                    .navigationBarTitleDisplayMode(.large)
                    .tabItem {
                        if tab.isPrimary {
                            Label(tab.rawValue, systemImage: tab.icon)
                        }
                    }
                    .tag(tab)
                }
            }
            .background(Color.clear)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let diff = value - lastScrollOffset
                if abs(diff) > 10 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isToolbarVisible = diff > 0
                    }
                    lastScrollOffset = value
                }
            }
            
            // 3. Alert Overlay
            if !alertManager.activeAlerts.isEmpty {
                VStack {
                    ServerAlertOverlay(manager: alertManager)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .toolbar {
            if isToolbarVisible {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // Power Menu (Gear)
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
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.gray)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        
                        // Secondary Menu (Three Dots)
                        Menu {
                            ForEach(ServerTab.allCases.filter { !$0.isPrimary }) { tab in
                                Button {
                                    selectedTab = tab
                                } label: {
                                    Label(tab.rawValue, systemImage: tab.icon)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.gray)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .toolbar(.hidden, for: .tabBar) // Hide main app dock
        // REMOVE .toolbar(.hidden, for: .tabBar) which was hiding the main dock?
        // Ah, the user previously had .toolbar(.hidden, for: .tabBar). I should check if that was for the APP'S main dock or the VIEW'S dock.
        // Usually ServerDetails is pushed on a stack.
        // If the app has a main tab bar, we might want to hide it.
        // But here we are using a TabView inside ServerDetails.
        // So we probably want to hide the *parent* tab bar (if any), but SHOW the current *internal* tab bar.
        // The default `TabView` shows its own bar.
        // So keeping `.toolbar(.hidden, for: .tabBar)` might hide the PARENT tab bar which is likely desired.
        // I will keep it but verifying its behavior on *this* TabView.
        // Actually, on iOS 18 `toolbar(.hidden, for: .tabBar)` hides the bar for the *current context*.
        // If I put it on `TabView`, it might hide its own bar?
        // No, it usually hides the parent's.
        // I'll keep it as it was there before.
        .onAppear {
            Task {
                await viewModel.connect(to: server)
            }
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
    
    // Custom header view removed in favor of standard navigation bar
}

// MARK: - Sub-Sections

struct ConsoleSection: View {
    let server: ServerAttributes
    @ObservedObject var viewModel: ServerDetailsViewModel
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Terminal
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Terminal")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
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
                .background(Color.black.opacity(0.4))
                
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(AnsiParser.parse(viewModel.consoleOutput))
                            .font(.custom("Menlo", size: 12))
                            .lineSpacing(4)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .id("bottom")
                    }
                    .frame(height: 400) // Increased height
                    .onChange(of: viewModel.consoleOutput) { _, _ in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onTapGesture {
                        isInputFocused = false
                    }
                }
                
                // Input
                HStack {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.5))
                    TextField("Enter command...", text: $viewModel.commandInput)
                        .focused($isInputFocused)
                        .onSubmit {
                            viewModel.sendCommand()
                            // Keep focus? Maybe not on mobile
                        }
                        .submitLabel(.send)
                        .foregroundStyle(.white)
                        .font(.custom("Menlo", size: 14))
                }
                .padding()
                .background(Color.white.opacity(0.05))
            }
            .background(Color.black.opacity(0.6)) // Darker background for contrast
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
    }
}



struct AnalyticsSection: View {
    let server: ServerAttributes
    @ObservedObject var viewModel: ServerDetailsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            if let stats = viewModel.currentStats {
                ServerResourceUsageView(stats: stats, limits: server.limits)
            } else {
                ProgressView()
                    .frame(height: 200)
            }
        }
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
                .foregroundStyle(.white.opacity(0.5))
            
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
            Text(description)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .liquidGlassEffect()
    }
}

// MARK: - ViewModel

// MARK: - ViewModel

class ServerDetailsViewModel: ObservableObject {
    @Published var consoleOutput: String = ""
    @Published var commandInput: String = ""
    @Published var currentStats: ServerStats?
    @Published var isConnected = false
    @Published var errorMessage: String?
    
    private var serverId: String?
    private var cancellables = Set<AnyCancellable>()
    
    func connect(to server: ServerAttributes) async {
        self.serverId = server.identifier
        
        await MainActor.run {
            self.consoleOutput = "Connecting to \(server.name)...\n"
            self.isConnected = false
            self.errorMessage = nil
        }
        
        do {
            // 1. Get Websocket Credentials
            let (socketUrl, token) = try await PterodactylClient.shared.fetchWebsocketDetails(serverId: server.identifier)
            
            // 2. Connect Websocket
            guard let url = URL(string: socketUrl) else {
                throw PterodactylError.serializationError
            }
            
            WebSocketClient.shared.connect(url: url, token: token)
            
            // 3. Subscribe to events
            setupSubscriptions()
            
            await MainActor.run {
                self.isConnected = true
            }
            
        } catch {
            await MainActor.run {
                self.consoleOutput += "Connection failed: \(error.localizedDescription)\n"
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func disconnect() {
        WebSocketClient.shared.disconnect()
        cancellables.removeAll()
        isConnected = false
    }
    
    private func setupSubscriptions() {
        WebSocketClient.shared.eventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .consoleOutput(let text):
                    self.consoleOutput += text + "\n"
                    // Cap console output to avoid memory issues (e.g. last 1000 lines)
                    if self.consoleOutput.count > 50000 {
                        self.consoleOutput = String(self.consoleOutput.suffix(50000))
                    }
                case .stats(let json):
                    self.parseStats(json)
                case .status(let status):
                    self.updateStatus(status)
                case .connected:
                    self.consoleOutput += "[System] Connected to server stream.\n"
                    self.isConnected = true
                case .disconnected:
                    self.consoleOutput += "[System] Disconnected.\n"
                    self.isConnected = false
                case .installOutput(let text):
                    self.consoleOutput += "[Install] \(text)\n"
                case .daemonError(let error):
                    self.consoleOutput += "[Error] \(error)\n"
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
    
    var body: some View {
        VStack(spacing: 20) {
            // 1. Active Alerts
            VStack(alignment: .leading, spacing: 12) {
                Text("Active Alerts")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if manager.activeAlerts.isEmpty {
                    HStack {
                         Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                         Text("No active alerts. System healthy.")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                } else {
                    ForEach(manager.activeAlerts, id: \.self) { alert in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(alert)
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
            }
            .liquidGlassEffect()
            
            // 2. Configuration (Embedded form style)
            VStack(alignment: .leading, spacing: 16) {
                Text("Configuration")
                    .font(.headline)
                    .foregroundStyle(.white)
                    
                Toggle(isOn: $manager.config.isEnabled) {
                    Label("Enable Alerts", systemImage: "bell.badge")
                        .foregroundStyle(.white)
                }
                .tint(.blue)
                
                if manager.config.isEnabled {
                    Divider().background(Color.white.opacity(0.2))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("CPU Limit")
                            Spacer()
                            Text("\(Int(manager.config.cpuThreshold))%")
                                .monospacedDigit()
                                .foregroundStyle(.blue)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        
                        Slider(value: $manager.config.cpuThreshold, in: 50...200, step: 10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                         HStack {
                            Text("Memory Limit")
                            Spacer()
                            Text("\(Int(manager.config.memoryThreshold))%")
                                .monospacedDigit()
                                .foregroundStyle(.blue)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        
                        Slider(value: $manager.config.memoryThreshold, in: 50...100, step: 5)
                    }
                    
                    Button("Save Configuration") {
                        manager.save()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .padding(.top, 8)
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(16)
            .liquidGlassEffect()
        }
    }
}
