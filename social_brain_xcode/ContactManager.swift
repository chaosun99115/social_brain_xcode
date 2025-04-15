import CoreData
import Foundation

class ContactManager {
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
        // Hardcoded notes for testing
        let note1 = Note(context: context)
        note1.noteId = UUID()
        note1.text = "Had a great conversation about AI and machine learning"
        note1.createdAt = Date()
        
        let note2 = Note(context: context)
        note2.noteId = UUID()
        note2.text = "Discussed potential collaboration on a new project"
        note2.createdAt = Date()
        
        return [note1, note2]
    }
} 
