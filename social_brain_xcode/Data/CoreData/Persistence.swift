//
//  Persistence.swift
//  social_brain_xcode
//
//  Created by chao sun on 2025-04-04.


import CoreData
import CloudKit
import Combine

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    // Add sync status tracking
    @Published var syncStatus: SyncStatus = .notStarted
    @Published private(set) var lastSyncError: Error?
    
    enum SyncStatus {
        case notStarted
        case inProgress
        case completed
        case failed(Error)
    }

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample social contacts
        for i in 0..<5 {
            let contact = Contact(context: viewContext)
            contact.contactId = UUID()
            contact.name = "Contact \(i)"
            contact.createdAt = Date()
            contact.updatedAt = Date()
            contact.recordStatus = 0
            
            // Create sample social notes for each contact
            let note = Note(context: viewContext)
            note.noteId = UUID()
            note.content = "Sample note for \(contact.name ?? "")"
            note.createdAt = Date()
            note.updatedAt = Date()
            note.recordStatus = 0
            
            // Create relationship between note and contact
            let relationship = NoteContactRelationship(context: viewContext)
            relationship.relationshipId = UUID()
            relationship.createdAt = Date()
            relationship.notes = note
            relationship.contacts = contact
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer
    @Published private(set) var isCloudKitEnabled = false
    
    // Add debouncing for remote changes
    private var remoteChangeDebounceTimer: Timer?
    private var lastRemoteChangeTime: Date = Date()
    private let remoteChangeDebounceInterval: TimeInterval = 1.0 // 1 second debounce
    
    // Add tracking to prevent sync loops
    private var lastCloudKitEventType: NSPersistentCloudKitContainer.EventType?
    private var lastCloudKitEventTime: Date = Date()
    private let cloudKitEventDebounceInterval: TimeInterval = 0.5 // 0.5 second debounce for CloudKit events

    init(inMemory: Bool = false) {
        // Disable CoreData debug logging
        UserDefaults.standard.set(false, forKey: "com.apple.CoreData.Logging.stderr")
        UserDefaults.standard.set(false, forKey: "com.apple.CoreData.SQLDebug")
        UserDefaults.standard.set(false, forKey: "com.apple.CoreData.SQLiteIntegrityCheck")
        
        container = NSPersistentCloudKitContainer(name: "social_brain_xcode")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure base store description
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // Initially disable CloudKit sync
        description.cloudKitContainerOptions = nil
        
        // Enable remote notifications and history tracking
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // Set up automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Load the persistent store
        container.loadPersistentStores { [weak self] (storeDescription, error) in
            if let error = error as NSError? {
                print("❌ PersistenceController: Failed to load persistent store: \(error)")
                // Handle store loading errors
                if let url = storeDescription.url {
                    do {
                        try self?.container.persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: storeDescription.type, options: nil)
                        try self?.container.persistentStoreCoordinator.addPersistentStore(ofType: storeDescription.type, configurationName: storeDescription.configuration, at: url, options: storeDescription.options)
                    } catch {
                        print("❌ PersistenceController: Failed to recreate persistent store: \(error)")
                        fatalError("Failed to recreate persistent store: \(error)")
                    }
                } else {
                    print("❌ PersistenceController: No URL available for store recreation")
                    fatalError("Failed to load persistent store: \(error)")
                }
            }
            
            // Set up observers for remote changes
            self?.setupRemoteChangeHandling()
        }
    }
    
    private func setupRemoteChangeHandling() {
        // Observe remote changes
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteChanges()
        }
        
        // Observe sync status changes
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }
    }
    
    private func handleRemoteChanges() {
        // Cancel any existing timer
        remoteChangeDebounceTimer?.invalidate()
        
        // Schedule a new debounced refresh
        remoteChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: remoteChangeDebounceInterval, repeats: false) { [weak self] _ in
            self?.performRemoteChangeRefresh()
        }
    }
    
    private func performRemoteChangeRefresh() {
        // Check if enough time has passed since last refresh to prevent loops
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRemoteChangeTime)
        if timeSinceLastRefresh < remoteChangeDebounceInterval {
            return
        }
        
        lastRemoteChangeTime = Date()
        
        // Refresh the view context when remote changes occur
        container.viewContext.perform {
            self.container.viewContext.refreshAllObjects()
            
            // Post notifications to refresh views after remote changes
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("RefreshNotesList"), object: nil)
                NotificationCenter.default.post(name: Notification.Name("RefreshContactsList"), object: nil)
                NotificationCenter.default.post(name: Notification.Name("RefreshCirclesList"), object: nil)
            }
        }
    }
    
    private func handleCloudKitEvent(_ notification: Notification) {
        guard let cloudEvent = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { 
            return 
        }
        
        // Check if this is a duplicate event to prevent loops
        let timeSinceLastEvent = Date().timeIntervalSince(lastCloudKitEventTime)
        if lastCloudKitEventType == cloudEvent.type && timeSinceLastEvent < cloudKitEventDebounceInterval {
            return
        }
        
        // Update tracking
        lastCloudKitEventType = cloudEvent.type
        lastCloudKitEventTime = Date()
        
        // Ensure all @Published updates happen on main thread
        Task { @MainActor in
            switch cloudEvent.type {
            case .setup:
                syncStatus = .inProgress
            case .import:
                syncStatus = .completed
            case .export:
                syncStatus = .completed
            @unknown default:
                break
            }
            
            if let error = cloudEvent.error {
                syncStatus = .failed(error)
                lastSyncError = error
            }
        }
    }
    
    // MARK: - Sync Status Helpers
    
    func isSyncing() -> Bool {
        if case .inProgress = syncStatus {
            return true
        }
        return false
    }
    
    func hasSyncError() -> Bool {
        if case .failed = syncStatus {
            return true
        }
        return false
    }
    
    func getSyncError() -> Error? {
        if case .failed(let error) = syncStatus {
            return error
        }
        return nil
    }
    
    // Add a method to check iCloud availability
    func checkICloudAvailability() -> Bool {
        let isAvailable = FileManager.default.ubiquityIdentityToken != nil
        return isAvailable
    }
    
    // Add a method to get iCloud account status
    func getICloudAccountStatus() async -> CKAccountStatus {
        return await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                if let error = error {
                    print("❌ PersistenceController: Error checking iCloud account status: \(error)")
                }
                continuation.resume(returning: status)
            }
        }
    }
    
    // Add method to enable/disable CloudKit sync
    func setCloudKitEnabled(_ enabled: Bool) async throws {
        guard let description = container.persistentStoreDescriptions.first else {
            throw NSError(domain: "com.socialbrain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve store description"])
        }
        
        if enabled && !isCloudKitEnabled {
            // Enable CloudKit sync
            let cloudKitContainerIdentifier = "iCloud.socialbrainbeta"
            
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerIdentifier)
            description.cloudKitContainerOptions = cloudKitOptions
            
            // Instead of replacePersistentStore, let's try a different approach
            // First, let's check if we can access the CloudKit container
            do {
                let ckContainer = CKContainer(identifier: cloudKitContainerIdentifier)
                let accountStatus = try await ckContainer.accountStatus()
                
                if accountStatus == .available {
                    // Reload the persistent store with CloudKit enabled
                    if let url = description.url {
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            // First, remove the existing store
                            if let existingStore = self.container.persistentStoreCoordinator.persistentStores.first {
                                do {
                                    try self.container.persistentStoreCoordinator.remove(existingStore)
                                } catch {
                                    continuation.resume(throwing: error)
                                    return
                                }
                            }
                            
                            // Now add the store back with CloudKit enabled
                            self.container.loadPersistentStores { _, error in
                                if let error = error {
                                    continuation.resume(throwing: error)
                                } else {
                                    continuation.resume()
                                }
                            }
                        }
                    }
                    
                    // Update @Published properties on main thread
                    await MainActor.run {
                        isCloudKitEnabled = true
                        syncStatus = .inProgress
                    }
                } else {
                    throw NSError(domain: "com.socialbrain", code: 2, userInfo: [NSLocalizedDescriptionKey: "CloudKit account not available"])
                }
            } catch {
                throw error
            }
            
        } else if !enabled && isCloudKitEnabled {
            // Disable CloudKit sync
            description.cloudKitContainerOptions = nil
            
            // Reload the persistent store without CloudKit
            if let url = description.url {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    // First, remove the existing store
                    if let existingStore = self.container.persistentStoreCoordinator.persistentStores.first {
                        do {
                            try self.container.persistentStoreCoordinator.remove(existingStore)
                        } catch {
                            continuation.resume(throwing: error)
                            return
                        }
                    }
                    
                    // Now add the store back without CloudKit
                    self.container.loadPersistentStores { _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
            
            // Update @Published properties on main thread
            await MainActor.run {
                isCloudKitEnabled = false
                syncStatus = .notStarted
            }
        }
    }

    // Add a public method to check CloudKit status
    func getCloudKitStatus() -> Bool {
        return isCloudKitEnabled
    }
}
