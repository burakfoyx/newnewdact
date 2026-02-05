import Foundation
import StoreKit

// MARK: - Product Identifiers
enum ProductID: String, CaseIterable {
    case proMonthly = "pro_monthly"
    case proYearly = "pro_yearly"
    case hostMonthly = "host_monthly"
    case hostYearly = "host_yearly"
    case lifetimePro = "lifetime_pro"
    case lifetimeHost = "lifetime_host"
    
    var displayName: String {
        switch self {
        case .proMonthly: return "Pro Monthly"
        case .proYearly: return "Pro Yearly"
        case .hostMonthly: return "Host Monthly"
        case .hostYearly: return "Host Yearly"
        case .lifetimePro: return "Pro Lifetime"
        case .lifetimeHost: return "Host Lifetime"
        }
    }
    
    var tier: UserTier {
        switch self {
        case .proMonthly, .proYearly, .lifetimePro:
            return .pro
        case .hostMonthly, .hostYearly, .lifetimeHost:
            return .host
        }
    }
    
    var isLifetime: Bool {
        self == .lifetimePro || self == .lifetimeHost
    }
}

// MARK: - User Tier
enum UserTier: Int, Comparable, Codable {
    case free = 0
    case pro = 1
    case host = 2
    
    static func < (lhs: UserTier, rhs: UserTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .host: return "Host"
        }
    }
}

// MARK: - Subscription Status
struct SubscriptionStatus {
    let tier: UserTier
    let isLifetime: Bool
    let expirationDate: Date?
    let willRenew: Bool
    
    static let free = SubscriptionStatus(tier: .free, isLifetime: false, expirationDate: nil, willRenew: false)
}

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .free
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    @Published var debugTierOverride: UserTier?
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products and check entitlements on init
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Current Tier (Convenience)
    var currentTier: UserTier {
        if let override = debugTierOverride {
            return override
        }
        return subscriptionStatus.tier
    }
    
    var isPro: Bool {
        currentTier >= .pro
    }
    
    var isHost: Bool {
        currentTier >= .host
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
            products.sort { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("StoreKit Error: \(error)")
        }
    }
    
    // MARK: - Purchase
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            // Transaction is pending (e.g., Ask to Buy)
            return false
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Update Subscription Status
    func updateSubscriptionStatus() async {
        var highestTier: UserTier = .free
        var isLifetime = false
        var latestExpiration: Date?
        var willRenew = false
        
        // Check all transactions
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if let productID = ProductID(rawValue: transaction.productID) {
                // Update tier
                if productID.tier > highestTier {
                    highestTier = productID.tier
                }
                
                // Check lifetime
                if productID.isLifetime {
                    isLifetime = true
                }
                
                // Track expiration for subscriptions
                if let expiration = transaction.expirationDate {
                    if latestExpiration == nil || expiration > latestExpiration! {
                        latestExpiration = expiration
                    }
                }
                
                // Check auto-renew status
                if transaction.revocationDate == nil {
                    willRenew = true
                }
                
                purchasedProductIDs.insert(transaction.productID)
            }
        }
        
        subscriptionStatus = SubscriptionStatus(
            tier: highestTier,
            isLifetime: isLifetime,
            expirationDate: latestExpiration,
            willRenew: willRenew
        )
    }
    
    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerifiedStatic(result)
                    _ = await MainActor.run {
                        Task {
                            await self.updateSubscriptionStatus()
                        }
                    }
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification Helper (instance method for MainActor context)
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // Static nonisolated version for detached tasks
    private static nonisolated func checkVerifiedStatic<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Get Product by ID
    func product(for productID: ProductID) -> Product? {
        products.first { $0.id == productID.rawValue }
    }
    
    // MARK: - Formatted Price
    func formattedPrice(for productID: ProductID) -> String? {
        product(for: productID)?.displayPrice
    }
}

// MARK: - Store Errors
enum StoreError: Error, LocalizedError {
    case verificationFailed
    case productNotFound
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}
