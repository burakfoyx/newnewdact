import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(colors: [.black, .blue.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        // Title
                        VStack(spacing: 8) {
                            Text("Connect Panel")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Enter your Pterodactyl credentials")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 60)
                        
                        // Form
                        LiquidGlassCard {
                            VStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("Panel URL")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("https://panel.example.com", text: $viewModel.hostURL)
                                        .textContentType(.URL)
                                        .keyboardType(.URL)
                                        .textInputAutocapitalization(.never)
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(12)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("API Key")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    SecureField("ptlc_...", text: $viewModel.apiKey)
                                        .textContentType(.password) // Enables keychain autofill/save prompt
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(12)
                                }
                                
                                if let error = viewModel.errorMessage {
                                    Text(error)
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                }
                                
                                Button(action: {
                                    Task { await viewModel.login() }
                                }) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Authenticate")
                                            .fontWeight(.bold)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(LiquidButtonStyle())
                                .disabled(viewModel.isLoading)
                                .padding(.top, 10)
                            }
                            .padding()
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .onChange(of: viewModel.isAuthenticated) { _, authenticated in
                 if authenticated {
                     isPresented = false
                 }
            }
        }
    }
}
