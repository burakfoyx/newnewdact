import SwiftUI
import StoreKit

// MARK: - Full Paywall View (Liquid Glass Design)
struct PaywallView: View {
    var highlightedFeature: Feature? = nil
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedTier: UserTier = .pro
    @State private var selectedPlan: ProductID = .proYearly
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Use app's Liquid Glass background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Tier Selector (Pro / Host)
                        tierSelector
                        
                        // Plan Options for selected tier
                        planSelector
                        
                        // Feature List
                        featureList
                        
                        // Purchase Button
                        purchaseButton
                        
                        // Footer
                        footerSection
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Animated Crown/Star Icon
            ZStack {
// Header Circle
                Color.clear
                    .frame(width: 90, height: 90)
                    .background(.regularMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.6), .orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .orange.opacity(0.3), radius: 20)
            
            Text("Unlock Full Potential")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Choose the plan that fits your needs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Tier Selector
    private var tierSelector: some View {
        HStack(spacing: 4) {
            TierTab(
                title: "Pro",
                subtitle: "For individuals",
                isSelected: selectedTier == .pro
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTier = .pro
                    selectedPlan = .proYearly
                }
            }
            
            TierTab(
                title: "Host",
                subtitle: "For providers",
                isSelected: selectedTier == .host
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTier = .host
                    selectedPlan = .hostYearly
                }
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    // MARK: - Plan Selector
    private var planSelector: some View {
        VStack(spacing: 12) {
            if selectedTier == .pro {
                // Pro Plans
                HStack(spacing: 12) {
                    GlassPlanCard(
                        title: "Monthly",
                        price: subscriptionManager.formattedPrice(for: .proMonthly) ?? "€4.99",
                        period: "/month",
                        badge: nil,
                        isSelected: selectedPlan == .proMonthly
                    ) {
                        selectedPlan = .proMonthly
                    }
                    
                    GlassPlanCard(
                        title: "Yearly",
                        price: subscriptionManager.formattedPrice(for: .proYearly) ?? "€39.99",
                        period: "/year",
                        badge: "Save 33%",
                        isSelected: selectedPlan == .proYearly
                    ) {
                        selectedPlan = .proYearly
                    }
                }
                
                GlassPlanCard(
                    title: "Lifetime",
                    price: subscriptionManager.formattedPrice(for: .lifetimePro) ?? "€29.99",
                    period: "one-time",
                    badge: "Best Value",
                    isSelected: selectedPlan == .lifetimePro,
                    isWide: true
                ) {
                    selectedPlan = .lifetimePro
                }
            } else {
                // Host Plans
                HStack(spacing: 12) {
                    GlassPlanCard(
                        title: "Monthly",
                        price: subscriptionManager.formattedPrice(for: .hostMonthly) ?? "€9.99",
                        period: "/month",
                        badge: nil,
                        isSelected: selectedPlan == .hostMonthly
                    ) {
                        selectedPlan = .hostMonthly
                    }
                    
                    GlassPlanCard(
                        title: "Yearly",
                        price: subscriptionManager.formattedPrice(for: .hostYearly) ?? "€79.99",
                        period: "/year",
                        badge: "Save 33%",
                        isSelected: selectedPlan == .hostYearly
                    ) {
                        selectedPlan = .hostYearly
                    }
                }
                
                GlassPlanCard(
                    title: "Lifetime",
                    price: subscriptionManager.formattedPrice(for: .lifetimeHost) ?? "€49.99",
                    period: "one-time",
                    badge: "Best Value",
                    isSelected: selectedPlan == .lifetimeHost,
                    isWide: true
                ) {
                    selectedPlan = .lifetimeHost
                }
            }
        }
    }
    
    // MARK: - Feature List
    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedTier == .pro ? "Pro Features" : "Host Features")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                if selectedTier == .pro {
                    GlassFeatureRow(icon: "chart.xyaxis.line", title: "Historical Analytics", description: "30-day resource history")
                    Divider()
                    GlassFeatureRow(icon: "bell.badge", title: "Custom Alerts", description: "Up to 5 alert rules")
                    Divider()
                    GlassFeatureRow(icon: "folder.fill", title: "Server Groups", description: "Organize into 5 groups")
                    Divider()
                    GlassFeatureRow(icon: "star.fill", title: "Favorites", description: "Pin servers to top")
                    Divider()
                    GlassFeatureRow(icon: "arrow.clockwise", title: "Faster Refresh", description: "5s/10s intervals")
                } else {
                    GlassFeatureRow(icon: "checkmark.seal.fill", title: "All Pro Features", description: "Everything in Pro, plus...")
                    Divider()
                    GlassFeatureRow(icon: "gearshape.2.fill", title: "Automation Rules", description: "Unlimited automated actions")
                    Divider()
                    GlassFeatureRow(icon: "cpu", title: "Node Intelligence", description: "Advanced node analytics")
                    Divider()
                    GlassFeatureRow(icon: "bell.fill", title: "Unlimited Alerts", description: "No limits on alert rules")
                    Divider()
                    GlassFeatureRow(icon: "arrow.up.forward.app", title: "Webhooks", description: "Discord, Slack & more")
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
    
    // MARK: - Purchase Button
    private var purchaseButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView()
                        .tint(.accentColor)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.body.bold())
                    Text("Continue with \(selectedPlan.displayName)")
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.black)
            .clipShape(Capsule())
            .shadow(color: .orange.opacity(0.4), radius: 12, y: 6)
        }
        .disabled(isPurchasing)
        .padding(.top, 8)
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Restore Purchases
            Button {
                Task {
                    isPurchasing = true
                    await subscriptionManager.restorePurchases()
                    isPurchasing = false
                    if subscriptionManager.currentTier != .free {
                        dismiss()
                    }
                }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Legal Text
            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            // Links
            HStack(spacing: 20) {
                Link("Terms of Use", destination: URL(string: "https://xyidactyl.app/terms")!)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Link("Privacy Policy", destination: URL(string: "https://xyidactyl.app/privacy")!)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Purchase Logic
    private func purchase() async {
        guard let product = subscriptionManager.product(for: selectedPlan) else {
            errorMessage = "Product not available. Please try again later."
            showError = true
            return
        }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let success = try await subscriptionManager.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Tier Tab
struct TierTab: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .secondary : .tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(
                isSelected ?
                    AnyShapeStyle(Color(.tertiarySystemFill)) :
                    AnyShapeStyle(Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Glass Plan Card
struct GlassPlanCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String?
    let isSelected: Bool
    var isWide: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let badge = badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                } else {
                    // Invisible spacer to keep cards same height
                    Text(" ")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .opacity(0)
                }
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 100)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected ?
                            LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isSelected ? 2 : 0
                    )
            )
            .shadow(color: isSelected ? .orange.opacity(0.3) : .clear, radius: 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Glass Feature Row
struct GlassFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(.green)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Upgrade Prompt (Contextual)
struct UpgradePromptView: View {
    let feature: Feature
    @State private var showPaywall = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: feature.icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(feature.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            Text(feature.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showPaywall = true
            } label: {
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showPaywall) {
            PaywallView(highlightedFeature: feature)
        }
    }
}

#Preview {
    PaywallView()
}
