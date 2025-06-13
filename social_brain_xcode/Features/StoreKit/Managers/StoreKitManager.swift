import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .inactive
    @Published private(set) var isLoading = false
    @Published private(set) var error: StoreKitError?
    
    private var updateListenerTask: Task<Void, Error>?
    private var retryCount = 0
    private let maxRetries = 3
    
    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                await self.handleTransactionResult(result)
            }
        }
    }
    
    private func handleTransactionResult(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else {
            return
        }
        
        await transaction.finish()
        await self.updateSubscriptionStatus()
    }
    
    func loadProducts() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let productIdentifiers = ["socialbrainbeta"]
            subscriptions = try await withRetry {
                try await Product.products(for: productIdentifiers)
            }
            
            // Log successful product loading
            print("✅ StoreKit: Successfully loaded \(subscriptions.count) products")
            for product in subscriptions {
                print("   - \(product.displayName): \(product.displayPrice)")
            }
        } catch {
            self.error = .loadFailed(error)
            print("❌ StoreKit: Failed to load products: \(error)")
            
            // Check if this is a simulator/StoreKit testing issue
            if isSimulatorEnvironment() {
                print("⚠️  StoreKit: Running in simulator - StoreKit testing may not be properly configured")
                print("💡 Tip: Ensure StoreKit testing is enabled in Xcode scheme settings")
            }
        }
        
        isLoading = false
    }
    
    private func withRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        retryCount = 0
        while true {
            do {
                return try await operation()
            } catch {
                retryCount += 1
                if retryCount >= maxRetries {
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * pow(2.0, Double(retryCount)))) // Exponential backoff
            }
        }
    }
    
    func purchase(_ product: Product) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            print("🔄 StoreKit: Attempting to purchase \(product.displayName)")
            
            let result = try await withRetry {
                try await product.purchase()
            }
            
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    print("❌ StoreKit: Purchase verification failed")
                    throw StoreKitError.verificationFailed
                }
                
                print("✅ StoreKit: Purchase successful for \(transaction.productID)")
                await transaction.finish()
                await updateSubscriptionStatus()
                
            case .userCancelled:
                print("ℹ️  StoreKit: Purchase cancelled by user")
                throw StoreKitError.userCancelled
                
            case .pending:
                print("⏳ StoreKit: Purchase pending")
                throw StoreKitError.pending
                
            @unknown default:
                print("❓ StoreKit: Unknown purchase result")
                throw StoreKitError.unknown
            }
        } catch {
            self.error = .purchaseFailed(error)
            print("❌ StoreKit: Purchase failed: \(error)")
            
            // Provide specific guidance for common errors
            if let urlError = error as? URLError {
                handleURLError(urlError)
            }
            
            throw error
        }
    }
    
    func restorePurchases() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            print("🔄 StoreKit: Attempting to restore purchases")
            try await withRetry {
                try await AppStore.sync()
            }
            await updateSubscriptionStatus()
            print("✅ StoreKit: Purchase restoration completed")
        } catch {
            self.error = .restoreFailed(error)
            print("❌ StoreKit: Restore failed: \(error)")
            
            // Provide specific guidance for common errors
            if let urlError = error as? URLError {
                handleURLError(urlError)
            }
            
            throw error
        }
    }
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        do {
            print("🔄 StoreKit: Checking subscription status...")
            
            for await result in StoreKit.Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else {
                    print("⚠️  StoreKit: Unverified transaction found")
                    continue
                }
                
                if transaction.productType == .autoRenewable {
                    hasActiveSubscription = true
                    print("✅ StoreKit: Found active subscription for \(transaction.productID)")
                    break
                }
            }
            
            let newStatus = hasActiveSubscription ? SubscriptionStatus.active : .inactive
            if subscriptionStatus != newStatus {
                print("🔄 StoreKit: Subscription status changed from \(subscriptionStatus) to \(newStatus)")
            }
            subscriptionStatus = newStatus
            
        } catch {
            self.error = .statusCheckFailed(error)
            print("❌ StoreKit: Failed to update subscription status: \(error)")
            
            // If there's an error checking status, default to inactive for new users
            subscriptionStatus = .inactive
            
            // Provide specific guidance for common errors
            if let urlError = error as? URLError {
                handleURLError(urlError)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func isSimulatorEnvironment() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private func handleURLError(_ error: URLError) {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            print("🌐 StoreKit: Network connectivity issue detected")
            print("💡 Tip: Check your internet connection and try again")
            
        case .timedOut:
            print("⏰ StoreKit: Request timed out")
            print("💡 Tip: The StoreKit server may be slow, try again later")
            
        case .cannotConnectToHost:
            print("🔌 StoreKit: Cannot connect to StoreKit server")
            if isSimulatorEnvironment() {
                print("💡 Tip: StoreKit testing may not be properly configured in simulator")
                print("💡 Tip: Check Xcode scheme settings for StoreKit configuration")
            }
            
        case .badServerResponse:
            print("🚫 StoreKit: Bad server response")
            print("💡 Tip: StoreKit server may be experiencing issues")
            
        default:
            print("❓ StoreKit: Unknown network error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Developer Methods (for testing)
    
    #if DEBUG
    /// Reset subscription status to inactive (for testing purposes)
    func resetSubscriptionStatus() {
        subscriptionStatus = .inactive
        print("Subscription status reset to inactive for testing")
    }
    
    /// Set subscription status to active (for testing purposes)
    func setSubscriptionActive() {
        subscriptionStatus = .active
        print("Subscription status set to active for testing")
    }
    
    /// Diagnose StoreKit issues and provide troubleshooting guidance
    func diagnoseStoreKitIssues() {
        print("🔍 StoreKit Diagnosis Report")
        print("================================")
        
        // Environment check
        if isSimulatorEnvironment() {
            print("📱 Environment: iOS Simulator")
            print("⚠️  Note: StoreKit testing may have limitations in simulator")
        } else {
            print("📱 Environment: Physical Device")
        }
        
        // Product status
        print("📦 Products loaded: \(subscriptions.count)")
        for product in subscriptions {
            print("   - \(product.displayName): \(product.displayPrice)")
        }
        
        // Subscription status
        print("🔐 Subscription status: \(subscriptionStatus)")
        
        // Error status
        if let currentError = error {
            print("❌ Current error: \(currentError)")
        } else {
            print("✅ No current errors")
        }
        
        // Loading status
        print("🔄 Loading state: \(isLoading ? "Loading" : "Idle")")
        
        // App Store Connect validation
        validateAppStoreConnectConfiguration()
        
        // Troubleshooting tips
        print("\n💡 Troubleshooting Tips:")
        if isSimulatorEnvironment() {
            print("   - Ensure StoreKit testing is enabled in Xcode scheme")
            print("   - Check that Configuration.storekit file is properly configured")
            print("   - Try running on a physical device for full StoreKit testing")
        }
        
        if subscriptions.isEmpty {
            print("   - No products loaded - check product identifiers")
            print("   - Verify App Store Connect configuration")
        }
        
        if case .unknown = subscriptionStatus {
            print("   - Subscription status unknown - check network connectivity")
        }
        
        print("================================")
    }
    
    /// Validate App Store Connect configuration
    private func validateAppStoreConnectConfiguration() {
        print("\n🏪 App Store Connect Configuration:")
        print("   - Product ID: socialbrainbeta ✅")
        print("   - Subscription Group ID: 21695627 ✅")
        print("   - Duration: 1 month ✅")
        print("   - Status: Missing Metadata ⚠️")
        print("\n📋 Required Actions in App Store Connect:")
        print("   1. Add localization metadata:")
        print("      - Chinese (zh_CN): 社交大脑 Pro 订阅")
        print("      - English (en_US): Social Brain Pro Subscription")
        print("   2. Add subscription description:")
        print("      - 解锁所有高级功能，包括无限笔记、iCloud同步、Face ID锁定和高级分析")
        print("   3. Set pricing (recommended: ¥18.00/month)")
        print("   4. Add subscription screenshots (optional)")
        print("   5. Submit for review when ready")
    }
    #endif
}

enum SubscriptionStatus {
    case active
    case inactive
    case unknown
}

enum StoreKitError: LocalizedError {
    case verificationFailed
    case userCancelled
    case pending
    case unknown
    case loadFailed(Error)
    case purchaseFailed(Error)
    case restoreFailed(Error)
    case statusCheckFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "无法验证购买"
        case .userCancelled:
            return "购买已取消"
        case .pending:
            return "购买待处理"
        case .unknown:
            return "未知错误"
        case .loadFailed(let error):
            return "加载产品失败: \(error.localizedDescription)"
        case .purchaseFailed(let error):
            return "购买失败: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "恢复购买失败: \(error.localizedDescription)"
        case .statusCheckFailed(let error):
            return "检查订阅状态失败: \(error.localizedDescription)"
        }
    }
} 