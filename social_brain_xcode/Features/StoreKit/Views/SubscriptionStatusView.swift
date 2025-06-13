import SwiftUI
import StoreKit

struct SubscriptionStatusView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Icon
                Image(systemName: storeManager.subscriptionStatus == .active ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(storeManager.subscriptionStatus == .active ? .green : .red)
                
                // Status Text
                Text(getStatusTitle())
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(getStatusDescription())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Additional Info
                if storeManager.hasLifetimeAccess() {
                    VStack(spacing: 8) {
                        Text("激活码: \(storeManager.getActivatedInvitationCode() ?? "未知")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let date = storeManager.getLifetimeAccessActivatedDate() {
                            Text("激活时间: \(formattedDate(date))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
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
        }
    }
    
    private func getStatusTitle() -> String {
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
        switch storeManager.subscriptionStatus {
        case .active:
            if storeManager.hasLifetimeAccess() {
                return "您已通过邀请码获得终生订阅，可以享受所有高级功能。"
            } else {
                return "您的订阅已激活，可以享受所有高级功能。"
            }
        case .inactive:
            return "您当前没有活跃的订阅。请升级到Pro版本以解锁所有功能。"
        case .unknown:
            return "无法确定订阅状态，请检查网络连接后重试。"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

struct SubscriptionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionStatusView()
    }
} 