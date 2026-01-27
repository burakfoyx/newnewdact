import SwiftUI

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
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case 0:
                    NavigationStack {
                        PanelListView(selectedTab: $selectedTab)
                            .navigationTitle("Panels")
                            .toolbar(.hidden, for: .navigationBar) // Hide native navbar to use GlassyNavBar if needed, or keeping native for now but adjusting top padding
                    }
                case 1:
                    NavigationStack {
                        ServerListView()
                            .navigationTitle("Servers")
                            // We can use a custom NavBar here too for consistency if requested
                    }
                case 2:
                    NavigationStack {
                        SettingsView()
                            .navigationTitle("Settings")
                    }
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Floating Tab Bar
            GlassyTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 20) // Floating above safe area
        }
        .edgesIgnoringSafeArea(.bottom) // Allow content to go behind tab bar
        .tint(accountManager.activeAccount?.theme.mainColor ?? .blue)
    }
}

struct GlassyTabBar: View {
    @Binding var selectedTab: Int
    
    let tabs = [
        (0, "Panels", "square.grid.2x2.fill"),
        (1, "Servers", "server.rack"),
        (2, "Settings", "gearshape.fill")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { index, title, icon in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: selectedTab == index ? .semibold : .regular))
                            .symbolEffect(.bounce, value: selectedTab == index)
                        
                        Text(title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
            }
        }
        .background(.ultraThinMaterial)
        .background(
            // "Global" fade effect: Ambient glow behind the bar
            LinearGradient(colors: [.black.opacity(0.2), .clear], startPoint: .bottom, endPoint: .top)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .overlay(
            Capsule()
                .stroke(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
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


struct LandingView: View {
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
