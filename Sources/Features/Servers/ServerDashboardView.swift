import SwiftUI

struct ServerDashboardView: View {
    let server: ServerAttributes
    @StateObject private var consoleViewModel: ConsoleViewModel
    @State private var selectedTab: ServerTab = .console
    @Environment(\.dismiss) var dismiss
    
    init(server: ServerAttributes) {
        self.server = server
        _consoleViewModel = StateObject(wrappedValue: ConsoleViewModel(serverId: server.identifier, limits: server.limits))
    }
    
    var body: some View {
        ZStack {
            // MARK: 1. Global Background
            // Single source of truth for background. All child views must be transparent.
            LiquidBackgroundView()
                .ignoresSafeArea()
                .compositingGroup()
            
            // MARK: 2. Content
            TabView(selection: $selectedTab) {
                // Wrap tabs to ensure they don't have their own backgrounds
                // CONSOLE
                ConsoleView(
                    viewModel: consoleViewModel,
                    limits: server.limits,
                    serverName: server.name
                )
                .background(Color.clear)
                .tag(ServerTab.console)
                
                // ANALYTICS
                HistoryView(
                    server: server,
                    serverName: server.name,
                    statusState: consoleViewModel.state,
                    stats: consoleViewModel.stats,
                    limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.analytics)
                
                // FILES
                FileManagerView(
                    server: server,
                    serverName: server.name,
                    statusState: consoleViewModel.state,
                    stats: consoleViewModel.stats,
                    limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.files)
                
                // NETWORK
                NetworkView(
                    server: server,
                    serverName: server.name,
                    statusState: consoleViewModel.state,
                    stats: consoleViewModel.stats,
                    limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.network)
                
                // BACKUPS
                BackupView(
                    server: server,
                    serverName: server.name,
                    statusState: consoleViewModel.state,
                    stats: consoleViewModel.stats,
                    limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.backups)
                
                // STARTUP
                StartupView(
                    server: server, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.startup)
                
                // SCHEDULES
                SchedulesView(
                    serverId: server.identifier, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.schedules)
                
                // DATABASES
                DatabasesView(
                    serverId: server.identifier, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.databases)
                
                // USERS
                UsersView(
                    serverId: server.identifier, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.users)
                
                // SETTINGS
                ServerSettingsView(
                    server: server, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.settings)
                
                // ALERTS
                AlertsListView(
                    server: server, serverName: server.name, statusState: consoleViewModel.state, stats: consoleViewModel.stats, limits: server.limits
                )
                .background(Color.clear)
                .tag(ServerTab.alerts)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            // Ensure content isn't hidden by our custom bottom bar
            // We reserve 60pt for the bar base + safe area
            .safeAreaInset(edge: .bottom) {
                 Color.clear.frame(height: 50)
            }

            // MARK: 3. Custom Bottom Tab Bar
            VStack(spacing: 0) {
                Spacer()
                
                // Divider line for native feel
                Divider()
                    .background(Color.white.opacity(0.1))
                
                ScrollableTabBar(selectedTab: $selectedTab)
                    .background(.ultraThinMaterial) // Native-like blur
            }
            .ignoresSafeArea(.item, edges: .bottom) // Let background extend to bottom edge
        }
        // MARK: 4. Native Top Navigation
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar) // Transparent Nav Bar
        .toolbar {
            // Power / Settings Menu (Top Right)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Power Section
                    Section {
                        Button { consoleViewModel.sendPowerAction("start") } label: { Label("Start", systemImage: "play.fill") }
                        Button { consoleViewModel.sendPowerAction("restart") } label: { Label("Restart", systemImage: "arrow.clockwise") }
                        Button { consoleViewModel.sendPowerAction("stop") } label: { Label("Stop", systemImage: "stop.fill") }
                        Button(role: .destructive) { consoleViewModel.sendPowerAction("kill") } label: { Label("Kill", systemImage: "flame.fill") }
                    } header: {
                        Text("Power Controls")
                    }
                    
                    // Actions (Contextual "Create" logic based on tab?) 
                    // Or keep it simple.
                    
                    // Settings Link
                    Section {
                        // Switch to Settings Tab
                        Button { selectedTab = .settings } label: { Label("Attributes", systemImage: "slider.horizontal.3") }
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            
            // Contextual "Plus" Button (If applicable)
            if shouldShowCreateButton {
                ToolbarItem(placement: .topBarTrailing) {
                     Button(action: handleCreateAction) {
                         Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                     }
                }
            }
        }
    }
    
    // Logic for "Plus" button visibility
    private var shouldShowCreateButton: Bool {
        switch selectedTab {
        case .backups, .databases, .schedules, .users: return true
        default: return false
        }
    }
    
    private func handleCreateAction() {
        // Here we would trigger the 'Create' sheet for the specific view.
        // For now, we print. Ideally, child views should observe a 'createTrigger' or we bind state.
        // Or simpler: The child views manage their own creation sheets via an environment object, 
        // OR we put the button IN the child view's toolbar (if we weren't hiding the tab bar).
        // Since we are using a custom TabView, child views CAN have toolbar items! 
        // But native toolbar items in SwiftUI TabView sometimes behave oddly if the parent intercepts.
        // Let's verify if standard .toolbar in child views works with parent NavigationStack.
        // If yes, we remove this global logic and let child views handle it.
        // For now, keeping it here for safety.
        print("Create Action for \(selectedTab)")
    }
}

// MARK: - Subcomponents

struct ScrollableTabBar: View {
    @Binding var selectedTab: ServerTab
    @Namespace private var ns
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 25) {
                ForEach(ServerTab.allCases) { tab in
                    Button {
                        withAnimation(.snappy) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            // Icon
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                                .symbolVariant(selectedTab == tab ? .fill : .none)
                            
                            // Text
                            Text(tab.rawValue)
                                .font(.caption2)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                        }
                        .foregroundStyle(selectedTab == tab ? .blue : .secondary) // Highlight Color
                        .frame(minWidth: 50)
                        .padding(.vertical, 10)
                        .overlay(alignment: .top) {
                            if selectedTab == tab {
                                // Optional Top Indicator line
                                Capsule()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 3)
                                    .offset(y: -10)
                                    .matchedGeometryEffect(id: "Indicator", in: ns)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 50) // Standard Tab Bar Height area (excluding safe area)
        .padding(.bottom, 5) // Slight adjustment
    }
}
