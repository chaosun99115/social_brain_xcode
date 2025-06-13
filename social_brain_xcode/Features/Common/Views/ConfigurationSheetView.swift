import SwiftUI
import LocalAuthentication
import CloudKit
import CoreData

// MARK: - iCloud Sync Implementation Notes
/*
 Current iCloud Sync Implementation (Temporarily Disabled):
 
 1. Architecture:
    - Uses CloudKit for data synchronization
    - Managed by PersistenceController
    - Supports bidirectional sync of CoreData entities
 
 2. Key Components:
    - CloudKit container configuration
    - Account status verification
    - Sync status tracking
    - Error handling and recovery
 
 3. Sync Process:
    a. Account Verification
       - Checks iCloud account status
       - Handles various states: available, noAccount, restricted
       - Provides user feedback for account issues
    
    b. Sync Operations
       - Enables/disables CloudKit sync
       - Manages sync status (notStarted, inProgress, completed, failed)
       - Handles conflict resolution
       - Tracks last sync time
    
    c. Error Handling
       - Network connectivity issues
       - Account access problems
       - Sync conflicts
       - Provides recovery suggestions
 
 4. Future Development Tasks:
    - Implement proper conflict resolution
    - Add sync progress indicators
    - Improve error recovery mechanisms
    - Add sync status persistence
    - Implement background sync
    - Add sync retry mechanisms
    - Implement proper data migration
*/

