import SwiftUI
import Darwin

struct ContentView: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var selectedTab = 0
    
    init() {
        // Configure UI appearances for iOS 26 native transparent bars
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
    
    private func triggerLocalNetworkPermission() {
        DispatchQueue.global(qos: .background).async {
            let socket = socket(AF_INET, SOCK_STREAM, 0)
            guard socket >= 0 else { return }
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = CFSwapInt16HostToBig(80)
            addr.sin_addr.s_addr = inet_addr("192.168.0.1")
            
            let addrPtr = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
            }
            
            _ = Darwin.connect(socket, addrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            close(socket)
        }
    }
}

#Preview {
    ContentView()
}
