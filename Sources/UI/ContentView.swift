import SwiftUI

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
    }
    
    var authenticatedView: some View {
        ZStack {
            // Global Background
            LiquidBackgroundView()
            
            TabView(selection: $selectedTab) {
                NavigationStack {
                    PanelListView(selectedTab: $selectedTab)
                        .navigationTitle("API Keys")
                }
                .tabItem {
                    Label("API", systemImage: "key.fill")
                }
                .tag(0)
                
                NavigationStack {
                    ServerListView()
                        .navigationTitle("Servers")
                }
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }
                .tag(1)
                
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                }
                .tabItem {
                     Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
            }
            .tint(accountManager.activeAccount?.theme.mainColor ?? .blue)
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}



struct LandingView: View {
// ... existing landing view code ...
    @Binding var showLogin: Bool
    
    var body: some View {
        ZStack {
            // Animated ambient background
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Circles for refraction demo
            Circle()
                .fill(Color.cyan)
                .blur(radius: 60)
                .frame(width: 200, height: 200)
                .offset(x: -100, y: -150)
            
            Circle()
                .fill(Color.pink)
                .blur(radius: 60)
                .frame(width: 200, height: 200)
                .offset(x: 100, y: 100)
            
            VStack(spacing: 30) {
                // Header
                LiquidGlassCard {
                    VStack(spacing: 10) {
                        Image(systemName: "swift") // Placeholder icon
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
                
                // Action
                Button(action: {
                    showLogin = true
                }) {
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


