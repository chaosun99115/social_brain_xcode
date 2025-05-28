import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .unknown
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
        } catch {
            self.error = .loadFailed(error)
            print("Failed to load products: \(error)")
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
            throw error
        }
    }
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        do {
            for await result in StoreKit.Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else {
                    continue
                }
                
                if transaction.productType == .autoRenewable {
                    hasActiveSubscription = true
                    break
                }
            }
            
            subscriptionStatus = hasActiveSubscription ? .active : .inactive
        } catch {
            self.error = .statusCheckFailed(error)
            print("Failed to update subscription status: \(error)")
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