struct ConfigurationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appModeManager: AppModeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var featureFlagManager: FeatureFlagManager
    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var persistenceController = PersistenceController.shared
    
    // Configuration options
    @State private var isICloudSyncEnabled = false
    @State private var showingSampleDataDialog = false
    @State private var showingProUpgrade = false
    @State private var showingFaceIDError = false
    @State private var faceIDError: String?
    @State private var isAuthenticating = false
    @State private var showingSyncError = false
    @State private var syncError: Error?
    @State private var isCheckingICloud = false
    @State private var iCloudAccountStatus: CKAccountStatus = .couldNotDetermine
    
    // Add state to track pending actions
    @State private var pendingICloudSyncAction: Bool?
    @State private var pendingFaceIDAction: Bool?
    
    // Add state for subscription management
    @State private var showingSubscriptionView = false
    @State private var showingRestoreAlert = false
    @State private var restoreResult: String?
    @State private var showingSubscriptionError = false
    @State private var subscriptionErrorMessage: String?
    
    private var isProUser: Bool {
        featureFlagManager.canUseProFeatures
    }
    
    // Add init to configure navigation bar appearance
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(.systemGray6))
        appearance.shadowColor = .clear // Remove the divider line
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Check and re-ingest prompts if needed
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        do {
            let count = try context.count(for: fetchRequest)
            if count == 0 {
                // Only re-ingest if there are no prompts at all
                PromptService.shared.ingestDefaultPrompts(in: context)
            }
        } catch {
            print("Error checking prompt count: \(error)")
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Sample Data Section
                Section {
                    Button(action: {
                        showingSampleDataDialog = true
                    }) {
                        HStack {
                            Text("查看示例数据")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(.primary)
                    
                    // Social Knowledge Base
                    NavigationLink(destination: getPromptListViewMode()) {
                        HStack {
                            Text("人际经验库")
                            Spacer()
                        }
                    }
                }
                
                // Subscription Section
                Section(header: Text("订阅状态")) {
                    // Current subscription status
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前状态")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Image(systemName: subscriptionStatusIcon)
                                    .foregroundColor(subscriptionStatusColor)
                                Text(subscriptionStatusText)
                                    .font(.headline)
                                    .foregroundColor(subscriptionStatusColor)
                            }
                        }
                        
                        Spacer()
                        
                        if storeManager.subscriptionStatus == .inactive {
                            Button("升级") {
                                showingSubscriptionView = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primaryAction)
                            .cornerRadius(8)
                        }
                    }
                    
                    // Restore purchases button
                    if storeManager.subscriptionStatus == .inactive {
                        Button("恢复购买") {
                            Task {
                                await restorePurchases()
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Advanced Features Section
                Section(header: Text("Pro功能")) {
                    // iCloud Sync Option
                    ICloudSyncView()

                    // Face ID Toggle
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
                
                // Developer Section (only show in debug builds)
                #if DEBUG
                Section(header: Text("开发者选项")) {
                    Toggle("启用订阅要求", isOn: Binding(
                        get: { featureFlagManager.requireSubscriptionForProFeatures },
                        set: { newValue in
                            featureFlagManager.setRequireSubscriptionForProFeatures(newValue)
                        }
                    ))
                    .onChange(of: featureFlagManager.requireSubscriptionForProFeatures) { newValue in
                        print("Subscription requirement changed to: \(newValue)")
                    }
                    
                    HStack {
                        Text("当前Pro状态")
                        Spacer()
                        Text(isProUser ? "已激活" : "未激活")
                            .foregroundColor(isProUser ? .green : .red)
                    }
                    
                    // Subscription testing buttons
                    VStack(spacing: 8) {
                        Button("重置订阅状态为未激活") {
                            storeManager.resetSubscriptionStatus()
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        
                        Button("设置订阅状态为已激活") {
                            storeManager.setSubscriptionActive()
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                        
                        Button("重置为首启动状态") {
                            featureFlagManager.resetToFirstLaunch()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        
                        Button("诊断StoreKit问题") {
                            storeManager.diagnoseStoreKitIssues()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
                #endif
                
                // About Section
                Section(header: Text("关于")) {
                    NavigationLink(destination: AboutView()) {
                        Text("关于社交大脑")
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
                    .foregroundColor(.green)
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
            .sheet(isPresented: $showingSubscriptionView) {
                SubscriptionView()
                    .onDisappear {
                        // Handle pending actions after subscription view is dismissed
                        if let pendingSync = pendingICloudSyncAction {
                            if isProUser {
                                handleICloudSyncToggle(pendingSync)
                            }
                            pendingICloudSyncAction = nil
                        }
                        
                        if let pendingFaceID = pendingFaceIDAction {
                            if isProUser {
                                if pendingFaceID {
                                    authenticateWithFaceID()
                                } else {
                                    appSettingsManager.setFaceIDEnabled(false)
                                }
                            }
                            pendingFaceIDAction = nil
                        }
                    }
            }
            .sheet(isPresented: $showingProUpgrade) {
                SubscriptionView()
                    .onDisappear {
                        // Handle pending actions after subscription view is dismissed
                        if let pendingSync = pendingICloudSyncAction {
                            if isProUser {
                                handleICloudSyncToggle(pendingSync)
                            }
                            pendingICloudSyncAction = nil
                        }
                        
                        if let pendingFaceID = pendingFaceIDAction {
                            if isProUser {
                                if pendingFaceID {
                                    authenticateWithFaceID()
                                } else {
                                    appSettingsManager.setFaceIDEnabled(false)
                                }
                            }
                            pendingFaceIDAction = nil
                        }
                    }
            }
            .alert("Face ID错误", isPresented: $showingFaceIDError) {
                Button("确定", role: .cancel) {
                    appSettingsManager.setFaceIDEnabled(false)
                }
            } message: {
                Text(faceIDError ?? "无法启用Face ID")
            }
            .alert("恢复购买结果", isPresented: $showingRestoreAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(restoreResult ?? "恢复购买完成")
            }
            .alert("订阅错误", isPresented: $showingSubscriptionError) {
                Button("确定", role: .cancel) { }
                Button("重试") {
                    Task {
                        await restorePurchases()
                    }
                }
            } message: {
                Text(subscriptionErrorMessage ?? "发生未知错误")
            }
            .alert("同步错误", isPresented: $showingSyncError) {
                Button("确定", role: .cancel) { }
                if let error = syncError as NSError?,
                   let recoverySuggestion = error.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String {
                    Button("查看帮助") {
                        // Show a sheet with detailed instructions
                        // TODO: Implement a help sheet with formatted instructions
                    }
                }
            } message: {
                if let error = syncError as NSError? {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.localizedDescription)
                            .font(.headline)
                        if let recoverySuggestion = error.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String {
                            Text(recoverySuggestion)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Ensure new users start with inactive subscription status
            Task {
                await storeManager.updateSubscriptionStatus()
            }
        }
    }
    
    // MARK: - Computed Properties for Subscription Status
    
    private var subscriptionStatusIcon: String {
        switch storeManager.subscriptionStatus {
        case .active:
            return "star.fill"
        case .inactive:
            return "star"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var subscriptionStatusColor: Color {
        switch storeManager.subscriptionStatus {
        case .active:
            return .yellow
        case .inactive:
            return .gray
        case .unknown:
            return .orange
        }
    }
    
    private var subscriptionStatusText: String {
        switch storeManager.subscriptionStatus {
        case .active:
            return "Pro会员"
        case .inactive:
            return "免费用户"
        case .unknown:
            return "检查中..."
        }
    }
    
    // MARK: - Subscription Methods
    
    private func restorePurchases() async {
        do {
            try await storeManager.restorePurchases()
            await MainActor.run {
                if storeManager.subscriptionStatus == .active {
                    restoreResult = "购买恢复成功！您现在可以使用所有Pro功能。"
                } else {
                    restoreResult = "未找到可恢复的购买。"
                }
                showingRestoreAlert = true
            }
        } catch {
            await MainActor.run {
                // Provide user-friendly error messages
                let errorMessage = getSubscriptionErrorMessage(error)
                subscriptionErrorMessage = errorMessage
                showingSubscriptionError = true
            }
        }
    }
    
    private func getSubscriptionErrorMessage(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "网络连接中断。请检查您的网络连接后重试。"
            case .timedOut:
                return "请求超时。请稍后重试。"
            case .cannotConnectToHost:
                return "无法连接到App Store服务器。请稍后重试。"
            case .badServerResponse:
                return "服务器响应错误。请稍后重试。"
            default:
                return "网络错误：\(error.localizedDescription)"
            }
        } else if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .verificationFailed:
                return "购买验证失败。请稍后重试。"
            case .userCancelled:
                return "操作已取消。"
            case .pending:
                return "购买正在处理中，请稍候。"
            case .unknown:
                return "发生未知错误，请稍后重试。"
            case .loadFailed, .purchaseFailed, .restoreFailed, .statusCheckFailed:
                return "操作失败：\(error.localizedDescription)"
            }
        } else {
            return "恢复购买失败：\(error.localizedDescription)"
        }
    }
    
    private func authenticateWithFaceID() {
        isAuthenticating = true
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication,
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
        do {
            // Use the SeedDataManager method to switch scenarios while preserving user data
            try await SeedDataManager.shared.switchToScenario(mode.scenario, in: persistenceController.container.viewContext)
            
            // Update UI on main thread
            await MainActor.run {
                appModeManager.isSampleMode = true
                appModeManager.sampleModeType = (mode.id == "indie") ? "indieDev" : mode.id
                
                // Dismiss the configuration sheet
                dismiss()
            }
        } catch {
            // Handle error - you might want to show an alert here
            print("Error switching to sample mode: \(error)")
        }
    }
    
    private func handleICloudSyncToggle(_ enabled: Bool) {
        // Implementation preserved for future development
        // See documentation comments above for details
    }
    
    private func getPromptListViewMode() -> some View {
        if appModeManager.isSampleMode {
            switch appModeManager.sampleModeType {
            case "changedJob":
                return AnyView(PromptListView(mode: .changedJob))
            case "indieDev":
                return AnyView(PromptListView(mode: .indieDev))
            default:
                return AnyView(PromptListView(mode: .regular))
            }
        } else {
            return AnyView(PromptListView(mode: .regular))
        }
    }
}

// MARK: - Sync Status View
/*
private struct SyncStatusView: View {
    // Implementation preserved for future development
    // See documentation comments above for details
}
*/

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
                        FeatureRow(icon: "faceid", title: "Face ID锁定", description: "使用Face ID保护您的隐私数据")
                        FeatureRow(icon: "chart.bar.fill", title: "高级分析", description: "深入了解您的社交关系")
                        FeatureRow(icon: "lock.shield.fill", title: "隐私保护", description: "全方位保护您的数据安全")
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

// AboutView, PrivacyPolicyView, and TermsOfServiceView are now in AboutView.swift

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

// MARK: - Social Knowledge Base View
struct SocialKnowledgeBaseView: View {
    struct KnowledgeItem: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let isNew: Bool
    }
    
    let knowledgeItems: [KnowledgeItem] = [
        KnowledgeItem(
            title: "职场关系课",
            description: "学习如何在职场中建立和维护有效的人际关系，提升职业发展",
            isNew: true
        ),
        KnowledgeItem(
            title: "软技能提升",
            description: "掌握沟通、情商、领导力等关键软技能，提升个人影响力",
            isNew: false
        )
    ]
    
    var body: some View {
        List {
            ForEach(knowledgeItems) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                        if item.isNew {
                            Text("新")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                    
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("社交知识库")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Add preview for SocialKnowledgeBaseView
struct SocialKnowledgeBaseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SocialKnowledgeBaseView()
        }
    }
} 