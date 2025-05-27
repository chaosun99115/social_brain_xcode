import SwiftUI
import StoreKit

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: SubscriptionError?
    @Published var showError = false
    
    private let subscriptionService = SubscriptionService.shared
    
    var subscriptions: [Product] {
        subscriptionService.subscriptions
    }
    
    var isSubscribed: Bool {
        subscriptionService.isSubscribed
    }
    
    var hasLifetimeSubscription: Bool {
        subscriptionService.hasLifetimeSubscription
    }
    
    var hasMonthlySubscription: Bool {
        subscriptionService.hasMonthlySubscription
    }
    
    var freeContactLimit: Int {
        subscriptionService.freeContactLimit
    }
    
    var freeAICreditLimit: Int {
        subscriptionService.freeAICreditLimit
    }
    
    func purchase(_ product: Product) async {
        isLoading = true
        error = nil
        
        do {
            try await subscriptionService.purchase(product)
        } catch let error as SubscriptionError {
            self.error = error
            showError = true
        } catch {
            self.error = .unknown
            showError = true
        }
        
        isLoading = false
    }
    
    func restorePurchases() async {
        isLoading = true
        error = nil
        
        do {
            try await AppStore.sync()
            await subscriptionService.updateSubscriptionStatus()
        } catch {
            self.error = .unknown
            showError = true
        }
        
        isLoading = false
    }
} 