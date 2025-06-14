import Foundation
import CloudKit
import CoreData
import Combine
import UIKit

@MainActor
class ICloudSyncManager: ObservableObject {
    static let shared = ICloudSyncManager()
    
    // MARK: - Published Properties
    @Published var syncStatus: SyncStatus = .notStarted
    @Published var isCloudKitEnabled = false
    @Published var lastSyncError: Error?
    @Published var isCheckingAccount = false
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    
    // MARK: - Private Properties
    private var persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    
    // Add debouncing for remote changes
    private var remoteChangeDebounceTimer: Timer?
    private var lastRemoteChangeTime: Date = Date()
    private let remoteChangeDebounceInterval: TimeInterval = 1.0 // 1 second debounce
    
    // Add tracking to prevent sync loops
    private var lastCloudKitEventType: NSPersistentCloudKitContainer.EventType?
    private var lastCloudKitEventTime: Date = Date()
    private let cloudKitEventDebounceInterval: TimeInterval = 0.5 // 0.5 second debounce for CloudKit events
    
    // MARK: - Sync Status Enum
    enum SyncStatus: Equatable {
        case notStarted
        case inProgress
        case completed
        case failed(Error)
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted),
                 (.inProgress, .inProgress),
                 (.completed, .completed):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        self.persistenceController = PersistenceController.shared
        setupObservers()
        loadCurrentStatus()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe CloudKit events from PersistenceController
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification, object: persistenceController.container)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleCloudKitEvent(notification)
            }
            .store(in: &cancellables)
        
        // Observe remote changes
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange, object: persistenceController.container.persistentStoreCoordinator)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleRemoteChanges()
            }
            .store(in: &cancellables)
        
        // Observe iCloud account status changes
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAccountStatusChange()
            }
            .store(in: &cancellables)
        
        // Observe app lifecycle for account status checks
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
    }
    
    private func loadCurrentStatus() {
        isCloudKitEnabled = persistenceController.getCloudKitStatus()
        syncStatus = mapSyncStatus(persistenceController.syncStatus)
        lastSyncError = persistenceController.lastSyncError
    }
    
    private func mapSyncStatus(_ status: PersistenceController.SyncStatus) -> SyncStatus {
        switch status {
        case .notStarted:
            return .notStarted
        case .inProgress:
            return .inProgress
        case .completed:
            return .completed
        case .failed(let error):
            return .failed(error)
        }
    }
    
    // MARK: - Public Methods
    
    /// Check iCloud account availability
    func checkICloudAvailability() -> Bool {
        let isAvailable = FileManager.default.ubiquityIdentityToken != nil
        return isAvailable
    }
    
    /// Get current iCloud account status
    func checkAccountStatus() async {
        isCheckingAccount = true
        defer { 
            isCheckingAccount = false
        }
        
        do {
            accountStatus = try await CKContainer.default().accountStatus()
        } catch {
            accountStatus = .couldNotDetermine
        }
    }
    
    /// Enable or disable CloudKit sync
    func toggleCloudKitSync(_ enabled: Bool) async throws {
        if enabled {
            await checkAccountStatus()
            
            switch accountStatus {
            case .available:
                break
            case .noAccount:
                throw ICloudError.noAccount
            case .restricted:
                throw ICloudError.restricted
            case .couldNotDetermine:
                throw ICloudError.couldNotDetermine
            case .temporarilyUnavailable:
                throw ICloudError.temporarilyUnavailable
            @unknown default:
                throw ICloudError.unknown
            }
        }
        
        try await persistenceController.setCloudKitEnabled(enabled)
        
        await MainActor.run {
            isCloudKitEnabled = enabled
            
            if enabled {
                syncStatus = .inProgress
                storeSyncPreference(true)
            } else {
                syncStatus = .notStarted
                lastSyncError = nil
                storeSyncPreference(false)
            }
        }
    }
    
    /// Get sync status description for UI
    func getSyncStatusDescription() -> String {
        switch syncStatus {
        case .notStarted:
            return isCloudKitEnabled ? "准备同步" : "未启用"
        case .inProgress:
            return "同步中..."
        case .completed:
            return "同步完成"
        case .failed(let error):
            return "同步失败: \(error.localizedDescription)"
        }
    }
    
    /// Get sync status icon for UI
    func getSyncStatusIcon() -> String {
        switch syncStatus {
        case .notStarted:
            return isCloudKitEnabled ? "icloud" : "icloud.slash"
        case .inProgress:
            return "icloud.and.arrow.up"
        case .completed:
            return "icloud.and.arrow.down"
        case .failed:
            return "icloud.slash"
        }
    }
    
    /// Get sync status color for UI
    func getSyncStatusColor() -> String {
        switch syncStatus {
        case .notStarted:
            return isCloudKitEnabled ? "blue" : "gray"
        case .inProgress:
            return "blue"
        case .completed:
            return "green"
        case .failed:
            return "red"
        }
    }
    
    /// Check if currently syncing
    func isSyncing() -> Bool {
        if case .inProgress = syncStatus {
            return true
        }
        return false
    }
    
    /// Check if there's a sync error
    func hasSyncError() -> Bool {
        if case .failed = syncStatus {
            return true
        }
        return false
    }
    
    /// Get the last sync error
    func getSyncError() -> Error? {
        if case .failed(let error) = syncStatus {
            return error
        }
        return lastSyncError
    }
    
    // MARK: - Private Methods
    
    private func handleCloudKitEvent(_ notification: Notification) {
        guard let cloudEvent = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { 
            return 
        }
        
        let timeSinceLastEvent = Date().timeIntervalSince(lastCloudKitEventTime)
        if lastCloudKitEventType == cloudEvent.type && timeSinceLastEvent < cloudKitEventDebounceInterval {
            return
        }
        
        lastCloudKitEventType = cloudEvent.type
        lastCloudKitEventTime = Date()
        
        switch cloudEvent.type {
        case .setup:
            // CloudKit setup event - no action needed
            break
        case .import:
            // CloudKit import event - post refresh notifications
            syncStatus = .completed
            postRefreshNotifications()
        case .export:
            // CloudKit export event - post refresh notifications
            syncStatus = .completed
            postRefreshNotifications()
        @unknown default:
            break
        }
        
        if let error = cloudEvent.error {
            syncStatus = .failed(error)
            lastSyncError = error
        }
    }
    
    private func handleRemoteChanges() {
        remoteChangeDebounceTimer?.invalidate()
        
        remoteChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: remoteChangeDebounceInterval, repeats: false) { [weak self] _ in
            self?.performRemoteChangeRefresh()
        }
    }
    
    private func performRemoteChangeRefresh() {
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRemoteChangeTime)
        if timeSinceLastRefresh < remoteChangeDebounceInterval {
            return
        }
        
        lastRemoteChangeTime = Date()
        
        persistenceController.container.viewContext.perform {
            self.persistenceController.container.viewContext.refreshAllObjects()
            
            DispatchQueue.main.async {
                self.postRefreshNotifications()
            }
        }
    }
    
    private func postRefreshNotifications() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("RefreshNotesList"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("RefreshContactsList"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("RefreshCirclesList"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("RefreshPromptList"), object: nil)
        }
    }
    
    // MARK: - Account Change Handling
    
    /// Handle iCloud account status changes
    private func handleAccountStatusChange() {
        Task {
            await checkAccountStatus()
            
            // Check if user wants sync enabled
            let userWantsSync = UserDefaults.standard.bool(forKey: "UserWantsCloudKitSync")
            
            // If sync is enabled but account is no longer available, show error but don't disable permanently
            if isCloudKitEnabled && accountStatus != .available {
                await MainActor.run {
                    syncStatus = .failed(ICloudError.noAccount)
                    lastSyncError = ICloudError.noAccount
                }
                
                // Post notification for UI to show account change alert
                NotificationCenter.default.post(name: .iCloudAccountChanged, object: nil)
                
                // Don't disable sync permanently if user wants it - just show the error
                // The sync will be re-attempted when account becomes available again
            }
            
            // If account becomes available and user wants sync enabled, re-enable
            if accountStatus == .available && !isCloudKitEnabled && userWantsSync {
                do {
                    try await toggleCloudKitSync(true)
                } catch {
                    print("❌ Failed to re-enable sync after account change: \(error)")
                }
            }
        }
    }
    
    /// Handle app becoming active - check account status
    private func handleAppDidBecomeActive() {
        Task {
            await checkAccountStatus()
        }
    }
    
    /// Store sync preference for account change recovery
    private func storeSyncPreference(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "UserWantsCloudKitSync")
    }
}

// MARK: - ICloud Error Types
enum ICloudError: LocalizedError {
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "未登录iCloud账户"
        case .restricted:
            return "iCloud访问受限"
        case .couldNotDetermine:
            return "无法确定iCloud状态"
        case .temporarilyUnavailable:
            return "iCloud暂时不可用"
        case .unknown:
            return "未知错误"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noAccount:
            return "请在设置中登录您的iCloud账户"
        case .restricted:
            return "请检查iCloud设置中的访问权限"
        case .couldNotDetermine:
            return "请检查网络连接并重试"
        case .temporarilyUnavailable:
            return "请稍后重试"
        case .unknown:
            return "请重启应用或联系支持"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let iCloudAccountChanged = Notification.Name("iCloudAccountChanged")
} 