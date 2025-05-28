import SwiftUI

struct SubscriptionStatusView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showingSubscriptionView = false
    
    var body: some View {
        Group {
            switch storeManager.subscriptionStatus {
            case .active:
                Label("Pro会员", systemImage: "star.fill")
                    .foregroundColor(.yellow)
            case .inactive:
                Button(action: { showingSubscriptionView = true }) {
                    Label("升级到Pro", systemImage: "star")
                        .foregroundColor(.primary)
                }
            case .unknown:
                ProgressView()
                    .onAppear {
                        Task {
                            await storeManager.updateSubscriptionStatus()
                        }
                    }
            }
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
    }
}

struct SubscriptionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SubscriptionStatusView()
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
    }
} 