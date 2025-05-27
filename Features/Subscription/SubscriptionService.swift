import StoreKit
import SwiftUI

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    // Product IDs
    private let monthlySubscriptionID = "com.socialbrain.subscription.monthly"
    private let lifetimeSubscriptionID = "com.socialbrain.subscription.lifetime"
    
    // Free tier limits
    let freeContactLimit = 20
    let freeAICreditLimit = 1000
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionGroupStatus: RenewalState?
    
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
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
            for await result in Transaction.updates {
                await self.handleTransactionResult(result)
            }
        }
    }
    
    private func handleTransactionResult(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            return
        }
        
        await transaction.finish()
        await self.updateSubscriptionStatus()
    }
    
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [monthlySubscriptionID, lifetimeSubscriptionID])
            subscriptions = products.sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products:", error)
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw SubscriptionError.verificationFailed
            }
            await transaction.finish()
            await updateSubscriptionStatus()
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }
    
    func updateSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                purchasedSubscriptions.append(subscription)
            }
        }
    }
    
    var isSubscribed: Bool {
        !purchasedSubscriptions.isEmpty
    }
    
    var hasLifetimeSubscription: Bool {
        purchasedSubscriptions.contains { $0.id == lifetimeSubscriptionID }
    }
    
    var hasMonthlySubscription: Bool {
        purchasedSubscriptions.contains { $0.id == monthlySubscriptionID }
    }
}

enum SubscriptionError: LocalizedError {
    case verificationFailed
    case userCancelled
    case pending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Subscription verification failed"
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending"
        case .unknown:
            return "An unknown error occurred"
        }
    }
} 