import CoreData
import Foundation

class ContactManager: ObservableObject {
    static let shared = ContactManager()
    private let context = CoreDataManager.shared.viewContext
    
    private init() {}
    
    // MARK: - Create
    func createContact(name: String) -> Contact? {
        let contact = Contact(context: context)
        contact.contactId = UUID()
        contact.name = name
        contact.createdAt = Date()
        contact.updatedAt = Date()
        contact.recordStatus = 0 // unsynced
        
        do {
            try context.save()
            return contact
        } catch {
            print("Error creating contact: \(error)")
            return nil
        }
    }
    
    // MARK: - Read
    func fetchContacts() -> [Contact] {
        let request: NSFetchRequest<Contact> = Contact.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Contact.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching contacts: \(error)")
            return []
        }
    }
    
    func fetchContact(withId contactId: UUID) -> Contact? {
        let request: NSFetchRequest<Contact> = Contact.fetchRequest()
        request.predicate = NSPredicate(format: "contactId == %@", contactId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching contact: \(error)")
            return nil
        }
    }
    
    func fetchContact(withName name: String) -> Contact? {
        let request: NSFetchRequest<Contact> = Contact.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching contact by name: \(error)")
            return nil
        }
    }
    
    func contactExists(withName name: String) -> Bool {
        return fetchContact(withName: name) != nil
    }
    
    // MARK: - Update
    func updateContact(contactId: UUID, name: String) -> Bool {
        guard let contact = fetchContact(withId: contactId) else { return false }
        
        contact.name = name
        contact.updatedAt = Date()
        contact.recordStatus = 0 // mark as unsynced
        
        do {
            try context.save()
            return true
        } catch {
            print("Error updating contact: \(error)")
            return false
        }
    }
    
    // MARK: - Delete
    func deleteContact(contactId: UUID) -> Bool {
        guard let contact = fetchContact(withId: contactId) else { return false }
        
        // Soft delete by marking as deleted
        contact.recordStatus = 2 // deleted
        contact.updatedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error deleting contact: \(error)")
            return false
        }
    }
    
    // MARK: - Sync Status
    func markContactAsSynced(contactId: UUID) -> Bool {
        guard let contact = fetchContact(withId: contactId) else { return false }
        
        contact.recordStatus = 1 // synced
        contact.updatedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error marking contact as synced: \(error)")
            return false
        }
    }
    
    // MARK: - Relationships
    func getNotesForContact(contactId: UUID) -> [Note] {
        guard let contact = fetchContact(withId: contactId) else { return [] }
        
        // Get the relationships
        let relationships = contact.notes as? Set<NoteContactRelationship> ?? []
        
        // Extract notes from relationships
        var notes: [Note] = []
        for relationship in relationships {
            if let note = relationship.notes {
                notes.append(note)
            }
        }
        
        // Sort notes by creation date (newest first)
        return notes.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    // MARK: - Note Count
    func getNotesCount(forContactId contactId: UUID) -> Int {
        return getNotesForContact(contactId: contactId).count
    }
    
    func validateContactRelationships(_ contact: Contact) throws {
        // If contact has no relationships, that's valid
        guard let relationships = contact.notes as? Set<NoteContactRelationship> else {
            return // No relationships is valid
        }
        
        // Check for any invalid relationships
        for relationship in relationships {
            if relationship.notes == nil {
                // Clean up invalid relationship
                context.delete(relationship)
            }
        }
        
        // Save any changes made during validation
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error cleaning up invalid relationships: \(error)")
            }
        }
    }
    
    // MARK: - Relationship Management
    func addNoteToContact(contactId: UUID, noteId: UUID) -> Bool {
        guard let contact = fetchContact(withId: contactId),
              let note = NoteManager.shared.fetchNote(withId: noteId) else {
            return false
        }
        
        let relationship = NoteContactRelationship(context: context)
        relationship.relationshipId = UUID()
        relationship.contacts = contact
        relationship.notes = note
        relationship.createdAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error adding note to contact: \(error)")
            return false
        }
    }
    
    func removeNoteFromContact(contactId: UUID, noteId: UUID) -> Bool {
        let request: NSFetchRequest<NoteContactRelationship> = NoteContactRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "contacts.contactId == %@ AND notes.noteId == %@",
                                      contactId as CVarArg, noteId as CVarArg)
        
        do {
            let relationships = try context.fetch(request)
            for relationship in relationships {
                context.delete(relationship)
            }
            try context.save()
            return true
        } catch {
            print("Error removing note from contact: \(error)")
            return false
        }
    }
} 
