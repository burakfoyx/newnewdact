import SwiftUI

enum ServerTab: String, CaseIterable, Identifiable {
    case console = "Console"
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
        _consoleViewModel = StateObject(wrappedValue: ConsoleViewModel(serverId: server.identifier))
    }
    
    // ... Tab Enum ...
    
    var body: some View {
        ZStack {
            // Background
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                 // Header
                 GlassyNavBar(
                     title: server.name,
                     statusState: consoleViewModel.state,
                     selectedTab: $selectedTab,
                     onBack: { dismiss() },
                     onPowerAction: { action in consoleViewModel.sendPowerAction(action) }
                 )
                 .padding(.horizontal)
                 .padding(.top)
                 
                  TabView(selection: $selectedTab) {
                    ConsoleView(viewModel: consoleViewModel, limits: server.limits)
                        .tag(ServerTab.console)
                    
                    FileManagerView(serverId: server.identifier)
                        .tag(ServerTab.files)
                    
                    NetworkView(serverId: server.identifier)
                        .tag(ServerTab.network)
                        
                    BackupView(serverId: server.identifier)
                        .tag(ServerTab.backups)
                        
                    StartupView(serverId: server.identifier)
                        .tag(ServerTab.startup)
                        
                    SchedulesView(serverId: server.identifier)
                        .tag(ServerTab.schedules)
                        
                    DatabasesView(serverId: server.identifier)
                        .tag(ServerTab.databases)
                        
                    UsersView(serverId: server.identifier)
                        .tag(ServerTab.users)
                    
                    ServerSettingsView(server: server)
                        .tag(ServerTab.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(nil, value: selectedTab)
                
                // Bottom Tab Bar ...
            }
        }
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        // Removed ignoresSafeArea(.keyboard) to allow content to adjust for keyboard
    }
    
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

struct GlassyNavBar: View {
    let title: String
    let statusState: String
    @Binding var selectedTab: ServerTab
    let onBack: () -> Void
    let onPowerAction: (String) -> Void
    
    var statusColor: Color {
        switch statusState {
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
    
    var body: some View {
        VStack(spacing: 12) {
            // First Row: Title & Actions
            HStack(spacing: 12) {
                 Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .glassEffect(in: Circle())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                
                Spacer()
                
                // Status Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: statusColor.opacity(0.8), radius: 4)
                    Text(statusState.capitalized)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .glassEffect(.thick, in: Capsule())
                
                // Power Action
                Menu {
                    Button(action: { onPowerAction("start") }) { Label("Start", systemImage: "play.fill") }
                    Button(action: { onPowerAction("restart") }) { Label("Restart", systemImage: "arrow.clockwise") }
                    Button(action: { onPowerAction("stop") }) { Label("Stop", systemImage: "stop.fill") }
                    Button(role: .destructive, action: { onPowerAction("kill") }) { Label("Kill", systemImage: "flame.fill") }
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .glassEffect(
                            .regular.tint(Color.red),
                            in: Circle()
                        )
                }
            }
            
            // Second Row: Morphing Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ServerTab.allCases) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                Text(tab.rawValue)
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                selectedTab == tab ? Color.white.opacity(0.2) : Color.clear
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedTab == tab ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                         .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct GlassMetricsCard: View {
    let stats: WebsocketResponse.Stats?
    let limits: ServerLimits
    
    var body: some View {
        HStack(spacing: 16) {
             // CPU Ring
             GlassProgressRing(
                value: stats?.cpu_absolute ?? 0,
                total: Double(limits.cpu ?? 100), 
                label: "CPU",
                color: .blue
             )
             
             Spacer()
             
             // Memory Ring
             GlassProgressRing(
                value: Double(stats?.memory_bytes ?? 0) / 1024 / 1024,
                total: Double(limits.memory ?? 1024),
                label: "RAM",
                color: .purple
             )
             
             Spacer()
             
             // Disk Ring
             GlassProgressRing(
                value: Double(stats?.disk_bytes ?? 0) / 1024 / 1024,
                total: Double(limits.disk ?? 1024),
                label: "DISK",
                color: .cyan
             )
        }
        .padding(20)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct GlassProgressRing: View {
    let value: Double
    let total: Double
    let label: String
    let color: Color // Base color, but we'll override for status
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }
    
    var ringColor: Color {
        let p = progress
        if p >= 0.8 { return .red }
        if p >= 0.5 { return .orange }
        return .blue // Default/Base
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                   .stroke(.white.opacity(0.1), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [ringColor.opacity(0.6), ringColor], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor.opacity(0.5), radius: 6)
                
                // Percentage
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
