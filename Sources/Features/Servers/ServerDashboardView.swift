import SwiftUI

struct ServerDashboardView: View {
    let server: ServerAttributes
    @StateObject private var consoleViewModel: ConsoleViewModel
    @State private var selectedTab: ServerTab = .console
    @Environment(\.dismiss) var dismiss
    
    // FAB State
    @State private var showFab: Bool = false
    @Namespace private var tabNamespace
    
    init(server: ServerAttributes) {
        self.server = server
        _consoleViewModel = StateObject(wrappedValue: ConsoleViewModel(serverId: server.identifier, limits: server.limits))
    }
    
    var body: some View {
        ZStack {
            // MARK: 1. Background Layer
            LiquidBackgroundView()
                .ignoresSafeArea()
                .compositingGroup() // Prevents "Double Vision" artifacts
            
            // MARK: 2. Content Layer
            TabView(selection: $selectedTab) {
                // --- Console ---
                ConsoleView(
                    viewModel: consoleViewModel,
                    limits: server.limits,
                    serverName: server.name
                )
                .background(Color.clear)
                .tag(ServerTab.console)
                
                // --- Analytics ---
                HistoryView(
                    server: server,
                    serverName: server.name,
                    statusState: consoleViewModel.state,
                    stats: consoleViewModel.stats,
                    limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.analytics)
                
                // --- Files ---
                FileManagerView(
                    server: server,
                    serverName: server.name,
                    statusState: consoleViewModel.state,
                    stats: consoleViewModel.stats,
                    limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.files)
                
                // --- Network ---
                NetworkView(
                    server: server,
                    serverName: server.name,
                    statusState: consoleViewModel.state,
                    stats: consoleViewModel.stats,
                    limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.network)
                
                // --- Backups ---
                BackupView(
                    server: server,
                    serverName: server.name,
                    statusState: consoleViewModel.state,
                    stats: consoleViewModel.stats,
                    limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.backups)
                
                // --- Other Tabs (Startup, Schedules, Databases, Users, Settings, Alerts) ---
                // For brevity in first pass, adding main ones. Can add all if needed.
                // STARTUP
                StartupView(server: server, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits)
                    .background(Color.clear).tag(ServerTab.startup)
                
                // SCHEDULES
                SchedulesView(serverId: server.identifier, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits)
                    .background(Color.clear).tag(ServerTab.schedules)
                
                // DATABASES
                DatabasesView(serverId: server.identifier, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits)
                    .background(Color.clear).tag(ServerTab.databases)
                
                // USERS
                UsersView(serverId: server.identifier, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits)
                    .background(Color.clear).tag(ServerTab.users)
                
                // SETTINGS
                ServerSettingsView(server: server, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits)
                    .background(Color.clear).tag(ServerTab.settings)
                
                // ALERTS
                AlertsListView(server: server, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits)
                    .background(Color.clear).tag(ServerTab.alerts)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
            // Insets to prevent content being hidden behind bars
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 50) } // Header Space
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) } // Tab Bar Space
            
            // MARK: 3. HUD Layer (Floating Interface)
            VStack(spacing: 0) {
                // --- TOP: Minimal Header ---
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(server.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        // Small Status Indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 6, height: 6)
                            Text(consoleViewModel.state.capitalized)
                                .font(.caption2.bold())
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    // Optional Power Button in Top Right?
                    Menu {
                        Button(action: { consoleViewModel.sendPowerAction("start") }) { Label("Start", systemImage: "play.fill") }
                        Button(action: { consoleViewModel.sendPowerAction("restart") }) { Label("Restart", systemImage: "arrow.clockwise") }
                        Button(action: { consoleViewModel.sendPowerAction("stop") }) { Label("Stop", systemImage: "stop.fill") }
                        Button(role: .destructive, action: { consoleViewModel.sendPowerAction("kill") }) { Label("Kill", systemImage: "flame.fill") }
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(statusColor.opacity(0.2)) // Glow based on status
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(statusColor.opacity(0.5), lineWidth: 1))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5) // Minimal padding
                .padding(.bottom, 10)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.0) // Minimal or invisible? User said "Small text". Let's keep it clean.
                        // Ideally gradient fade?
                        .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                )
                
                Spacer()
                
                // --- BOTTOM: Custom Scrollable Tab Bar ---
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(ServerTab.allCases) { tab in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 20))
                                    Text(tab.rawValue)
                                        .font(.caption2)
                                        .fixedSize()
                                }
                                .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.5))
                                .frame(minWidth: 50)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(
                                    ZStack {
                                        if selectedTab == tab {
                                            Capsule()
                                                .fill(Color.white.opacity(0.2))
                                                .matchedGeometryEffect(id: "TabHighlight", in: tabNamespace)
                                        }
                                    }
                                )
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle()) // Smooth touch
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .backgroundWidthReader(minHeight: 70) // Ensure height
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                .padding(.horizontal)
                .padding(.bottom, 5) // Push up slightly from home indicator
            }
            .ignoresSafeArea(.container, edges: .top) // Header goes up
            
            // MARK: 4. Floating Action Button (FAB)
            // Show only on specific tabs
            if shouldShowFab {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: handleFabAction) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue) // Theme Color?
                                .clipShape(Circle())
                                .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // Above tab bar
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
             // Logic to hide system bars if needed
        }
    }
    
    // MARK: - Helpers
    

    
    private var statusColor: Color {
        switch consoleViewModel.state {
        case "running": return .green
        case "starting": return .yellow
        case "stopping": return .orange
        case "offline": return .red
        default: return .gray
        }
    }
    
    private var shouldShowFab: Bool {
        // FAB visible on these tabs
        switch selectedTab {
        case .backups, .databases, .schedules, .users: return true
        default: return false
        }
    }
    
    private func handleFabAction() {
        // Handle Action
        print("FAB Action for \(selectedTab.rawValue)")
    }
}

// Helper to read height if needed
extension View {
    func backgroundWidthReader(minHeight: CGFloat = 0) -> some View {
        self.frame(minHeight: minHeight)
    }
}
