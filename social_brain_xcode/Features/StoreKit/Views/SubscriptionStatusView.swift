import SwiftUI
import StoreKit

struct SubscriptionStatusView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Icon
                if !storeManager.isInitialized {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: storeManager.subscriptionStatus == .active ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(storeManager.subscriptionStatus == .active ? .green : .red)
                }
                
                // Status Text
                Text(getStatusTitle())
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(getStatusDescription())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Initialize button if not initialized
                if !storeManager.isInitialized {
                    Button("初始化订阅状态") {
                        Task {
                            await storeManager.retryInitialization()
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                }
                
                Spacer()
                
                // Action Button
                Button(action: {
                    dismiss()
                }) {
                    Text("确定")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primaryAction)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("订阅状态")
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
        }
    }
    
    private func getStatusTitle() -> String {
        if !storeManager.isInitialized {
            return "未初始化"
        }
        
        switch storeManager.subscriptionStatus {
        case .active:
            return "订阅已激活"
        case .inactive:
            return "订阅未激活"
        case .unknown:
            return "状态未知"
        }
    }
    
    private func getStatusDescription() -> String {
        if !storeManager.isInitialized {
            return "订阅状态尚未初始化。请点击下方按钮初始化或检查网络连接。"
        }
        
        switch storeManager.subscriptionStatus {
        case .active:
            return "您的订阅已激活，可以享受所有高级功能。"
        case .inactive:
            return "您当前没有活跃的订阅。请升级到Pro版本以解锁所有功能。"
        case .unknown:
            return "无法确定订阅状态，请检查网络连接后重试。"
        }
    }
}

struct SubscriptionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionStatusView()
    }
} 