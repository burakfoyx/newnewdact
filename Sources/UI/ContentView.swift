import SwiftUI

struct ContentView: View {
    @State private var showLogin = false
    @State private var isAuthenticated = false
    
    var body: some View {
        ZStack {
            if isAuthenticated {
                ServerListView()
            } else {
                LandingView(showLogin: $showLogin)
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            AuthenticationView(isPresented: $showLogin)
                .onDisappear {
                    // Check if we are authenticated after dismissing
                    // In a real app we might use a shared EnvironmentObject for Auth State
                    // For now, let's assume if we dismissed, we might be auth'd, or check Keychain
                    /* 
                       Logic Gap: AuthenticationView sets isPresented to false on success, 
                       but doesn't communicate success back to ContentView directly unless we use bindings or EnvObject.
                       Fix: Let's assume AuthenticationView saves to Keychain and we can check, 
                       OR let's refactor to use an @EnvironmentObject. 
                       For this quick iteration, I will check a shared state or callback.
                    */
                   checkAuth()
                }
        }
        .onChange(of: showLogin) { isShown in
            if !isShown {
                 // Re-check auth
                 checkAuth()
            }
        }
    }
    
    func checkAuth() {
        // Simple check
        if KeychainHelper.standard.read(account: "current_session") != nil {
            isAuthenticated = true
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
                            .symbolEffect(.bounce, options: .repeating)
                        
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
