import SwiftUI

struct SettingsView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var serverPrefs = ServerPreferencesManager.shared
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                List {
                    subscriptionSection
                    agentSection
                    refreshSection
                    aboutSection
                    linksSection
                    infoSection
                    debugSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NotificationBellButton()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
    
    // MARK: - Subscription Section
    
    private var subscriptionSection: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                subscriptionButtonContent
            }
        } header: {
            Text("Subscription")
        }
    }
    
    private var subscriptionButtonContent: some View {
        HStack(spacing: 16) {
            subscriptionIcon
            subscriptionText
            Spacer()
            if subscriptionManager.currentTier == .free {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var subscriptionIcon: some View {
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
    }
    
    private var subscriptionText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(subscriptionManager.currentTier == .free ? "Upgrade to Pro" : "\(subscriptionManager.currentTier.displayName) Member")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(subscriptionManager.currentTier == .free ? "Unlock analytics, alerts & more" : "Thank you for your support!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // Appearance section removed — wallpaper picker no longer needed
    
    // MARK: - Refresh Section
    
    private var refreshSection: some View {
        Section("Refresh Interval") {
            Picker("Auto-refresh", selection: $serverPrefs.refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.displayName)
                        .tag(interval)
                }
            }
            
            if subscriptionManager.currentTier == .free {
                Text("5s and 10s intervals require Pro")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Agent Section
    
    private var agentSection: some View {
        AgentSettingsView()
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section("About") {
            infoRow(label: "Version", value: "1.1.0")
            infoRow(label: "Build", value: "iOS 26")
            infoRow(label: "Developer", value: "XY Studios")
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Links Section
    
    private var linksSection: some View {
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
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        Section {
            Text("Manage panels in the Panels tab")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Debug Section
    
    private var debugSection: some View {
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
            
            NavigationLink("Live CPU App Profiler") {
                AppProfilerView()
            }
        }
    }
}
