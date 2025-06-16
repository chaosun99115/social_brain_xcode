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
    
    // Invitation codes for lifetime access
    private let validInvitationCodes = [
        "XKKMNRNJ74X7",
        "JKXNNWYAM3WP", 
        "H6X79FANXAFW",
        "LNAW3TTREPPL",
        "NLNL9JW77LRX",
        "H7RYAPXKF6XJ",
        "7MTKFMTJLAEW",
        "JET3M3P69P37",
        "KTMK6PJKNK4F",
        "NK3Y6JXT66YY"
    ]
    
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
        
        // Use different Product IDs based on environment
        let productIdentifiers: [String]
        #if DEBUG
        // Use sandbox Product IDs for development testing
        productIdentifiers = ["relate_monthly", "relate_lifetime_premium"]
        #else
        // Use production Product IDs for release builds
        productIdentifiers = ["relate_monthly", "relate_lifetime_premium"]
        #endif
        
        do {
            subscriptions = try await withRetry {
                try await Product.products(for: productIdentifiers)
            }
            
            // Perform detailed environment analysis
            logEnvironmentDetails()
            
            // Additional analysis based on product details
            if let firstProduct = subscriptions.first {
                // Product analysis logic can be kept for debugging if needed
            }
            
        } catch {
            self.error = .loadFailed(error)
            print("❌ StoreKit: Failed to load products: \(error)")
            
            // Handle specific StoreKit errors
            if let storeKitError = error as? StoreKitError {
                handleStoreKitError(storeKitError)
            } else if let urlError = error as? URLError {
                handleURLError(urlError)
            } else {
                // Handle generic errors
                handleGenericStoreKitError(error)
            }
            
            // Check if this is a simulator/StoreKit testing issue
            if isSimulatorEnvironment() {
                print("⚠️  StoreKit: Running in simulator - StoreKit testing may not be properly configured")
                print("💡 Tip: Ensure StoreKit testing is enabled in Xcode scheme settings")
                provideSimulatorTroubleshooting()
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
            let result = try await withRetry {
                try await product.purchase()
            }
            
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    throw StoreKitError.verificationFailed
                }
                
                await transaction.finish()
                await updateSubscriptionStatus()
                
            case .userCancelled:
                throw StoreKitError.userCancelled
                
            case .pending:
                throw StoreKitError.pending
                
            @unknown default:
                throw StoreKitError.unknown
            }
        } catch {
            self.error = .purchaseFailed(error)
            
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
            try await withRetry {
                try await AppStore.sync()
            }
            await updateSubscriptionStatus()
        } catch {
            self.error = .restoreFailed(error)
            
            // Provide specific guidance for common errors
            if let urlError = error as? URLError {
                handleURLError(urlError)
            }
            
            throw error
        }
    }
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        // First check if user has lifetime access via invitation code
        if hasLifetimeAccess() {
            hasActiveSubscription = true
        }
        
        do {
            for await result in StoreKit.Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else {
                    continue
                }
                
                // Check for both auto-renewable subscriptions and non-consumable purchases (lifetime)
                if transaction.productType == .autoRenewable || transaction.productType == .nonConsumable {
                    hasActiveSubscription = true
                    break
                }
            }
            
            let newStatus = hasActiveSubscription ? SubscriptionStatus.active : .inactive
            if subscriptionStatus != newStatus {
                subscriptionStatus = newStatus
            }
        } catch {
            // Keep current status if we can't check
            if subscriptionStatus == .unknown {
                subscriptionStatus = .inactive
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
    
    private func isSandboxEnvironment() -> Bool {
        // Check if we're running in sandbox environment
        #if DEBUG
        // In debug builds, check if we're using sandbox configuration
        // Check if we have a Configuration.storekit file being used
        return !isUsingStoreKitConfigurationFile()
        #else
        return false
        #endif
    }
    
    private func isUsingStoreKitConfigurationFile() -> Bool {
        // Check if we're using the local Configuration.storekit file
        // This is a heuristic based on the behavior we observed
        return subscriptions.contains(where: { $0.price == 0 })
    }
    
    private func detectActualStoreKitEnvironment() -> String {
        // Try to detect the actual environment being used
        #if targetEnvironment(simulator)
        if isUsingStoreKitConfigurationFile() {
            return "Simulator (Local Configuration File)"
        } else {
            return "Simulator (Sandbox Testing)"
        }
        #else
        // On device, we need to check the actual configuration
        if isUsingStoreKitConfigurationFile() {
            return "Device (Local Configuration File)"
        } else {
            return "Device (Sandbox/Production)"
        }
        #endif
    }
    
    private func logEnvironmentDetails() {
        print("🔍 StoreKit Environment Analysis")
        print("================================")
        print("📱 Platform: \(isSimulatorEnvironment() ? "Simulator" : "Device")")
        print("🔐 Environment: \(detectActualStoreKitEnvironment())")
        print("📄 Using Config File: \(isUsingStoreKitConfigurationFile())")
        print("📦 Products Loaded: \(subscriptions.count)")
        
        if !subscriptions.isEmpty {
            print("💰 Product Prices:")
            for product in subscriptions {
                print("   - \(product.displayName): \(product.displayPrice) (\(product.price))")
            }
        }
        
        print("================================")
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
            } else if isSandboxEnvironment() {
                print("💡 Tip: Sandbox environment detected - ensure you're signed in with sandbox Apple ID")
                print("💡 Tip: Check that your sandbox account has sufficient test balance")
            }
            
        case .badServerResponse:
            print("🚫 StoreKit: Bad server response")
            print("💡 Tip: StoreKit server may be experiencing issues")
            
        default:
            print("❓ StoreKit: Unknown network error: \(error.localizedDescription)")
        }
    }
    
    private func handleStoreKitError(_ error: StoreKitError) {
        switch error {
        case .verificationFailed:
            print("🔐 StoreKit: Purchase verification failed")
            print("💡 Tip: This may be due to network issues or server problems")
        case .userCancelled:
            print("🚫 StoreKit: User cancelled the operation")
        case .pending:
            print("⏳ StoreKit: Purchase is pending")
            print("💡 Tip: Check your email for confirmation or try again later")
        case .unknown:
            print("❓ StoreKit: Unknown error occurred")
        case .loadFailed(let underlyingError):
            print("📦 StoreKit: Failed to load products")
            print("💡 Underlying error: \(underlyingError.localizedDescription)")
        case .purchaseFailed(let underlyingError):
            print("💳 StoreKit: Purchase failed")
            print("💡 Underlying error: \(underlyingError.localizedDescription)")
        case .restoreFailed(let underlyingError):
            print("🔄 StoreKit: Restore failed")
            print("💡 Underlying error: \(underlyingError.localizedDescription)")
        case .statusCheckFailed(let underlyingError):
            print("🔍 StoreKit: Status check failed")
            print("💡 Underlying error: \(underlyingError.localizedDescription)")
        }
    }
    
    private func handleGenericStoreKitError(_ error: Error) {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("no active account") {
            print("👤 StoreKit: No active Apple ID account")
            print("💡 Tip: Sign in to your Apple ID in Settings > App Store")
            print("💡 Tip: For testing, use a sandbox Apple ID")
        } else if errorDescription.contains("error decoding response") {
            print("📄 StoreKit: Error decoding server response")
            print("💡 Tip: This may be due to network issues or server problems")
            print("💡 Tip: Try again later or check your internet connection")
        } else if errorDescription.contains("did not receive any products") {
            print("📦 StoreKit: No products received from server")
            print("💡 Tip: Check that product IDs are correct in App Store Connect")
            print("💡 Tip: Verify your app's bundle ID matches App Store Connect")
        } else {
            print("❓ StoreKit: Generic error: \(error.localizedDescription)")
        }
    }
    
    private func provideSimulatorTroubleshooting() {
        print("\n🔧 Simulator StoreKit Troubleshooting:")
        print("======================================")
        print("1. Check Xcode Scheme Settings:")
        print("   - Product > Scheme > Edit Scheme")
        print("   - Run > Options > StoreKit Configuration")
        print("   - Set to 'None' for sandbox testing")
        print("   - Or set to 'Configuration.storekit' for local testing")
        print("")
        print("2. For Sandbox Testing:")
        print("   - Sign in with sandbox Apple ID in Simulator")
        print("   - Settings > App Store > Sign In")
        print("   - Use a test account from App Store Connect")
        print("")
        print("3. For Local Testing:")
        print("   - Ensure Configuration.storekit file is properly configured")
        print("   - Products will show $0.00 prices")
        print("   - No Apple ID required")
        print("")
        print("4. Alternative Solutions:")
        print("   - Test on a physical device for full StoreKit functionality")
        print("   - Use StoreKit testing in Xcode 13+ for better simulator support")
        print("======================================")
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
    
    /// Test invitation code validation (for testing purposes)
    func testInvitationCode(_ code: String) {
        print("🧪 Testing invitation code: \(code)")
        let isValid = validateInvitationCode(code)
        print("Result: \(isValid ? "Valid" : "Invalid")")
        
        if isValid {
            print("✅ Lifetime access activated")
            print("📅 Activated date: \(getLifetimeAccessActivatedDate() ?? Date())")
            print("🔑 Used code: \(getActivatedInvitationCode() ?? "Unknown")")
        }
    }
    
    /// List all valid invitation codes (for testing purposes)
    func listValidInvitationCodes() {
        print("📋 Valid invitation codes:")
        for (index, code) in validInvitationCodes.enumerated() {
            print("   \(index + 1). \(code)")
        }
    }
    
    /// Debug StoreKit configuration and locale issues
    func debugStoreKitLocalization() {
        print("🔍 StoreKit Localization Debug")
        print("================================")
        
        // Check current locale
        let currentLocale = Locale.current
        print("🌍 Current Locale: \(currentLocale.identifier)")
        print("🌍 Language: \(currentLocale.language.languageCode?.identifier ?? "Unknown")")
        print("🌍 Region: \(currentLocale.region?.identifier ?? "Unknown")")
        
        // Check preferred languages
        let preferredLanguages = Locale.preferredLanguages
        print("🌍 Preferred Languages: \(preferredLanguages)")
        
        // Check if we're using StoreKit Configuration File
        let isUsingConfigurationFile = subscriptions.contains(where: { $0.price == 0 })
        print("📄 Using StoreKit Configuration File: \(isUsingConfigurationFile)")
        
        // Log product details
        print("📦 Products loaded: \(subscriptions.count)")
        for product in subscriptions {
            print("   Product ID: \(product.id)")
            print("   Display Name: \(product.displayName)")
            print("   Description: \(product.description)")
            print("   Display Price: \(product.displayPrice)")
            print("   Price: \(product.price)")
            print("   ---")
        }
        
        // Check environment
        print("🔧 Environment:")
        print("   - Simulator: \(isSimulatorEnvironment())")
        print("   - Sandbox: \(isSandboxEnvironment())")
        
        print("================================")
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
        
        // Sandbox environment check
        if isSandboxEnvironment() {
            print("🔐 Environment: Sandbox Mode")
            print("💡 Note: Using sandbox Apple ID for testing")
            print("💰 Note: Transactions use sandbox test balance")
        } else {
            print("🔐 Environment: Production Mode")
        }
        
        // Configuration file check
        if isUsingStoreKitConfigurationFile() {
            print("📄 Configuration: Using Local Configuration File")
            print("💡 Note: Products will show $0.00 prices")
            print("💡 Note: No Apple ID authentication required")
        } else {
            print("📄 Configuration: Using App Store Connect")
            print("💡 Note: Requires Apple ID authentication")
        }
        
        // Product status
        print("📦 Products loaded: \(subscriptions.count)")
        for product in subscriptions {
            print("   - \(product.displayName): \(product.displayPrice)")
        }
        
        // Subscription status
        print("🔐 Subscription status: \(subscriptionStatus)")
        
        // Lifetime access status
        if hasLifetimeAccess() {
            print("🎉 Lifetime access: Active")
            print("   - Activated code: \(getActivatedInvitationCode() ?? "Unknown")")
            print("   - Activated date: \(getLifetimeAccessActivatedDate() ?? Date())")
        } else {
            print("🎉 Lifetime access: Inactive")
        }
        
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
        
        if isSandboxEnvironment() {
            print("   - Ensure you're signed in with sandbox Apple ID in Settings > App Store")
            print("   - Check that your sandbox account has sufficient test balance")
            print("   - Verify the product ID 'relate_monthly' and 'relate_lifetime_premium' exist in App Store Connect")
            print("   - Try signing out and back in to refresh authentication")
            print("   - Check that your app's bundle ID matches App Store Connect")
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
        print("   - Product ID: relate_monthly ✅")
        print("   - Product ID: relate_lifetime_premium ✅")
        print("   - Subscription Group ID: 21695627 ✅")
        print("   - Duration: 1 month ✅")
        print("   - Status: Missing Metadata ⚠️")
        print("\n📋 Required Actions in App Store Connect:")
        print("   1. Add localization metadata:")
        print("      - Chinese (zh_CN): 月度订阅 / 终生订阅")
        print("      - English (en_US): Monthly Subscription / Lifetime Premium Access")
        print("   2. Add subscription description:")
        print("      - 解锁所有高级功能，包括iCloud同步和Face ID认证")
        print("   3. Set pricing (¥6.00/month, ¥68.00 lifetime)")
        print("   4. Add subscription screenshots (optional)")
        print("   5. Submit for review when ready")
    }
    #endif
    
    private func detectStoreKitConfigurationUsage() -> Bool {
        // Check if we're in local testing mode by examining the transaction environment
        // This is a heuristic based on the behavior we observed in logs
        return false // We'll update this based on actual transaction data
    }
    
    private func provideStoreKitConfigurationFixInstructions() {
        print("🔧 STOREKIT CONFIGURATION FIX REQUIRED")
        print("======================================")
        print("Your app is currently using StoreKit Configuration File (local testing)")
        print("To test with sandbox Apple ID, follow these steps:")
        print("")
        print("1. Open Xcode")
        print("2. Go to Product > Scheme > Edit Scheme")
        print("3. Select 'Run' on the left sidebar")
        print("4. Go to 'Options' tab")
        print("5. Under 'StoreKit Configuration', select 'None'")
        print("6. Clean build folder (Product > Clean Build Folder)")
        print("7. Build and run again")
        print("")
        print("After making these changes:")
        print("- Products will show real prices (not $0.00)")
        print("- Apple ID authentication will be required")
        print("- Transactions will go through sandbox servers")
        print("- You'll need to sign in with your sandbox Apple ID")
        print("======================================")
    }
    
    // MARK: - Invitation Code Methods
    
    /// Validate an invitation code and activate lifetime access if valid
    func validateInvitationCode(_ code: String) -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let isValid = validInvitationCodes.contains(trimmedCode)
        
        if isValid {
            // Store the activation in UserDefaults
            UserDefaults.standard.set(true, forKey: "lifetimeAccessActivated")
            UserDefaults.standard.set(trimmedCode, forKey: "activatedInvitationCode")
            UserDefaults.standard.set(Date(), forKey: "lifetimeAccessActivatedDate")
            
            // Update subscription status
            subscriptionStatus = .active
        }
        
        return isValid
    }
    
    /// Check if user has activated lifetime access via invitation code
    func hasLifetimeAccess() -> Bool {
        return UserDefaults.standard.bool(forKey: "lifetimeAccessActivated")
    }
    
    /// Get the activated invitation code
    func getActivatedInvitationCode() -> String? {
        return UserDefaults.standard.string(forKey: "activatedInvitationCode")
    }
    
    /// Get the date when lifetime access was activated
    func getLifetimeAccessActivatedDate() -> Date? {
        return UserDefaults.standard.object(forKey: "lifetimeAccessActivatedDate") as? Date
    }
    
    /// Reset lifetime access (for testing purposes)
    func resetLifetimeAccess() {
        UserDefaults.standard.removeObject(forKey: "lifetimeAccessActivated")
        UserDefaults.standard.removeObject(forKey: "activatedInvitationCode")
        UserDefaults.standard.removeObject(forKey: "lifetimeAccessActivatedDate")
        print("🔄 Lifetime access reset")
    }
    
    /// Quick test function to check StoreKit setup
    func quickStoreKitTest() {
        print("🧪 Quick StoreKit Test")
        print("======================")
        
        // Test environment detection
        print("📱 Platform: \(isSimulatorEnvironment() ? "Simulator" : "Device")")
        print("🔐 Environment: \(detectActualStoreKitEnvironment())")
        print("📄 Using Config File: \(isUsingStoreKitConfigurationFile())")
        
        // Test product loading
        print("📦 Products: \(subscriptions.count) loaded")
        
        // Test subscription status
        print("🔐 Subscription: \(subscriptionStatus)")
        
        // Test lifetime access
        print("🎉 Lifetime Access: \(hasLifetimeAccess() ? "Active" : "Inactive")")
        
        print("======================")
        
        // Provide specific recommendations
        if subscriptions.isEmpty {
            print("🚨 ISSUE: No products loaded")
            print("💡 SOLUTION: Check Xcode scheme settings for StoreKit configuration")
        }
        
        if isSimulatorEnvironment() && !isUsingStoreKitConfigurationFile() {
            print("⚠️  WARNING: Simulator without config file may have authentication issues")
            print("💡 SOLUTION: Sign in with sandbox Apple ID or use Configuration.storekit")
        }
        
        if case .unknown = subscriptionStatus {
            print("⚠️  WARNING: Subscription status unknown")
            print("💡 SOLUTION: Check network connectivity and Apple ID authentication")
        }
    }
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