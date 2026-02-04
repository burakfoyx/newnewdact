import SwiftUI
import StoreKit

// MARK: - Full Paywall View
struct PaywallView: View {
    var highlightedFeature: Feature? = nil
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: ProductID = .proYearly
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.02, blue: 0.15),
                        Color(red: 0.10, green: 0.05, blue: 0.20),
                        Color(red: 0.05, green: 0.02, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Plan Selector
                        planSelector
                        
                        // Feature Comparison
                        featureComparison
                        
                        // Purchase Button
                        purchaseButton
                        
                        // Restore & Legal
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
                            .foregroundStyle(.white.opacity(0.6))
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
            // Crown Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .orange.opacity(0.5), radius: 20)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            
            Text("Upgrade to Pro")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            
            Text("Unlock powerful features to manage your servers like a pro")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Plan Selector
    private var planSelector: some View {
        VStack(spacing: 12) {
            // Pro Plans
            HStack(spacing: 12) {
                PlanCard(
                    title: "Monthly",
                    price: subscriptionManager.formattedPrice(for: .proMonthly) ?? "€4.99",
                    period: "/month",
                    isSelected: selectedPlan == .proMonthly,
                    badge: nil
                ) {
                    selectedPlan = .proMonthly
                }
                
                PlanCard(
                    title: "Yearly",
                    price: subscriptionManager.formattedPrice(for: .proYearly) ?? "€39.99",
                    period: "/year",
                    isSelected: selectedPlan == .proYearly,
                    badge: "Save 33%"
                ) {
                    selectedPlan = .proYearly
                }
            }
            
            // Lifetime Option
            PlanCard(
                title: "Lifetime",
                price: subscriptionManager.formattedPrice(for: .lifetimePro) ?? "€29.99",
                period: "one-time",
                isSelected: selectedPlan == .lifetimePro,
                badge: "Best Value",
                isWide: true
            ) {
                selectedPlan = .lifetimePro
            }
        }
    }
    
    // MARK: - Feature Comparison
    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.headline)
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                FeatureRow(icon: "chart.xyaxis.line", title: "Historical Analytics", description: "View resource usage over time", isIncluded: true)
                FeatureRow(icon: "bell.badge", title: "Custom Alerts", description: "Get notified when thresholds are exceeded", isIncluded: true)
                FeatureRow(icon: "folder.fill", title: "Server Groups", description: "Organize servers into groups (up to 5)", isIncluded: true)
                FeatureRow(icon: "star.fill", title: "Favorites", description: "Pin servers to the top", isIncluded: true)
                FeatureRow(icon: "arrow.clockwise", title: "Faster Refresh", description: "5s/10s refresh intervals", isIncluded: true)
                FeatureRow(icon: "tag.fill", title: "Custom Labels", description: "Add labels and colors to servers", isIncluded: true)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Purchase Button
    private var purchaseButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.black)
                } else {
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
            .shadow(color: .orange.opacity(0.4), radius: 10, y: 5)
        }
        .disabled(isPurchasing)
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
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // Legal Text
            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            
            // Links
            HStack(spacing: 20) {
                Link("Terms of Use", destination: URL(string: "https://xyidactyl.app/terms")!)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                
                Link("Privacy Policy", destination: URL(string: "https://xyidactyl.app/privacy")!)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - Purchase Logic
    private func purchase() async {
        guard let product = subscriptionManager.product(for: selectedPlan) else {
            errorMessage = "Product not available"
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

// MARK: - Plan Card
struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let isSelected: Bool
    let badge: String?
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
                }
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: isWide ? .infinity : nil)
            .frame(minWidth: isWide ? nil : 140)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? 
                                    LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [.white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isIncluded: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.yellow)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: isIncluded ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(isIncluded ? .green : .gray)
        }
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
                    .foregroundStyle(.yellow)
                
                Text(feature.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            Text(feature.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showPaywall) {
            PaywallView(highlightedFeature: feature)
        }
    }
}

#Preview {
    PaywallView()
}
