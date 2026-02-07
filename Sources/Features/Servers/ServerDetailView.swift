import SwiftUI

enum ServerTab: String, CaseIterable, Identifiable {
    case console = "Console"
    case analytics = "Analytics"
    case alerts = "Alerts"
    case files = "Files"
    case network = "Network"
    case backups = "Backups"
    case startup = "Startup"
    case schedules = "Schedules"
    case databases = "Databases"
    case users = "Users"
    case settings = "Settings"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .console: return "terminal.fill"
        case .analytics: return "chart.xyaxis.line"
        case .alerts: return "bell.fill"
        case .files: return "folder.fill"
        case .network: return "network"
        case .backups: return "archivebox.fill"
        case .startup: return "play.laptopcomputer"
        case .schedules: return "clock.fill"
        case .databases: return "cylinder.split.1x2.fill"
        case .users: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ServerDetailView: View {
    let server: ServerAttributes
    @StateObject private var consoleViewModel: ConsoleViewModel
    @State private var selectedTab: ServerTab = .console
    @Environment(\.dismiss) var dismiss
    
    init(server: ServerAttributes) {
        self.server = server
        _consoleViewModel = StateObject(wrappedValue: ConsoleViewModel(serverId: server.identifier, limits: server.limits))
    }
    
    // ... Tab Enum ...
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background layer
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                // Content layer - TabView with top padding for header
                TabView(selection: $selectedTab) {
                    ConsoleView(
                        viewModel: consoleViewModel,
                        limits: server.limits,
                        serverName: server.name
                    )
                    .background(Color.clear)
                    .tag(ServerTab.console)
                    
                    HistoryView(
                        server: server,
                        serverName: server.name,
                        statusState: consoleViewModel.state,
                        stats: consoleViewModel.stats,
                        limits: server.limits
                    )
                    .background(Color.clear)
                    .tag(ServerTab.analytics)
                    
                    AlertsListView(
                        server: server,
                        serverName: server.name,
                        statusState: consoleViewModel.state,
                        stats: consoleViewModel.stats,
                        limits: server.limits
                    )
                    .background(Color.clear)
                    .tag(ServerTab.alerts)
                    
                    FileManagerView(
                        server: server,
                        serverName: server.name,
                        statusState: consoleViewModel.state,
                        stats: consoleViewModel.stats,
                        limits: server.limits
                    )
                    .background(Color.clear)
                    .tag(ServerTab.files)
                        
                    NetworkView(
                        server: server,
                        serverName: server.name,
                        statusState: consoleViewModel.state,
                        stats: consoleViewModel.stats,
                        limits: server.limits
                    )
                    .background(Color.clear)
                    .tag(ServerTab.network)
                        
                    BackupView(
                        server: server,
                        serverName: server.name,
                        statusState: consoleViewModel.state,
                        stats: consoleViewModel.stats,
                        limits: server.limits
                    )
                    .background(Color.clear)
                    .tag(ServerTab.backups)
                        
                    StartupView(
                        server: server,
                        serverName: server.name,
                        statusState: consoleViewModel.state,
                        stats: consoleViewModel.stats,
                        limits: server.limits
                    )
                    .background(Color.clear)
                    .tag(ServerTab.startup)
                        
                    SchedulesView(
                        serverId: server.identifier,
                        serverName: server.name,
                        statusState: consoleViewModel.state,
                        stats: consoleViewModel.stats,
                        limits: server.limits
                    )
                    .background(Color.clear)
                    .tag(ServerTab.schedules)
                        
                    DatabasesView(
                        serverId: server.identifier,
                        serverName: server.name,
                        statusState: consoleViewModel.state,
                        stats: consoleViewModel.stats,
                        limits: server.limits
                    )
                    .background(Color.clear)
                    .tag(ServerTab.databases)
                        
                    UsersView(
                        serverId: server.identifier,
                        serverName: server.name,
                        statusState: consoleViewModel.state,
                        stats: consoleViewModel.stats,
                        limits: server.limits
                    )
                    .background(Color.clear)
                    .tag(ServerTab.users)
                    
                    ServerSettingsView(
                        server: server,
                        serverName: server.name,
                        statusState: consoleViewModel.state,
                        stats: consoleViewModel.stats,
                        limits: server.limits
                    )
                    .background(Color.clear)
                    .tag(ServerTab.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .animation(nil, value: selectedTab)
                // Push content below header and above bottom safe area
                .contentMargins(.top, 200, for: .scrollContent)
                .contentMargins(.bottom, 100, for: .scrollContent)
                
                // Header layer - overlaid on top, using frame instead of Spacer
                ServerDetailHeader(
                    title: server.name,
                    statusState: consoleViewModel.state,
                    selectedTab: $selectedTab,
                    onBack: { dismiss() },
                    onPowerAction: { action in consoleViewModel.sendPowerAction(action) },
                    stats: consoleViewModel.stats,
                    limits: server.limits
                )
                .padding(.horizontal)
                .padding(.top, geometry.safeAreaInsets.top + 20)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea(.container, edges: .all)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
    
    // Kept helper for statusColor if needed by other logic, but used less now.
    var statusColor: Color {
        switch consoleViewModel.state {
        case "running": return .green
        case "starting": return .yellow
        case "restarting": return .yellow
        case "stopping": return .orange
        case "offline": return .gray
        case "installing": return .blue
        case "suspended": return .orange
        default: return .gray
        }
    }
}

extension Int64 {
    var formattedMemory: String {
        let mb = Double(self) / 1024 / 1024
        return String(format: "%.0f MB", mb)
    }
}

extension Double {
    var formattedCPU: String {
        return String(format: "%.1f%%", self)
    }
}


extension View {
    func capsule() -> some View {
        clipShape(Capsule())
    }
}

// End of file
