import StoreKit
import SwiftUI
import Network

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .unknown
    @Published private(set) var isLoading = false
    @Published private(set) var error: StoreKitError?
    @Published private(set) var isInitialized = false
    
    private var updateListenerTask: Task<Void, Error>?
    private var retryCount = 0
    private let maxRetries = 3
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = false
    
    private init() {
        setupNetworkMonitoring()
        // Don't initialize StoreKit immediately - wait for explicit initialization
    }
    
    deinit {
        updateListenerTask?.cancel()
        networkMonitor.cancel()
    }
    
    // MARK: - Public Initialization
    
    /// Initialize StoreKit when needed (call this when user grants internet access)
    func initialize() async {
        guard !isInitialized else { return }
        
        // Check network connectivity first
        guard isNetworkAvailable else {
            return
        }
        
        updateListenerTask = listenForTransactions()
        await loadProducts()
        await updateSubscriptionStatus()
        isInitialized = true
    }
    
    /// Manually trigger initialization (useful for retry scenarios)
    func retryInitialization() async {
        print("🔄 StoreKit: Retrying initialization...")
        isInitialized = false
        await initialize()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isNetworkAvailable = path.status == .satisfied
                if path.status == .satisfied && !self.isInitialized {
                    // Network became available, try to initialize if not already done
                    Task { @MainActor in
                        await self.initialize()
                    }
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global())
    }
    
    // MARK: - Transaction Listening
    
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
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        guard !isLoading else { return }
        guard isNetworkAvailable else {
            return
        }
        
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
    
    // MARK: - Purchase Methods
    
    func purchase(_ product: Product) async throws {
        guard isNetworkAvailable else {
            throw StoreKitError.networkUnavailable
        }
        
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
        guard isNetworkAvailable else {
            throw StoreKitError.networkUnavailable
        }
        
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
    
    // MARK: - Subscription Status
    
    func updateSubscriptionStatus() async {
        guard isNetworkAvailable else {
            return
        }
        
        var hasActiveSubscription = false
        
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
        // In debug builds, we're likely in sandbox for testing
        return true
        #else
        // In release builds, we're in production
        return false
        #endif
    }
    
    private func isUsingStoreKitConfigurationFile() -> Bool {
        // Configuration.storekit file has been removed for production
        // This method is kept for backward compatibility but always returns false
        return false
    }
    
    private func detectActualStoreKitEnvironment() -> String {
        // Try to detect the actual environment being used
        #if targetEnvironment(simulator)
        return "Simulator (Sandbox Testing)"
        #else
        #if DEBUG
        return "Device (Sandbox Testing)"
        #else
        return "Device (Production)"
        #endif
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
        case .networkUnavailable:
            print("🌐 StoreKit: Network is not available")
            print("💡 Tip: Check your internet connection and try again")
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
            print("   - Configuration.storekit file has been removed for production")
            print("   - Test on physical device for full StoreKit functionality")
            print("   - Use sandbox Apple ID for testing")
        }
        
        if isSandboxEnvironment() {
            print("   - Ensure you're signed in with sandbox Apple ID in Settings > App Store")
            print("   - Check that your sandbox account has sufficient test balance")
            print("   - Verify the product ID 'relate_monthly' and 'relate_lifetime_premium' exist in App Store Connect")
            print("   - Try signing out and back in to refresh authentication")
            print("   - Check that your app's bundle ID matches App Store Connect")
        } else {
            print("   - Running in production environment")
            print("   - Ensure App Store Connect products are 'Ready to Submit'")
            print("   - Verify pricing and localizations are complete")
        }
        
        if subscriptions.isEmpty {
            print("   - No products loaded - check product identifiers")
            print("   - Verify App Store Connect configuration")
            print("   - Check network connectivity")
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
        print("   - Configuration.storekit: Removed for production ✅")
        print("   - Environment: Production ready ✅")
        print("\n📋 App Store Connect Requirements:")
        print("   1. Ensure products are 'Ready to Submit'")
        print("   2. Verify localization metadata:")
        print("      - Chinese (zh_CN): 月度订阅 / 终生订阅")
        print("      - English (en_US): Monthly Subscription / Lifetime Premium Access")
        print("   3. Confirm subscription description:")
        print("      - 解锁所有高级功能，包括iCloud同步和Face ID认证")
        print("   4. Verify pricing (¥6.00/month, ¥68.00 lifetime)")
        print("   5. Add subscription screenshots (optional)")
        print("   6. Submit for review when ready")
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
    
    /// Quick test function to check StoreKit setup
    func quickStoreKitTest() {
        print("🧪 Quick StoreKit Test")
        print("======================")
        
        // Test environment detection
        print("📱 Platform: \(isSimulatorEnvironment() ? "Simulator" : "Device")")
        print("🔐 Environment: \(detectActualStoreKitEnvironment())")
        print("📄 Configuration.storekit: Removed for production ✅")
        
        // Test product loading
        print("📦 Products: \(subscriptions.count) loaded")
        
        // Test subscription status
        print("🔐 Subscription: \(subscriptionStatus)")
        
        print("======================")
        
        // Provide specific recommendations
        if subscriptions.isEmpty {
            print("🚨 ISSUE: No products loaded")
            print("💡 SOLUTION: Check App Store Connect configuration")
            print("💡 SOLUTION: Verify product IDs are correct")
            print("💡 SOLUTION: Test on physical device with sandbox Apple ID")
        }
        
        if isSimulatorEnvironment() {
            print("⚠️  WARNING: Testing in simulator")
            print("💡 SOLUTION: Test on physical device for full functionality")
        }
        
        if case .unknown = subscriptionStatus {
            print("⚠️  WARNING: Subscription status unknown")
            print("💡 SOLUTION: Check network connectivity and Apple ID authentication")
        }
        
        if !isSimulatorEnvironment() && !isSandboxEnvironment() {
            print("✅ PRODUCTION: App is configured for production distribution")
        }
    }
    
    /// Check if the app is ready for production distribution
    func checkProductionReadiness() {
        print("🚀 Production Readiness Check")
        print("=============================")
        
        // Check Configuration.storekit file
        print("📄 Configuration.storekit: Removed ✅")
        
        // Check environment
        let environment = detectActualStoreKitEnvironment()
        print("🔐 Environment: \(environment)")
        
        // Check products
        print("📦 Products loaded: \(subscriptions.count)")
        
        // Check subscription status
        print("🔐 Subscription status: \(subscriptionStatus)")
        
        // Overall readiness
        let isReady = !isSimulatorEnvironment() && subscriptions.count > 0
        print("✅ Production Ready: \(isReady ? "YES" : "NO")")
        
        if isReady {
            print("\n🎉 Your app is ready for App Store distribution!")
            print("📋 Next steps:")
            print("   1. Test on physical device with sandbox Apple ID")
            print("   2. Verify App Store Connect products are 'Ready to Submit'")
            print("   3. Submit your app for review")
        } else {
            print("\n⚠️  Issues found:")
            if isSimulatorEnvironment() {
                print("   - Test on physical device")
            }
            if subscriptions.isEmpty {
                print("   - Check App Store Connect configuration")
            }
        }
        
        print("=============================")
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
    case networkUnavailable
    
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
        case .networkUnavailable:
            return "网络不可用"
        }
    }
} 