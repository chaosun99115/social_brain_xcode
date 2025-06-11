import CoreData
import Foundation

// Note type enum
enum NoteType: Int {
    case sample = 0    // Sample notes
    case regular = 1   // Regular notes
    case memo = 2      // Memo notes
}

class NoteManager: ObservableObject {
    static let shared = NoteManager()
    private let context = CoreDataManager.shared.viewContext
    
    private init() {}
    
    // MARK: - Create
    func createNote(text: String) -> Note? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return nil }
        let note = Note(context: context)
        note.noteId = UUID()
        note.content = trimmedText
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
    
    // New method to create a note with content and type
    func createNote(content: String, type: NoteType = .regular) -> Note? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return nil }
        let note = Note(context: context)
        note.noteId = UUID()
        note.content = trimmedContent
        note.createdAt = Date()
        note.updatedAt = Date()
        note.recordStatus = 0 // unsynced
        note.type = Int16(type.rawValue)
        
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
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)
        ]
        
        do {
            let notes = try context.fetch(request)
            return notes
        } catch {
            print("Error fetching notes: \(error)")
            return []
        }
    }
    
    func fetchActiveNotes() -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)
        ]
        
        do {
            let notes = try context.fetch(request)
            return notes
        } catch {
            print("Error fetching active notes: \(error)")
            return []
        }
    }
    
    func fetchAllNotes() async throws -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)
        ]
        
        return try context.fetch(request)
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
    
    // MARK: - Fetch by Type and SubType
    func fetchNotes(type: Int16, subType: Int16) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "type == %d AND subType == %d", type, subType)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)
        ]
        
        do {
            let notes = try context.fetch(request)
            return notes
        } catch {
            print("Error fetching notes by type and subtype: \(error)")
            return []
        }
    }
    
    func fetchActiveNotes(type: Int16, subType: Int16) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "type == %d AND subType == %d AND (isArchived == NO OR isArchived == nil)", type, subType)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)
        ]
        
        do {
            let notes = try context.fetch(request)
            return notes
        } catch {
            print("Error fetching active notes by type and subtype: \(error)")
            return []
        }
    }
    
    func fetchNotesAsync(type: Int16, subType: Int16) async throws -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "type == %d AND subType == %d", type, subType)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)
        ]
        
        return try context.fetch(request)
    }
    
    // MARK: - Update
    func updateNote(noteId: UUID, text: String) -> Bool {
        guard let note = fetchNote(withId: noteId) else { return false }
        
        note.content = text
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
    
    // New method to update note with mentions and relationships
    func updateNoteWithMentions(noteId: UUID, content: String, mentions: [String]) async -> Bool {
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        return await backgroundContext.perform {
            // Get the note in background context
            guard let backgroundNote = try? backgroundContext.existingObject(with: self.fetchNote(withId: noteId)?.objectID ?? NSManagedObjectID()) as? Note else {
                return false
            }
            
            // Update note content
            backgroundNote.content = content
            backgroundNote.updatedAt = Date()
            backgroundNote.recordStatus = 0 // mark as unsynced
            
            // Remove existing relationships
            let existingRelationships = backgroundNote.contacts as? Set<NoteContactRelationship> ?? []
            for relationship in existingRelationships {
                backgroundContext.delete(relationship)
            }
            
            // Add new relationships for mentions
            for mention in mentions {
                // Get or create contact in the background context
                let contact: Contact
                if let existingContact = ContactManager.shared.fetchContact(withName: mention) {
                    // Get the contact in the background context
                    guard let contactInBackgroundContext = try? backgroundContext.existingObject(with: existingContact.objectID) as? Contact else {
                        continue
                    }
                    contact = contactInBackgroundContext
                } else {
                    // Create new contact in the background context
                    let newContact = Contact(context: backgroundContext)
                    newContact.contactId = UUID()
                    newContact.name = mention
                    newContact.createdAt = Date()
                    newContact.updatedAt = Date()
                    newContact.recordStatus = 0 // unsynced
                    newContact.type = 0 // default type
                    newContact.isArchived = false // Set isArchived to false
                    
                    // Save the background context to ensure the contact is properly created
                    do {
                        try backgroundContext.save()
                    } catch {
                        continue
                    }
                    
                    contact = newContact
                }
                
                // Create relationship in the same context
                let relationship = NoteContactRelationship(context: backgroundContext)
                relationship.relationshipId = UUID()
                relationship.createdAt = Date()
                relationship.notes = backgroundNote
                relationship.contacts = contact
            }
            
            do {
                // Save the background context
                try backgroundContext.save()
                
                // Save the parent context
                try self.context.save()
                
                // Process note in background (fire-and-forget)
                Task.detached { [weak self] in
                    guard let self = self, let note = self.fetchNote(withId: noteId) else { return }
                    await self.processNoteInBackground(note)
                }
                
                return true
            } catch {
                print("Error updating note with mentions: \(error)")
                return false
            }
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
    
    // MARK: - Archive
    func archiveNote(noteId: UUID) -> Bool {
        guard let note = fetchNote(withId: noteId) else { return false }
        
        note.isArchived = true
        note.updatedAt = Date()
        note.recordStatus = 0 // mark as unsynced
        
        do {
            try context.save()
            return true
        } catch {
            print("Error archiving note: \(error)")
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
        relationship.notes = note
        relationship.contacts = contact
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
        request.predicate = NSPredicate(format: "notes.noteId == %@ AND contacts.contactId == %@",
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
    
    // MARK: - Helper Methods
    private func extractMentions(from text: String) -> [String] {
        // Match @ followed by one or more of: Chinese, English, numbers, underscore, hyphen, full-width parenthesis
        // Stop at whitespace or common punctuation
        let pattern = "@([\\u4e00-\\u9fa5A-Za-z0-9_\\-（）()]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        return results.map { match in
            return nsString.substring(with: match.range(at: 1))
        }
    }
    
    // MARK: - Background Processing
    private func processNoteInBackground(_ note: Note) async {
        let context = note.managedObjectContext!
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        do {
            // Get the note in background context
            let backgroundNote = try await backgroundContext.perform {
                guard let backgroundNote = try backgroundContext.existingObject(with: note.objectID) as? Note else {
                    throw NSError(domain: "NoteManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get note in background context"])
                }
                return backgroundNote
            }
            
            // Extract mentions from the note
            let mentions = extractMentions(from: backgroundNote.content ?? "")
            
            // Fetch contacts for mentions
            let relatedContacts = try await backgroundContext.perform {
                let request: NSFetchRequest<Contact> = Contact.fetchRequest()
                request.predicate = NSPredicate(format: "name IN %@", mentions)
                return try backgroundContext.fetch(request)
            }
            
            // Update the note in background context
            try await backgroundContext.perform {
                backgroundNote.updateCompleted = 1
                try backgroundContext.save()
            }
            
            // Update the main context
            await MainActor.run {
                note.updateCompleted = 1
                try? context.save()
            }
            
        } catch {
            print("Error processing note: \(error.localizedDescription)")
            // Update error state on main thread
            await MainActor.run {
                note.updateCompleted = 0
                try? context.save()
            }
        }
    }

    func createNoteWithMentions(content: String, type: NoteType = .regular, subType: Int16 = 1, mentions: [String]) async -> Note? {
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        return await backgroundContext.perform {
            let note = Note(context: backgroundContext)
            note.noteId = UUID()
            note.content = content
            note.createdAt = Date()
            note.updatedAt = Date()
            note.recordStatus = 0 // unsynced
            note.type = Int16(type.rawValue)
            note.subType = subType // Set the subType
            note.updateCompleted = 0 // false
            
            // Add contacts
            for mention in mentions {
                // Get or create contact in the background context
                let contact: Contact
                if let existingContact = ContactManager.shared.fetchContact(withName: mention) {
                    // Get the contact in the background context
                    guard let contactInBackgroundContext = try? backgroundContext.existingObject(with: existingContact.objectID) as? Contact else {
                        continue
                    }
                    contact = contactInBackgroundContext
                } else {
                    // Create new contact in the background context
                    let newContact = Contact(context: backgroundContext)
                    newContact.contactId = UUID()
                    newContact.name = mention
                    newContact.createdAt = Date()
                    newContact.updatedAt = Date()
                    newContact.recordStatus = 0 // unsynced
                    newContact.type = 0 // default type
                    newContact.isArchived = false // Set isArchived to false
                    
                    // Save the background context to ensure the contact is properly created
                    do {
                        try backgroundContext.save()
                    } catch {
                        continue
                    }
                    
                    contact = newContact
                }
                
                // Create relationship in the same context
                let relationship = NoteContactRelationship(context: backgroundContext)
                relationship.relationshipId = UUID()
                relationship.createdAt = Date()
                relationship.notes = note
                relationship.contacts = contact
            }
            
            do {
                // Save the background context
                try backgroundContext.save()
                
                // Save the parent context
                try self.context.save()
                
                // Process note in background (fire-and-forget)
                let noteId = note.noteId
                Task.detached { [weak self] in
                    guard let self = self, let noteId = noteId, let note = self.fetchNote(withId: noteId) else { return }
                    await self.processNoteInBackground(note)
                }
                
                return note
            } catch {
                backgroundContext.delete(note)
                return nil
            }
        }
    }
    
    func getMentionsFromNote(_ note: Note) -> [String] {
        guard let relationships = note.contacts as? Set<NoteContactRelationship> else {
            return []
        }
        
        return relationships.compactMap { relationship in
            relationship.contacts?.name
        }
    }
} 
