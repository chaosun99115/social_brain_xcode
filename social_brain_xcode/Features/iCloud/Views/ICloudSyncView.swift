import SwiftUI
import CloudKit

struct ICloudSyncView: View {
    @StateObject private var syncManager = ICloudSyncManager.shared
    @EnvironmentObject var featureFlagManager: FeatureFlagManager
    @State private var showingErrorAlert = false
    @State private var showingAccountAlert = false
    @State private var showingSuccessAlert = false
    @State private var showingAccountChangeAlert = false
    @State private var showingSubscriptionRequirementAlert = false
    @State private var currentError: Error?
    
    let onSubscriptionRequired: (() -> Void)?
    
    private var isProUser: Bool {
        featureFlagManager.canUseProFeatures
    }
    
    init(onSubscriptionRequired: (() -> Void)? = nil) {
        self.onSubscriptionRequired = onSubscriptionRequired
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main Toggle - Use single source of truth
            Toggle("启用iCloud同步", isOn: Binding(
                get: { 
                    // Use only the user's stored preference as the single source of truth
                    UserDefaults.standard.bool(forKey: "UserWantsCloudKitSync")
                },
                set: { newValue in
                    if newValue && !isProUser {
                        showingSubscriptionRequirementAlert = true
                    } else {
                        Task {
                            await handleSyncToggle(newValue)
                        }
                    }
                }
            ))
            .disabled(syncManager.isSyncing() || syncManager.isCheckingAccount)
            
            // Progress Status (only shown when iCloud is enabled and actively syncing)
            if syncManager.isCloudKitEnabled && syncManager.isSyncing() {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("正在同步...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.leading, 4)
            }
            
            // Error Display
            if syncManager.hasSyncError(), let error = syncManager.getSyncError() {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text("同步错误")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("重试") {
                            Task {
                                await retrySync()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .onAppear {
            Task {
                await syncManager.checkAccountStatus()
                
                // Ensure sync manager state matches user preference on app launch
                let userWantsSync = UserDefaults.standard.bool(forKey: "UserWantsCloudKitSync")
                if userWantsSync != syncManager.isCloudKitEnabled {
                    // Sync the states - if user wants sync but it's not enabled, try to enable it
                    if userWantsSync && !syncManager.isCloudKitEnabled {
                        do {
                            try await syncManager.toggleCloudKitSync(true)
                        } catch {
                            // If we can't enable sync, update the user preference to match reality
                            print("Failed to enable iCloud sync on app launch: \(error)")
                            UserDefaults.standard.set(false, forKey: "UserWantsCloudKitSync")
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudAccountChanged)) { _ in
            showingAccountChangeAlert = true
        }
        .alert("同步错误", isPresented: $showingErrorAlert) {
            Button("确定", role: .cancel) { }
            if let error = currentError as? ICloudError,
               error.recoverySuggestion != nil {
                Button("查看帮助") {
                    // TODO: Show help sheet
                }
            }
        } message: {
            if let error = currentError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.localizedDescription)
                    if let iCloudError = error as? ICloudError,
                       let suggestion = iCloudError.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .alert("iCloud账户", isPresented: $showingAccountAlert) {
            Button("确定", role: .cancel) { }
            Button("打开设置") {
                openSettings()
            }
        } message: {
            Text("请在设置中登录您的iCloud账户以启用同步功能")
        }
        .alert("iCloud同步已启用", isPresented: $showingSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("您的数据现在将在所有设备上自动同步")
        }
        .alert("iCloud账户已更改", isPresented: $showingAccountChangeAlert) {
            Button("确定", role: .cancel) { }
            Button("检查状态") {
                Task {
                    await syncManager.checkAccountStatus()
                }
            }
        } message: {
            Text("检测到iCloud账户状态发生变化。同步功能可能受到影响，请检查您的iCloud设置。")
        }
        .alert("尚未订阅", isPresented: $showingSubscriptionRequirementAlert) {
            Button("取消", role: .cancel) { }
            Button("去订阅") {
                onSubscriptionRequired?()
            }
        } message: {
            Text("需要订阅后使用该功能")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleSyncToggle(_ enabled: Bool) async {
        do {
            // Store the user's intent immediately
            UserDefaults.standard.set(enabled, forKey: "UserWantsCloudKitSync")
            
            try await syncManager.toggleCloudKitSync(enabled)
            
            // Show success alert when sync is successfully enabled
            if enabled {
                await MainActor.run {
                    showingSuccessAlert = true
                }
            }
        } catch {
            // If sync fails, revert the user preference to match the actual state
            UserDefaults.standard.set(false, forKey: "UserWantsCloudKitSync")
            currentError = error
            showingErrorAlert = true
            
            // If it's an account-related error, show account alert
            if let iCloudError = error as? ICloudError,
               [.noAccount, .restricted].contains(iCloudError) {
                showingAccountAlert = true
            }
        }
    }
    
    private func retrySync() async {
        let userWantsSync = UserDefaults.standard.bool(forKey: "UserWantsCloudKitSync")
        if userWantsSync {
            do {
                // First disable, then re-enable to force a fresh sync
                try await syncManager.toggleCloudKitSync(false)
                try await syncManager.toggleCloudKitSync(true)
            } catch {
                currentError = error
                showingErrorAlert = true
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Preview
struct ICloudSyncView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ICloudSyncView()
                .environmentObject(FeatureFlagManager.shared)
                .padding()
        }
        .previewLayout(.sizeThatFits)
    }
} 