import SwiftUI

struct ServerDetailView: View {
    let server: ServerAttributes
    @StateObject private var consoleViewModel: ConsoleViewModel // Owned here to share state
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
                 HStack {
                     // Back Button ...
                     Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                     VStack(alignment: .leading) {
                         Text(server.name)
                             .font(.headline)
                             .foregroundStyle(.white)
                         // Real-time Resources
                         HStack(spacing: 8) {
                             Label(consoleViewModel.stats?.memory_bytes.formattedMemory ?? "0 MB", systemImage: "memorychip")
                             Label(consoleViewModel.stats?.cpu_absolute.formattedCPU ?? "0%", systemImage: "cpu")
                         }
                         .font(.caption2)
                         .foregroundStyle(.white.opacity(0.7))
                     }
                     
                     Spacer()
                     
                     // Power Menu ...
                     Menu {
                        Button(action: { consoleViewModel.sendPowerAction("start") }) {
                            Label("Start", systemImage: "play.fill")
                        }
                        Button(action: { consoleViewModel.sendPowerAction("restart") }) {
                            Label("Restart", systemImage: "arrow.clockwise")
                        }
                        Button(action: { consoleViewModel.sendPowerAction("stop") }) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        Button(role: .destructive, action: { consoleViewModel.sendPowerAction("kill") }) {
                            Label("Kill", systemImage: "flame.fill")
                        }
                    } label: {
                        Image(systemName: "power.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .shadow(color: .blue.opacity(0.5), radius: 5)
                    }
                     
                     // Real Status Badge
                     HStack(spacing: 6) {
                         Circle()
                             .fill(statusColor)
                             .frame(width: 8, height: 8)
                             .shadow(color: statusColor, radius: 4)
                         Text(consoleViewModel.state.capitalized)
                             .font(.caption2.bold())
                             .foregroundStyle(.white)
                     }
                     .padding(.horizontal, 10)
                     .padding(.vertical, 6)
                     .background(.ultraThinMaterial)
                     .capsule()
                 }
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
