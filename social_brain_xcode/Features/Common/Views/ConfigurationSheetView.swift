import SwiftUI
import LocalAuthentication
import CloudKit

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
                            if isProUser {
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
                
                // Pro Features Section (Premium Features)
                Section(header: Text("Pro功能")) {
                    VStack(spacing: 12) {
                        // iCloud Sync Toggle
                        Toggle("iCloud同步", isOn: Binding(
                            get: { isICloudSyncEnabled },
                            set: { newValue in
                                if !isProUser {
                                    pendingICloudSyncAction = newValue
                                    showingProUpgrade = true
                                    isICloudSyncEnabled = false
                                    return
                                }
                                handleICloudSyncToggle(newValue)
                            }
                        ))
                        
                        // Face ID Toggle
                        Toggle("Face ID锁定", isOn: Binding(
                            get: { appSettingsManager.isFaceIDEnabled },
                            set: { newValue in
                                if !isProUser {
                                    pendingFaceIDAction = newValue
                                    showingProUpgrade = true
                                    appSettingsManager.setFaceIDEnabled(false)
                                    return
                                }
                                if newValue {
                                    authenticateWithFaceID()
                                } else {
                                    appSettingsManager.setFaceIDEnabled(false)
                                }
                            }
                        ))
                        .disabled(isAuthenticating)
                        
                        if !isProUser {
                            Text("升级到Pro以解锁所有高级功能")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        
                        if isICloudSyncEnabled && isProUser {
                            SyncStatusView()
                                .padding(.vertical, 8)
                        }
                    }
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
                
                // Add Feature Flag Section (Development Only)
                #if DEBUG
                Section(header: Text("开发设置")) {
                    Toggle("需要订阅才能使用高级功能", isOn: Binding(
                        get: { featureFlagManager.requireSubscriptionForProFeatures },
                        set: { featureFlagManager.setRequireSubscriptionForProFeatures($0) }
                    ))
                    .tint(.accentColor)
                    
                    Text("关闭此选项将允许所有用户使用 Face ID 和 iCloud 同步功能")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                #endif
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
    
    private func handleICloudSyncToggle(_ enabled: Bool) {
        if enabled {
            isCheckingICloud = true
            
            // Check iCloud availability
            Task {
                let status = await persistenceController.getICloudAccountStatus()
                
                await MainActor.run {
                    isCheckingICloud = false
                    
                    switch status {
                    case .available:
                        // Enable CloudKit sync
                        Task {
                            do {
                                try await persistenceController.setCloudKitEnabled(true)
                                await MainActor.run {
                                    isICloudSyncEnabled = true
                                }
                            } catch {
                                await MainActor.run {
                                    isICloudSyncEnabled = false
                                    syncError = error
                                    showingSyncError = true
                                }
                            }
                        }
                        
                    case .noAccount:
                        isICloudSyncEnabled = false
                        let error = NSError(
                            domain: "com.socialbrain",
                            code: 1,
                            userInfo: [
                                NSLocalizedDescriptionKey: "iCloud 未登录",
                                NSLocalizedRecoverySuggestionErrorKey: """
                                    请在系统设置中登录 iCloud 账号以启用同步功能。

                                    1. 打开系统设置
                                    2. 点击顶部的 Apple ID
                                    3. 选择"iCloud"
                                    4. 确保已登录并启用了 iCloud
                                    """
                            ]
                        )
                        syncError = error
                        showingSyncError = true
                        
                    case .restricted:
                        isICloudSyncEnabled = false
                        let error = NSError(
                            domain: "com.socialbrain",
                            code: 2,
                            userInfo: [
                                NSLocalizedDescriptionKey: "iCloud 访问受限",
                                NSLocalizedRecoverySuggestionErrorKey: """
                                    您的设备可能启用了访问限制。

                                    1. 打开系统设置
                                    2. 点击"屏幕使用时间"
                                    3. 点击"内容和隐私访问限制"
                                    4. 确保 iCloud 访问未被限制
                                    """
                            ]
                        )
                        syncError = error
                        showingSyncError = true
                        
                    case .couldNotDetermine:
                        isICloudSyncEnabled = false
                        let error = NSError(
                            domain: "com.socialbrain",
                            code: 3,
                            userInfo: [
                                NSLocalizedDescriptionKey: "无法确定 iCloud 状态",
                                NSLocalizedRecoverySuggestionErrorKey: """
                                    请检查您的网络连接并确保：

                                    1. 设备已连接到互联网
                                    2. 系统设置中的 iCloud 服务正常
                                    3. 如果问题持续，请尝试重启设备
                                    """
                            ]
                        )
                        syncError = error
                        showingSyncError = true
                        
                    @unknown default:
                        isICloudSyncEnabled = false
                        let error = NSError(
                            domain: "com.socialbrain",
                            code: 4,
                            userInfo: [
                                NSLocalizedDescriptionKey: "未知的 iCloud 状态",
                                NSLocalizedRecoverySuggestionErrorKey: "请稍后重试。如果问题持续存在，请联系客服。"
                            ]
                        )
                        syncError = error
                        showingSyncError = true
                    }
                }
            }
        } else {
            // Disable CloudKit sync
            Task {
                do {
                    try await persistenceController.setCloudKitEnabled(false)
                    await MainActor.run {
                        isICloudSyncEnabled = false
                    }
                } catch {
                    await MainActor.run {
                        syncError = error
                        showingSyncError = true
                    }
                }
            }
        }
    }
}

// MARK: - Sync Status View
private struct SyncStatusView: View {
    @ObservedObject private var persistenceController = PersistenceController.shared
    @State private var showingErrorAlert = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Sync Status Icon
            Image(systemName: syncStatusIcon)
                .font(.system(size: 24))
                .foregroundColor(syncStatusColor)
            
            // Sync Status Text
            Text(syncStatusText)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Last Sync Time (if available)
            if let lastSyncTime = lastSyncTime {
                Text("Last synced: \(lastSyncTime, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Sync Button
            Button(action: {
                // Trigger a manual sync by refreshing the view context
                persistenceController.container.viewContext.refreshAllObjects()
            }) {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .disabled(persistenceController.isSyncing())
        }
        .padding()
        .alert("Sync Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = persistenceController.getSyncError() {
                Text(error.localizedDescription)
            }
        }
        .onChange(of: persistenceController.hasSyncError()) { hasError in
            showingErrorAlert = hasError
        }
    }
    
    private var syncStatusIcon: String {
        switch persistenceController.syncStatus {
        case .notStarted:
            return "icloud.slash"
        case .inProgress:
            return "icloud.and.arrow.down.fill"
        case .completed:
            return "checkmark.icloud.fill"
        case .failed:
            return "exclamationmark.icloud.fill"
        }
    }
    
    private var syncStatusColor: Color {
        switch persistenceController.syncStatus {
        case .notStarted:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var syncStatusText: String {
        switch persistenceController.syncStatus {
        case .notStarted:
            return "Sync Not Started"
        case .inProgress:
            return "Syncing..."
        case .completed:
            return "Sync Complete"
        case .failed:
            return "Sync Failed"
        }
    }
    
    private var lastSyncTime: Date? {
        // In a real app, you might want to store and retrieve the last successful sync time
        // For now, we'll just return nil
        nil
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
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