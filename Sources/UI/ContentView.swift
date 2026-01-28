import SwiftUI

struct ContentView: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var selectedTab = 0
    
    init() {
        // Configure ALL UI appearances at init time before any views render
        configureAppearances()
        
        // Trigger Local Network Permission immediately
        triggerLocalNetworkPermission()
    }
    
    var body: some View {
        Group {
            if accountManager.activeAccount != nil {
                authenticatedView
            } else {
                AuthenticationView(isPresented: .constant(true))
            }
        }
    }
    
    var authenticatedView: some View {
        ZStack {
            // Global Background - MUST be first layer
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            // Tab content overlaid on background
            TabView(selection: $selectedTab) {
                // Tab 0: Panels
                PanelListView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Panels", systemImage: "rectangle.stack.fill")
                    }
                    .tag(0)
                
                // Tab 1: API
                ApiKeysView()
                    .tabItem {
                        Label("API", systemImage: "key.fill")
                    }
                    .tag(1)
                
                // Tab 2: Servers
                ServerListView()
                    .tabItem {
                        Label("Servers", systemImage: "server.rack")
                    }
                    .tag(2)
                
                // Tab 3: Settings
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(3)
            }
            .tint(.blue)
        }
    }
    
    private func configureAppearances() {
        // Make TabBar transparent
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Make NavigationBar transparent
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.backgroundColor = .clear
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        // Make TableView/List backgrounds clear
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        
        // Make CollectionView backgrounds clear
        UICollectionView.appearance().backgroundColor = .clear
    }
    
    private func triggerLocalNetworkPermission() {
        // Fire-and-forget network request to trigger permission dialog
        let url = URL(string: "http://192.168.0.1")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5
        URLSession.shared.dataTask(with: request).resume()
    }
}

struct LandingView: View {
    @Binding var showLogin: Bool
    
    var body: some View {
        ZStack {
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                LiquidGlassCard {
                    VStack(spacing: 10) {
                        Image(systemName: "swift")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse)
                        
                        Text("XYIdactyl")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("The Future of Panel Management")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: { showLogin = true }) {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Connect with Face ID")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(LiquidButtonStyle())
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 50)
        }
    }
}

#Preview {
    ContentView()
}
