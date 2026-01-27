import SwiftUI

struct ContentView: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var showLogin = false
    
    var body: some View {
        ZStack {
            if accountManager.activeAccount != nil {
                ServerListView()
                    .environmentObject(accountManager)
            } else {
                LandingView(showLogin: $showLogin)
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            AuthenticationView(isPresented: $showLogin)
        }
    }
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
