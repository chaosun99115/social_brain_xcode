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
            let contact = NSEntityDescription.insertNewObject(forEntityName: "Contact", into: viewContext) as! Contact
            contact.name = "Contact \(i)"
            contact.createdAt = Date()
            contact.updatedAt = Date()
            contact.recordStatus = 0
            
            // Create sample social notes for each contact
            let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: viewContext) as! Note
            note.noteId = UUID()
            note.content = "Sample note for \(contact.name ?? "")"
            note.createdAt = Date()
            note.updatedAt = Date()
            note.recordStatus = 0
            
            // Create relationship between note and contact
            let relationship = NSEntityDescription.insertNewObject(forEntityName: "NoteContactRelationship", into: viewContext) as! NoteContactRelationship
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
    private var isCloudKitEnabled = false

    init(inMemory: Bool = false) {
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
                // Handle store loading errors
                if let url = storeDescription.url {
                    do {
                        try self?.container.persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: storeDescription.type, options: nil)
                        try self?.container.persistentStoreCoordinator.addPersistentStore(ofType: storeDescription.type, configurationName: storeDescription.configuration, at: url, options: storeDescription.options)
                    } catch {
                        fatalError("Failed to recreate persistent store: \(error)")
                    }
                } else {
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
        // Refresh the view context when remote changes occur
        container.viewContext.perform {
            self.container.viewContext.refreshAllObjects()
        }
    }
    
    private func handleCloudKitEvent(_ notification: Notification) {
        guard let cloudEvent = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch cloudEvent.type {
            case .setup:
                self.syncStatus = .inProgress
            case .import:
                self.syncStatus = .completed
            case .export:
                self.syncStatus = .completed
            @unknown default:
                break
            }
            
            if let error = cloudEvent.error {
                self.syncStatus = .failed(error)
                self.lastSyncError = error
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
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    // Add a method to get iCloud account status
    func getICloudAccountStatus() async -> CKAccountStatus {
        return await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                if let error = error {
                    print("Error checking iCloud account status: \(error)")
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
            
            // Reload the persistent store with CloudKit enabled
            if let url = description.url {
                try await container.persistentStoreCoordinator.replacePersistentStore(
                    at: url,
                    destinationOptions: description.options,
                    withPersistentStoreFrom: url,
                    sourceOptions: nil,
                    ofType: description.type
                )
            }
            
            isCloudKitEnabled = true
            syncStatus = .inProgress
        } else if !enabled && isCloudKitEnabled {
            // Disable CloudKit sync
            description.cloudKitContainerOptions = nil
            
            // Reload the persistent store without CloudKit
            if let url = description.url {
                try await container.persistentStoreCoordinator.replacePersistentStore(
                    at: url,
                    destinationOptions: description.options,
                    withPersistentStoreFrom: url,
                    sourceOptions: nil,
                    ofType: description.type
                )
            }
            
            isCloudKitEnabled = false
            syncStatus = .notStarted
        }
    }
}
