//
//  Persistence.swift
//  social_brain_xcode
//
//  Created by chao sun on 2025-04-04.
//  this is for debug

import CoreData

struct PersistenceController {
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
            note.setValue(UUID(), forKey: "noteId")
            note.setValue("Sample note for \(contact.name ?? "")", forKey: "text")
            note.setValue(Date(), forKey: "createdAt")
            note.setValue(Date(), forKey: "updatedAt")
            note.setValue(0, forKey: "recordStatus")
            
            // Create relationship between note and contact
            let relationship = NSEntityDescription.insertNewObject(forEntityName: "NoteContactRelationship", into: viewContext) as! NoteContactRelationship
            relationship.relationshipId = UUID()
//            relationship.note = note
//            relationship.contact = contact
//            relationship.createdAt = Date()
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
        container = NSPersistentCloudKitContainer(name: "social_brain_xcode")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
