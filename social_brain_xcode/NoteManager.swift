import CoreData
import Foundation

class NoteManager {
    static let shared = NoteManager()
    private let context = CoreDataManager.shared.viewContext
    
    private init() {}
    
    // MARK: - Create
    func createNote(text: String) -> Note? {
        let note = Note(context: context)
        note.noteId = UUID()
        note.text = text
        note.createdAt = Date()
        note.updatedAt = Date()
        note.recordStatus = 0 // unsynced
        
        do {
            try context.save()
            return note
        } catch {
            print("Error creating note: \(error)")
            return nil
        }
    }
    
    // MARK: - Read
    func fetchNotes() -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching notes: \(error)")
            return []
        }
    }
    
    func fetchNote(withId noteId: UUID) -> Note? {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "noteId == %@", noteId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching note: \(error)")
            return nil
        }
    }
    
    // MARK: - Update
    func updateNote(noteId: UUID, text: String) -> Bool {
        guard let note = fetchNote(withId: noteId) else { return false }
        
        note.text = text
        note.updatedAt = Date()
        note.recordStatus = 0 // mark as unsynced
        
        do {
            try context.save()
            return true
        } catch {
            print("Error updating note: \(error)")
            return false
        }
    }
    
    // MARK: - Delete
    func deleteNote(noteId: UUID) -> Bool {
        guard let note = fetchNote(withId: noteId) else { return false }
        
        // Soft delete by marking as deleted
        note.recordStatus = 2 // deleted
        note.updatedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error deleting note: \(error)")
            return false
        }
    }
    
    // MARK: - Sync Status
    func markNoteAsSynced(noteId: UUID) -> Bool {
        guard let note = fetchNote(withId: noteId) else { return false }
        
        note.recordStatus = 1 // synced
        note.updatedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error marking note as synced: \(error)")
            return false
        }
    }
    
    // MARK: - Relationships
    func addContactToNote(noteId: UUID, contactId: UUID) -> Bool {
        guard let note = fetchNote(withId: noteId),
              let contact = ContactManager.shared.fetchContact(withId: contactId) else {
            return false
        }
        
        let relationship = NoteContactRelationship(context: context)
        relationship.relationshipId = UUID()
        relationship.note = note
        relationship.contact = contact
        relationship.createdAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error adding contact to note: \(error)")
            return false
        }
    }
    
    func removeContactFromNote(noteId: UUID, contactId: UUID) -> Bool {
        let request: NSFetchRequest<NoteContactRelationship> = NoteContactRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "note.noteId == %@ AND contact.contactId == %@",
                                      noteId as CVarArg, contactId as CVarArg)
        
        do {
            let relationships = try context.fetch(request)
            for relationship in relationships {
                context.delete(relationship)
            }
            try context.save()
            return true
        } catch {
            print("Error removing contact from note: \(error)")
            return false
        }
    }
} 