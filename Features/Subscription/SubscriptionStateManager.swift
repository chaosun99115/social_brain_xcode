import SwiftUI
import StoreKit

@MainActor
class SubscriptionStateManager: ObservableObject {
    static let shared = SubscriptionStateManager()
    
    private let subscriptionService = SubscriptionService.shared
    @Published private(set) var isSubscribed = false
    @Published private(set) var hasLifetimeSubscription = false
    
    private init() {
        Task {
            await updateSubscriptionState()
        }
    }
    
    func updateSubscriptionState() async {
        isSubscribed = subscriptionService.isSubscribed
        hasLifetimeSubscription = subscriptionService.hasLifetimeSubscription
    }
    
    var canAddMoreContacts: Bool {
        isSubscribed || true // TODO: Implement contact count check
    }
    
    var canUseAICredits: Bool {
        isSubscribed || true // TODO: Implement AI credit check
    }
    
    var remainingAICredits: Int {
        if isSubscribed {
            return Int.max
        }
        return subscriptionService.freeAICreditLimit // TODO: Implement credit tracking
    }
    
    var remainingContacts: Int {
        if isSubscribed {
            return Int.max
        }
        return subscriptionService.freeContactLimit // TODO: Implement contact count tracking
    }
    
    func showSubscriptionRequiredAlert() -> Alert {
        Alert(
            title: Text("Subscription Required"),
            message: Text("Please upgrade to Social Brain Pro to access this feature."),
            primaryButton: .default(Text("View Plans")) {
                NotificationCenter.default.post(name: .showSubscription, object: nil)
            },
            secondaryButton: .cancel()
        )
    }
}

extension Notification.Name {
    static let showSubscription = Notification.Name("showSubscription")
}

// View modifier to handle subscription state
struct SubscriptionRequiredModifier: ViewModifier {
    @StateObject private var subscriptionManager = SubscriptionStateManager.shared
    @State private var showSubscriptionAlert = false
    
    let isRequired: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isRequired) { newValue in
                if newValue && !subscriptionManager.isSubscribed {
                    showSubscriptionAlert = true
                }
            }
            .alert(isPresented: $showSubscriptionAlert) {
                subscriptionManager.showSubscriptionRequiredAlert()
            }
    }
}

extension View {
    func requiresSubscription(_ isRequired: Bool = true) -> some View {
        modifier(SubscriptionRequiredModifier(isRequired: isRequired))
    }
} 