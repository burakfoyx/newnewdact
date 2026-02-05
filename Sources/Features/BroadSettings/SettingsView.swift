import SwiftUI

struct SettingsView: View {
    @ObservedObject private var backgroundSettings = BackgroundSettings.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                List {
                    // Subscription Section
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 16) {
                                // Crown Icon
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: subscriptionManager.currentTier == .free ? [.yellow, .orange] : [.green, .teal],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: subscriptionManager.currentTier == .free ? "crown.fill" : "checkmark.seal.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subscriptionManager.currentTier == .free ? "Upgrade to Pro" : "\(subscriptionManager.currentTier.displayName) Member")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    Text(subscriptionManager.currentTier == .free ? "Unlock analytics, alerts & more" : "Thank you for your support!")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if subscriptionManager.currentTier == .free {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    } header: {
                        Text("Subscription")
                    }
                    
                    // Background Selection
                    Section("Appearance") {
                        ForEach(BackgroundStyle.allCases) { style in
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    backgroundSettings.selectedBackground = style
                                }
                            } label: {
                                HStack {
                                    // Preview thumbnail
                                    Image(style.rawValue)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 35)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    Text(style.displayName)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if backgroundSettings.selectedBackground == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.1.0")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Build")
                            Spacer()
                            Text("iOS 26")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Developer")
                            Spacer()
                            Text("XY Studios")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Section {
                        Link(destination: URL(string: "https://pterodactyl.io")!) {
                            HStack {
                                Text("Pterodactyl Panel")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Section {
                        Text("Manage panels in the Panels tab")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // #if DEBUG
                    Section("Debug Actions (Dev Only)") {
                        Picker("Force Tier", selection: $subscriptionManager.debugTierOverride) {
                            Text("Real").tag(Optional<UserTier>.none)
                            Text("Free").tag(Optional<UserTier>.some(.free))
                            Text("Pro").tag(Optional<UserTier>.some(.pro))
                            Text("Host").tag(Optional<UserTier>.some(.host))
                        }
                        
                        Button("Reset Debug Tier") {
                            subscriptionManager.debugTierOverride = nil
                        }
                    }
                    // #endif
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
        .background(Color.clear)
    }
}
