import SwiftUI

enum ServerTab: String, CaseIterable, Identifiable {
    case console = "Console"
    case files = "Files"
    case network = "Network"
    case backups = "Backups"
    case startup = "Startup"
    case settings = "Settings"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .console: return "terminal.fill"
        case .files: return "folder.fill"
        case .network: return "network"
        case .backups: return "archivebox.fill"
        case .startup: return "play.laptopcomputer"
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
            LiquidBackgroundView()
            
            VStack(spacing: 0) {
                 // Header
                 GlassyNavBar(
                     title: server.name,
                     stats: consoleViewModel.stats,
                     statusState: consoleViewModel.state,
                     onBack: { dismiss() },
                     onPowerAction: { action in consoleViewModel.sendPowerAction(action) }
                 )
                 .padding()
                 .padding()
                 
                  TabView(selection: $selectedTab) {
                    ConsoleView(viewModel: consoleViewModel) // Pass view model!
                        .tag(ServerTab.console)
                    
                    FileManagerView(serverId: server.identifier)
                        .tag(ServerTab.files)
                    
                    NetworkView(serverId: server.identifier)
                        .tag(ServerTab.network)
                        
                    BackupView(serverId: server.identifier)
                        .tag(ServerTab.backups)
                        
                    StartupView(serverId: server.identifier)
                        .tag(ServerTab.startup)
                    
                    SettingsView()
                        .tag(ServerTab.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(nil, value: selectedTab) // Disable tab slide animation if that's the issue
                
                // Bottom Tab Bar ...
            }
        }
    }
    
    var statusColor: Color {
        switch consoleViewModel.state {
        case "running": return .green
        case "starting": return .yellow
        case "stopping": return .orange
        case "offline": return .red
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

// MARK: - Glassy Navbar optimized for "Liquid Glass" iOS 17+ style
struct GlassyNavBar: View {
    let title: String
    let stats: WebsocketResponse.Stats?
    let statusState: String
    let onBack: () -> Void
    let onPowerAction: (String) -> Void
    
    var statusColor: Color {
        switch statusState {
        case "running": return .green
        case "starting": return .yellow
        case "stopping": return .orange
        case "offline": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
             Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                HStack(spacing: 8) {
                    Label(stats?.memory_bytes.formattedMemory ?? "0 MB", systemImage: "memorychip")
                    Label(stats?.cpu_absolute.formattedCPU ?? "0%", systemImage: "cpu")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
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
            .padding(.vertical, 6)
            .background(.thickMaterial) // Thicker for better contrast
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x:0, y: 1)
            
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
                    .padding(10)
                    .background(
                        LinearGradient(colors: [.red.opacity(0.8), .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
                    .shadow(color: .red.opacity(0.3), radius: 5)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(14)
        .background(.regularMaterial) // Native material
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }
}
