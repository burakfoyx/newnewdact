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
    
    @Namespace private var animation

    // Main tabs to show directly
    private let mainTabs: [ServerTab] = [.console, .analytics, .backups, .alerts]
    
    // Tabs to show in "More" menu
    private let moreTabs: [ServerTab] = [
        .files, .network, .startup, .schedules,
        .databases, .users, .settings
    ]
    
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
            .animation(nil, value: selectedTab) // Ensure no implicit tab animation

            // MARK: 3. Dock Overlay
            VStack {
                Spacer()
                
                LiquidGlassDock {
                    // Main Tabs
                    ForEach(mainTabs) { tab in
                        LiquidDockButton(
                            title: tab.rawValue,
                            icon: tab.icon,
                            isSelected: selectedTab == tab,
                            namespace: animation
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }
                    }
                    
                    // "More" Tab Menu
                    Menu {
                        ForEach(moreTabs) { tab in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                }
                            } label: {
                                Label(tab.rawValue, systemImage: tab.icon)
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: isMoreTabSelected ? selectedTab.icon : "ellipsis.circle")
                                .font(.system(size: 20, weight: isMoreTabSelected ? .semibold : .regular))
                                .symbolEffect(.bounce, value: isMoreTabSelected)
                            
                            Text(isMoreTabSelected ? selectedTab.rawValue : "More")
                                .font(.system(size: 10, weight: isMoreTabSelected ? .semibold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .foregroundStyle(isMoreTabSelected ? Color.blue : .white)
                        .background {
                            if isMoreTabSelected {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .matchedGeometryEffect(id: "TabBackground", in: animation)
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        // MARK: 4. Native Top Navigation
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar) // Fix: Hide system tab bar
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
                    
                    // Settings Link
                    Section {
                        // Switch to Settings Tab
                        Button { selectedTab = .settings } label: { Label("Attributes", systemImage: "slider.horizontal.3") }
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold)) // Standard Icon Size
                        .foregroundStyle(.white)
                }
            }
            
            // Contextual "Plus" Button (If applicable)
            if shouldShowCreateButton {
                ToolbarItem(placement: .topBarTrailing) {
                     Button(action: handleCreateAction) {
                         Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                     }
                }
            }
        }
    }
    
    private var isMoreTabSelected: Bool {
        moreTabs.contains(selectedTab)
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

// End of file
