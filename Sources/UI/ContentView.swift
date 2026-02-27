import SwiftUI
import Darwin

struct ContentView: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if accountManager.activeAccount != nil {
                authenticatedView
            } else {
                AuthenticationView(isPresented: .constant(true))
            }
        }
        .onAppear {
            configureAppearances()
        }
    }
    
    var authenticatedView: some View {
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
    
    private func configureAppearances() {
        // Make TabBar transparent (iOS 26 native)
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Make NavigationBar transparent (iOS 26 native)
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.backgroundColor = .clear
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }
}

#Preview {
    ContentView()
}
