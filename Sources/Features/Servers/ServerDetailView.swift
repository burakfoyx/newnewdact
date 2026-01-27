import SwiftUI

struct ServerDetailView: View {
    let server: ServerAttributes
    @State private var selectedTab: ServerTab = .console
    @Environment(\.dismiss) var dismiss
    
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
    
    var body: some View {
        ZStack {
            LiquidBackgroundView()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
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
                        Text(server.node)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Power Menu
                    Menu {
                        Button(action: { Task { try? await PterodactylClient.shared.sendPowerSignal(serverId: server.identifier, signal: "start") } }) {
                            Label("Start", systemImage: "play.fill")
                        }
                        Button(action: { Task { try? await PterodactylClient.shared.sendPowerSignal(serverId: server.identifier, signal: "restart") } }) {
                            Label("Restart", systemImage: "arrow.clockwise")
                        }
                        Button(action: { Task { try? await PterodactylClient.shared.sendPowerSignal(serverId: server.identifier, signal: "stop") } }) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        Button(role: .destructive, action: { Task { try? await PterodactylClient.shared.sendPowerSignal(serverId: server.identifier, signal: "kill") } }) {
                            Label("Kill", systemImage: "flame.fill")
                        }
                    } label: {
                        Image(systemName: "power.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .shadow(color: .blue.opacity(0.5), radius: 5)
                    }
                    .padding(.trailing, 8)
                    
                    // Status Badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .shadow(color: .green, radius: 4)
                        Text("Online")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .capsule()
                }
                .padding()
                
                // Content Area
                TabView(selection: $selectedTab) {
                    ConsoleView(serverId: server.identifier)
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
                
                // Custom Tab Bar
                HStack(spacing: 0) {
                    ForEach(ServerTab.allCases) { tab in
                        Button(action: { 
                            withAnimation(.spring(response: 0.3)) {
                                selectedTab = tab 
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 20))
                                    .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                                
                                Text(tab.rawValue)
                                    .font(.caption2)
                            }
                            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selectedTab == tab ? Color.white.opacity(0.1) : Color.clear
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                .background(.ultraThinMaterial)
            }
        }
        .navigationBarHidden(true)
    }
    
    // Helper view extensions for styling
}

extension View {
    func capsule() -> some View {
        clipShape(Capsule())
    }
}
