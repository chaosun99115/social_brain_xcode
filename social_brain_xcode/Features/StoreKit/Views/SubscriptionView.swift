import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("升级到Pro")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("解锁所有高级功能")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 20) {
                        SubscriptionFeatureRow(icon: "faceid", title: "Face ID解锁", description: "使用Face ID保护应用私密性")
                    }
                    .padding(.horizontal)
                    
                    // Subscription Options
                    if !storeManager.subscriptions.isEmpty {
                        // Show available subscription options
                        VStack(spacing: 16) {
                            // Monthly Subscription
                            if let monthlyProduct = storeManager.subscriptions.first(where: { $0.id == "relate_monthly" }) {
                                SubscriptionOptionView(
                                    product: monthlyProduct,
                                    isSelected: selectedProduct?.id == monthlyProduct.id,
                                    action: {
                                        selectedProduct = monthlyProduct
                                    }
                                )
                            }
                            
                            // Lifetime Subscription
                            if let lifetimeProduct = storeManager.subscriptions.first(where: { $0.id == "relate_lifetime_premium" }) {
                                SubscriptionOptionView(
                                    product: lifetimeProduct,
                                    isSelected: selectedProduct?.id == lifetimeProduct.id,
                                    action: {
                                        selectedProduct = lifetimeProduct
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    } else if storeManager.isLoading {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("正在加载订阅选项...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    } else if !storeManager.isInitialized {
                        // Not initialized state
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text("需要网络连接")
                                .font(.headline)
                            Text("请检查网络连接后重试")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("重试") {
                                Task {
                                    await storeManager.retryInitialization()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Purchase Button
                    if !storeManager.subscriptions.isEmpty {
                        Button(action: {
                            Task {
                                await handlePurchaseAction()
                            }
                        }) {
                            if isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(getPurchaseButtonText())
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(getPurchaseButtonColor())
                        .cornerRadius(12)
                        .disabled(!canPurchase())
                        .padding(.horizontal)
                    }
                    
                    // Restore Purchase
                    Button("恢复购买") {
                        Task {
                            await restorePurchases()
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Initialize StoreKit when view appears
                Task {
                    await storeManager.initialize()
                }
            }
            .alert("订阅错误", isPresented: $showingError, presenting: errorMessage) { _ in
                Button("确定", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .alert("订阅成功", isPresented: $showingSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("现在可以使用所有高级功能")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPurchaseButtonText() -> String {
        if selectedProduct != nil {
            return "立即订阅"
        } else {
            return "选择订阅计划"
        }
    }
    
    private func getPurchaseButtonColor() -> Color {
        if canPurchase() {
            return Color.primaryAction
        } else {
            return Color.gray
        }
    }
    
    private func canPurchase() -> Bool {
        return selectedProduct != nil
    }
    
    private func handlePurchaseAction() async {
        if let product = selectedProduct {
            await purchaseSelectedProduct(product)
        }
    }
    
    private func purchaseSelectedProduct(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await storeManager.purchase(product)
            showingSuccessAlert = true
        } catch {
            if let storeKitError = error as? StoreKitError, case .networkUnavailable = storeKitError {
                errorMessage = "网络连接不可用，请检查网络设置后重试"
            } else {
                errorMessage = error.localizedDescription
            }
            showingError = true
        }
    }
    
    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await storeManager.restorePurchases()
            if storeManager.subscriptionStatus == .active {
                dismiss()
            }
        } catch {
            if let storeKitError = error as? StoreKitError, case .networkUnavailable = storeKitError {
                errorMessage = "网络连接不可用，请检查网络设置后重试"
            } else {
                errorMessage = error.localizedDescription
            }
            showingError = true
        }
    }
}

struct SubscriptionFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct SubscriptionOptionView: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if product.type == .autoRenewable {
                        Text("每月")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("一次性")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.primaryAction.opacity(0.1) : Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primaryAction : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
} 