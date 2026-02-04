import SwiftUI

// MARK: - Feature Definition
enum Feature: String, CaseIterable {
    // Pro Features
    case historicalAnalytics
    case customAlerts
    case serverGroups
    case fasterRefresh
    case serverFavorites
    case customLabels
    
    // Host Features
    case automationRules
    case nodeIntelligence
    case webhookIntegration
    case unlimitedAlerts
    case unlimitedGroups
    case mountIntelligence
    
    /// Minimum tier required to access this feature
    var requiredTier: UserTier {
        switch self {
        // Pro tier features
        case .historicalAnalytics, .customAlerts, .serverGroups,
             .fasterRefresh, .serverFavorites, .customLabels:
            return .pro
            
        // Host tier features
        case .automationRules, .nodeIntelligence, .webhookIntegration,
             .unlimitedAlerts, .unlimitedGroups, .mountIntelligence:
            return .host
        }
    }
    
    var displayName: String {
        switch self {
        case .historicalAnalytics: return "Historical Analytics"
        case .customAlerts: return "Custom Alerts"
        case .serverGroups: return "Server Groups"
        case .fasterRefresh: return "Faster Refresh"
        case .serverFavorites: return "Server Favorites"
        case .customLabels: return "Custom Labels"
        case .automationRules: return "Automation Rules"
        case .nodeIntelligence: return "Node Intelligence"
        case .webhookIntegration: return "Webhook Integration"
        case .unlimitedAlerts: return "Unlimited Alerts"
        case .unlimitedGroups: return "Unlimited Groups"
        case .mountIntelligence: return "Mount Intelligence"
        }
    }
    
    var description: String {
        switch self {
        case .historicalAnalytics:
            return "View CPU, RAM, and disk usage history over time"
        case .customAlerts:
            return "Set up alerts for resource thresholds and server status"
        case .serverGroups:
            return "Organize servers into custom groups"
        case .fasterRefresh:
            return "Refresh server stats every 5 or 10 seconds"
        case .serverFavorites:
            return "Pin your most-used servers to the top"
        case .customLabels:
            return "Add custom labels and colors to servers"
        case .automationRules:
            return "Create automated actions based on triggers"
        case .nodeIntelligence:
            return "Advanced node-level analytics and forecasting"
        case .webhookIntegration:
            return "Send alerts to Discord, Slack, and custom webhooks"
        case .unlimitedAlerts:
            return "Create unlimited alert rules"
        case .unlimitedGroups:
            return "Create unlimited server groups"
        case .mountIntelligence:
            return "Analyze mount dependencies between servers"
        }
    }
    
    var icon: String {
        switch self {
        case .historicalAnalytics: return "chart.xyaxis.line"
        case .customAlerts: return "bell.badge"
        case .serverGroups: return "folder.fill"
        case .fasterRefresh: return "arrow.clockwise"
        case .serverFavorites: return "star.fill"
        case .customLabels: return "tag.fill"
        case .automationRules: return "gearshape.2.fill"
        case .nodeIntelligence: return "cpu"
        case .webhookIntegration: return "arrow.up.forward.app"
        case .unlimitedAlerts: return "bell.fill"
        case .unlimitedGroups: return "folder.fill.badge.plus"
        case .mountIntelligence: return "externaldrive.connected.to.line.below"
        }
    }
}

// MARK: - Feature Flags Manager
@MainActor
class FeatureFlags: ObservableObject {
    static let shared = FeatureFlags()
    
    private var subscriptionManager: SubscriptionManager {
        SubscriptionManager.shared
    }
    
    private init() {}
    
    /// Check if a feature is available for the current user
    func isAvailable(_ feature: Feature) -> Bool {
        subscriptionManager.currentTier >= feature.requiredTier
    }
    
    /// Get the limitation for a feature (e.g., number of groups allowed)
    func limit(for feature: Feature) -> Int? {
        switch feature {
        case .customAlerts:
            switch subscriptionManager.currentTier {
            case .free: return 0
            case .pro: return 5
            case .host: return .max
            }
        case .serverGroups:
            switch subscriptionManager.currentTier {
            case .free: return 1
            case .pro: return 5
            case .host: return .max
            }
        default:
            return nil
        }
    }
    
    /// Get all features available at a specific tier
    func features(for tier: UserTier) -> [Feature] {
        Feature.allCases.filter { $0.requiredTier <= tier }
    }
    
    /// Get features that would be unlocked by upgrading to a tier
    func newFeatures(upgrading to: UserTier) -> [Feature] {
        let current = subscriptionManager.currentTier
        return Feature.allCases.filter { 
            $0.requiredTier > current && $0.requiredTier <= to 
        }
    }
}

// MARK: - Feature Gated View Modifier
struct FeatureGatedModifier: ViewModifier {
    let feature: Feature
    let showPrompt: Bool
    @State private var showingPaywall = false
    
    func body(content: Content) -> some View {
        if FeatureFlags.shared.isAvailable(feature) {
            content
        } else if showPrompt {
            Button {
                showingPaywall = true
            } label: {
                content
                    .opacity(0.5)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(.ultraThinMaterial))
                    )
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(highlightedFeature: feature)
            }
        } else {
            EmptyView()
        }
    }
}

extension View {
    /// Gate a view behind a feature tier. If user doesn't have access, shows locked state.
    func featureGated(_ feature: Feature, showPrompt: Bool = true) -> some View {
        modifier(FeatureGatedModifier(feature: feature, showPrompt: showPrompt))
    }
}

// MARK: - Upgrade Prompt View
struct UpgradePromptView: View {
    let feature: Feature
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: feature.icon)
                    .font(.title3)
                    .foregroundStyle(.yellow)
                
                Text(feature.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            Text(feature.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button(action: onUpgrade) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to \(feature.requiredTier.displayName)")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Placeholder PaywallView (to be replaced)
struct PaywallView: View {
    var highlightedFeature: Feature? = nil
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Upgrade to Pro")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    
                    Text("Unlock powerful features")
                        .foregroundStyle(.white.opacity(0.7))
                    
                    // Placeholder - will be replaced with full paywall
                    Text("Full paywall coming soon...")
                        .foregroundStyle(.gray)
                        .padding(.top, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
