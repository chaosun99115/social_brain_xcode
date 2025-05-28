import SwiftUI
import LocalAuthentication

struct ConfigurationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appModeManager: AppModeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @StateObject private var storeManager = StoreKitManager.shared
    
    // Configuration options
    @State private var isICloudSyncEnabled = false
    @State private var showingSampleDataDialog = false
    @State private var showingProUpgrade = false
    @State private var showingFaceIDError = false
    @State private var faceIDError: String?
    @State private var isAuthenticating = false
    
    var body: some View {
        NavigationView {
            List {
                // Sample Data Section
                Section {
                    Button(action: {
                        showingSampleDataDialog = true
                    }) {
                        HStack {
                            Label("查看示例数据", systemImage: "person.3.sequence.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // Pro Features Section
                Section {
                    Button(action: {
                        showingProUpgrade = true
                    }) {
                        HStack {
                            Label("解锁Pro", systemImage: "star.fill")
                                .foregroundColor(.yellow)
                            Spacer()
                            if storeManager.subscriptionStatus == .active {
                                Text("已订阅")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // Data Section
                Section(header: Text("数据")) {
                    Toggle("iCloud同步", isOn: $isICloudSyncEnabled)
                        .onChange(of: isICloudSyncEnabled) { newValue in
                            // TODO: Implement iCloud sync toggle
                        }
                }
                
                // Security Section
                Section(header: Text("安全")) {
                    Toggle("Face ID锁定", isOn: Binding(
                        get: { appSettingsManager.isFaceIDEnabled },
                        set: { newValue in
                            if newValue {
                                authenticateWithFaceID()
                            } else {
                                appSettingsManager.setFaceIDEnabled(false)
                            }
                        }
                    ))
                    .disabled(isAuthenticating)
                }
                
                // About Section
                Section(header: Text("关于")) {
                    NavigationLink(destination: AboutView()) {
                        Label("关于社交大脑", systemImage: "info.circle")
                    }
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("隐私政策", systemImage: "hand.raised")
                    }
                    
                    NavigationLink(destination: TermsOfServiceView()) {
                        Label("使用条款", systemImage: "doc.text")
                    }
                }
                
                // Version Section
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                SampleModeConfig.selectionDialogMessage,
                isPresented: $showingSampleDataDialog,
                titleVisibility: .visible
            ) {
                ForEach(SampleModeConfig.availableModes, id: \.id) { mode in
                    Button(mode.title) {
                        Task {
                            await handleSampleModeSelection(mode)
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showingProUpgrade) {
                SubscriptionView()
            }
            .alert("Face ID错误", isPresented: $showingFaceIDError) {
                Button("确定", role: .cancel) {
                    appSettingsManager.setFaceIDEnabled(false)
                }
            } message: {
                Text(faceIDError ?? "无法启用Face ID")
            }
        }
    }
    
    private func authenticateWithFaceID() {
        isAuthenticating = true
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                 localizedReason: "验证以启用Face ID锁定") { success, error in
                DispatchQueue.main.async {
                    isAuthenticating = false
                    if success {
                        appSettingsManager.setFaceIDEnabled(true)
                    } else {
                        faceIDError = error?.localizedDescription
                        showingFaceIDError = true
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                isAuthenticating = false
                faceIDError = error?.localizedDescription
                showingFaceIDError = true
            }
        }
    }
    
    private func handleSampleModeSelection(_ mode: SampleModeConfig.ModeDefinition) async {
        // TODO: Implement sample mode selection
        // This should be similar to the implementation in SocialContactView
    }
}

// Pro Upgrade View
struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                    
                    // Price
                    VStack(spacing: 8) {
                        Text("¥68")
                            .font(.system(size: 48, weight: .bold))
                        
                        Text("一次性购买，终身使用")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                    
                    // Purchase Button
                    Button(action: {
                        // TODO: Implement purchase
                    }) {
                        Text("立即升级")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.primaryAction)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Restore Purchase
                    Button("恢复购买") {
                        // TODO: Implement restore purchase
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
        }
    }
}

// Placeholder views for navigation destinations
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("关于社交大脑")
                    .font(.title)
                    .padding(.bottom)
                
                Text("社交大脑是一款帮助用户提升社交互动质量、培养长期人际关系的个人关系管理应用。")
                    .padding(.bottom)
                
                Text("版本 1.0.0")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("隐私政策")
                    .font(.title)
                    .padding(.bottom)
                
                Text("我们重视您的隐私。本应用收集的所有数据都存储在您的设备上，我们不会未经您的同意分享任何个人信息。")
                    .padding(.bottom)
                
                Text("数据安全")
                    .font(.headline)
                Text("所有数据都经过加密存储，确保您的信息安全。")
            }
            .padding()
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("使用条款")
                    .font(.title)
                    .padding(.bottom)
                
                Text("使用本应用即表示您同意遵守以下条款：")
                    .padding(.bottom)
                
                Text("1. 您同意负责任地使用本应用")
                Text("2. 您同意不会滥用本应用的功能")
                Text("3. 您同意遵守所有适用的法律法规")
            }
            .padding()
        }
        .navigationTitle("使用条款")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Replace the #Preview macro with PreviewProvider
struct ConfigurationSheetView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationSheetView()
            .environmentObject(AppModeManager())
            .environment(\.colorScheme, .light)
        
        ConfigurationSheetView()
            .environmentObject(AppModeManager())
            .environment(\.colorScheme, .dark)
    }
}

// Add preview for ProUpgradeView
struct ProUpgradeView_Previews: PreviewProvider {
    static var previews: some View {
        ProUpgradeView()
            .environment(\.colorScheme, .light)
        
        ProUpgradeView()
            .environment(\.colorScheme, .dark)
    }
} 