import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var viewModel = SubscriptionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    
                    if viewModel.isSubscribed {
                        subscribedView
                    } else {
                        subscriptionOptionsView
                    }
                    
                    if !viewModel.isSubscribed {
                        freeTierView
                    }
                }
                .padding()
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if !viewModel.isSubscribed {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Restore") {
                            Task {
                                await viewModel.restorePurchases()
                            }
                        }
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError, presenting: viewModel.error) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Upgrade to Social Brain Pro")
                .font(.title2)
                .bold()
            
            Text("Unlock unlimited contacts and AI credits to nurture your relationships")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
    
    private var subscribedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("You're a Pro!")
                .font(.title2)
                .bold()
            
            if viewModel.hasLifetimeSubscription {
                Text("You have lifetime access to all features")
                    .foregroundColor(.secondary)
            } else {
                Text("Your subscription is active")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var subscriptionOptionsView: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.subscriptions, id: \.id) { product in
                SubscriptionOptionView(product: product) {
                    Task {
                        await viewModel.purchase(product)
                    }
                }
            }
        }
    }
    
    private var freeTierView: some View {
        VStack(spacing: 16) {
            Text("Free Tier")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "person.2.fill",
                    title: "Contacts",
                    description: "Up to \(viewModel.freeContactLimit) contacts"
                )
                
                FeatureRow(
                    icon: "brain.head.profile",
                    title: "AI Credits",
                    description: "\(viewModel.freeAICreditLimit) credits per month"
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
}

struct SubscriptionOptionView: View {
    let product: Product
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.headline)
                        
                        if product.id.contains("lifetime") {
                            Text("One-time purchase")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Monthly subscription")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Text(product.displayPrice)
                        .font(.title3)
                        .bold()
                }
                
                if product.id.contains("lifetime") {
                    Text("Best value")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SubscriptionView()
} 