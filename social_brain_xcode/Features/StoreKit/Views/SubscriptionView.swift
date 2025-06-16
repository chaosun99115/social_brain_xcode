import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var invitationCode = ""
    @State private var showingInvitationCodeModal = false
    @State private var showingInvitationCodeAlert = false
    @State private var invitationCodeAlertTitle = ""
    @State private var invitationCodeAlertMessage = ""
    @State private var isInvitationCodeSelected = true
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
                        FeatureRow(icon: "icloud", title: "iCloud同步", description: "保证隐私数据不会丢失")
                        FeatureRow(icon: "faceid", title: "Face ID解锁", description: "使用Face ID保护应用私密性")
                    }
                    .padding(.horizontal)
                    
                    // Subscription Options
                    VStack(spacing: 16) {
                        // Invitation Code Option
                        InvitationCodeOptionView(
                            isSelected: isInvitationCodeSelected,
                            invitationCode: $invitationCode,
                            onTap: {
                                // Deselect other options and select invitation code
                                selectedProduct = nil
                                isInvitationCodeSelected = true
                            }
                        )
                        
                        // Monthly Subscription
                        if let monthlyProduct = storeManager.subscriptions.first(where: { $0.id == "relate_monthly" }) {
                            SubscriptionOptionView(
                                product: monthlyProduct,
                                isSelected: selectedProduct?.id == monthlyProduct.id,
                                action: {
                                    // Deselect invitation code and select monthly
                                    isInvitationCodeSelected = false
                                    invitationCode = ""
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
                                    // Deselect invitation code and select lifetime
                                    isInvitationCodeSelected = false
                                    invitationCode = ""
                                    selectedProduct = lifetimeProduct
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Purchase Button
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
                    
                    // Restore Purchase
                    // Button("恢复购买") {
                    //     Task {
                    //         await restorePurchases()
                    //     }
                    // }
                    // .font(.subheadline)
                    
                    #if DEBUG
                    // Debug Button
                    Button("🔧 Debug StoreKit") {
                        storeManager.quickStoreKitTest()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    #endif
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
            .sheet(isPresented: $showingInvitationCodeModal) {
                InvitationCodeModalView(
                    invitationCode: $invitationCode,
                    onValidate: validateInvitationCode,
                    onDismiss: { showingInvitationCodeModal = false }
                )
            }
            .alert(invitationCodeAlertTitle, isPresented: $showingInvitationCodeAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(invitationCodeAlertMessage)
            }
            .alert("订阅成功", isPresented: $showingSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("现在可以使用所有高级功能")
            }
            .onChange(of: isInvitationCodeSelected) { newValue in
                // Remove automatic modal opening
                // if newValue && invitationCode.isEmpty {
                //     showingInvitationCodeModal = true
                // }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPurchaseButtonText() -> String {
        if isInvitationCodeSelected {
            return "输入邀请码"
        } else if selectedProduct != nil {
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
        return selectedProduct != nil || isInvitationCodeSelected
    }
    
    private func handlePurchaseAction() async {
        if isInvitationCodeSelected {
            showingInvitationCodeModal = true
        } else if let product = selectedProduct {
            await purchaseSelectedProduct(product)
        }
    }
    
    private func validateInvitationCode() {
        let trimmedCode = invitationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        showingInvitationCodeModal = false

        // Wait for the modal to be fully dismissed before showing the alert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if trimmedCode.isEmpty {
                showInvitationCodeAlert(
                    title: "邀请码错误",
                    message: "请输入邀请码"
                )
                return
            }
            if storeManager.validateInvitationCode(trimmedCode) {
                showInvitationCodeAlert(
                    title: "验证成功",
                    message: "邀请码验证成功！您已获得终生订阅。"
                )
                // Optionally auto-dismiss the subscription view after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    dismiss()
                }
            } else {
                showInvitationCodeAlert(
                    title: "邀请码无效",
                    message: "邀请码无效，请检查是否正确"
                )
            }
        }
    }
    
    private func showInvitationCodeAlert(title: String, message: String) {
        invitationCodeAlertTitle = title
        invitationCodeAlertMessage = message
        showingInvitationCodeAlert = true
    }
    
    private func purchaseSelectedProduct(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await storeManager.purchase(product)
            showingSuccessAlert = true
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

struct InvitationCodeOptionView: View {
    let isSelected: Bool
    @Binding var invitationCode: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("输入邀请码")
                        .font(.headline)
                }
                
                Spacer()
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

struct InvitationCodeModalView: View {
    @Binding var invitationCode: String
    let onValidate: () -> Void
    let onDismiss: () -> Void
    @State private var localInvitationCode = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("输入邀请码")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("请输入您的邀请码以获得终生订阅")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Input Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("邀请码")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("请输入邀请码", text: $localInvitationCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.subheadline)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .focused($isTextFieldFocused)
                        .onAppear {
                            // Reset local state when modal appears
                            localInvitationCode = ""
                            isTextFieldFocused = true
                        }
                        .onSubmit {
                            // Allow submission with Enter key
                            if !localInvitationCode.isEmpty {
                                invitationCode = localInvitationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                                onValidate()
                            }
                        }
                }
                .padding(.horizontal)
                
                // Validate Button
                Button(action: {
                    // Update the binding with the local value
                    invitationCode = localInvitationCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    onValidate()
                }) {
                    Text("验证邀请码")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(localInvitationCode.isEmpty ? Color.gray : Color.primaryAction)
                        .cornerRadius(12)
                }
                .disabled(localInvitationCode.isEmpty)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct InvitationCodeErrorModalView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("邀请码无效")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("请检查邀请码是否正确，或联系客服获取有效的邀请码")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Dismiss Button
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
                .padding(.bottom, 20)
            }
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
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
} 