//
//  Persistence.swift
//  social_brain_xcode
//
//  Created by chao sun on 2025-04-04.


import CoreData

class PersistenceController {
    static let shared = PersistenceController()

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

    init(inMemory: Bool = false) {
        // Create a single instance of the container
        container = NSPersistentCloudKitContainer(name: "social_brain_xcode")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Get the store URL
            guard let storeURL = container.persistentStoreDescriptions.first?.url else {
                fatalError("Failed to get store URL")
            }
            
            // Delete existing store if it exists
            if FileManager.default.fileExists(atPath: storeURL.path) {
                do {
                    try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
                    // print("Successfully deleted existing store")
                } catch {
                    // print("Error deleting store: \(error)")
                }
            }
        }
        
        // Configure the container with migration options
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        // Load the persistent stores
        container.loadPersistentStores { [weak self] (storeDescription, error) in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                // Handle the error appropriately
                print("Core Data store failed to load with error: \(error.localizedDescription)")
                print("Detailed error: \(error.userInfo)")
                
                // For development, try to delete and recreate the store
                if let storeURL = storeDescription.url {
                    do {
                        try self.container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
                        try self.container.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: [
                            NSMigratePersistentStoresAutomaticallyOption: true,
                            NSInferMappingModelAutomaticallyOption: true
                        ])
                        print("Successfully recreated store after error")
                    } catch {
                        print("Failed to recreate store: \(error)")
                    }
                }
            }
        }
        
        // Configure the view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
