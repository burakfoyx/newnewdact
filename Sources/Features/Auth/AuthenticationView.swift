import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @Binding var isPresented: Bool
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - tap to dismiss keyboard
                LiquidBackgroundView()
                    .ignoresSafeArea()
                    .onTapGesture {
                        isFieldFocused = false
                    }
                
                if viewModel.keyCheckState != .idle && viewModel.keyCheckState != .failed("") {
                    // Permission Check Animation Overlay
                    PermissionCheckOverlay(state: viewModel.keyCheckState)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    // Form
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
                                        Text("Account Name")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("e.g. Hostinger", text: $viewModel.name)
                                            .textContentType(.name)
                                            .focused($isFieldFocused)
                                            .padding()
                                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                                    }

                                    VStack(alignment: .leading) {
                                        Text("Panel URL")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("https://panel.example.com", text: $viewModel.hostURL)
                                            .textContentType(.URL)
                                            .keyboardType(.URL)
                                            .textInputAutocapitalization(.never)
                                            .focused($isFieldFocused)
                                            .padding()
                                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text("API Key")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        SecureField("ptlc_...", text: $viewModel.apiKey)
                                            .textContentType(.password)
                                            .focused($isFieldFocused)
                                            .padding()
                                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                                    }
                                    
                                    if let error = viewModel.errorMessage {
                                        Text(error)
                                            .foregroundStyle(.red)
                                            .font(.caption)
                                    }
                                    
                                    Button(action: {
                                        isFieldFocused = false // Dismiss keyboard
                                        Task { await viewModel.login() }
                                    }) {
                                        if viewModel.isLoading {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Text("Authenticate")
                                                .fontWeight(.bold)
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
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .animation(.spring(response: 0.5), value: viewModel.keyCheckState)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isFieldFocused = false
                        }
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

// MARK: - Permission Check Overlay

struct PermissionCheckOverlay: View {
    let state: KeyCheckState
    
    var body: some View {
        VStack(spacing: 30) {
            // Animated Icon
            ZStack {
                // Outer ring
                Circle()
                    .stroke(lineWidth: 3)
                    .foregroundStyle(.white.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                // Animated ring
                Circle()
                    .trim(from: 0, to: trimValue)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(ringColor)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: trimValue)
                
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(iconColor)
                    .scaleEffect(state == .adminDetected || state == .userDetected ? 1.2 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: state)
            }
            .glassEffect(.clear, in: Circle())
            .frame(width: 140, height: 140)
            
            // Status Text
            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                
                Text(statusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
        }
        .padding(40)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
    
    private var trimValue: CGFloat {
        switch state {
        case .connecting: return 0.25
        case .checkingPermissions: return 0.6
        case .adminDetected, .userDetected: return 1.0
        default: return 0
        }
    }
    
    private var ringColor: Color {
        switch state {
        case .adminDetected: return .purple
        case .userDetected: return .green
        default: return .blue
        }
    }
    
    private var iconName: String {
        switch state {
        case .connecting: return "network"
        case .checkingPermissions: return "key.fill"
        case .adminDetected: return "crown.fill"
        case .userDetected: return "person.fill.checkmark"
        default: return "network"
        }
    }
    
    private var iconColor: Color {
        switch state {
        case .adminDetected: return .purple
        case .userDetected: return .green
        default: return .blue
        }
    }
    
    private var statusTitle: String {
        switch state {
        case .connecting: return "Connecting..."
        case .checkingPermissions: return "Checking Permissions"
        case .adminDetected: return "Admin Access"
        case .userDetected: return "User Access"
        default: return "Processing..."
        }
    }
    
    private var statusSubtitle: String {
        switch state {
        case .connecting: return "Establishing connection to panel"
        case .checkingPermissions: return "Detecting API key permissions"
        case .adminDetected: return "Full Application API access\nYou can create servers!"
        case .userDetected: return "Client API access\nManage your servers"
        default: return ""
        }
    }
}
