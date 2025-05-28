import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
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
                        FeatureRow(icon: "infinity", title: "无限笔记", description: "记录所有重要的社交互动")
                        FeatureRow(icon: "icloud", title: "iCloud同步", description: "在所有设备上同步您的数据")
                        FeatureRow(icon: "chart.bar.fill", title: "高级分析", description: "深入了解您的社交关系")
                        FeatureRow(icon: "lock.shield.fill", title: "隐私保护", description: "使用Face ID保护您的数据")
                    }
                    .padding(.horizontal)
                    
                    // Subscription Options
                    VStack(spacing: 16) {
                        ForEach(storeManager.subscriptions, id: \.id) { product in
                            SubscriptionOptionView(
                                product: product,
                                isSelected: selectedProduct?.id == product.id,
                                action: { selectedProduct = product }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Purchase Button
                    Button(action: {
                        Task {
                            await purchaseSelectedProduct()
                        }
                    }) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(selectedProduct == nil ? "选择订阅计划" : "立即订阅")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedProduct == nil ? Color.gray : Color.primaryAction)
                    .cornerRadius(12)
                    .disabled(selectedProduct == nil || isPurchasing)
                    .padding(.horizontal)
                    
                    // Restore Purchase
                    Button("恢复购买") {
                        Task {
                            await restorePurchases()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    // Terms and Privacy
                    VStack(spacing: 8) {
                        Text("订阅将自动续期，可随时取消")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Link("使用条款", destination: URL(string: "https://socialbrain.app/terms")!)
                            Text("·")
                            Link("隐私政策", destination: URL(string: "https://socialbrain.app/privacy")!)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.top)
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
            .alert("订阅错误", isPresented: $showingError, presenting: errorMessage) { _ in
                Button("确定", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }
    
    private func purchaseSelectedProduct() async {
        guard let product = selectedProduct else { return }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await storeManager.purchase(product)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
            showingError = true
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
                    Text(product.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(.headline)
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