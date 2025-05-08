import CoreData
import Foundation

// Note type enum
enum NoteType: Int {
    case general = 0
    case meeting = 1
    case social = 2
    case followUp = 3
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
    func createNote(content: String, type: NoteType = .general) -> Note? {
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
    
    // MARK: - Background Processing
    private func processNoteInBackground(note: Note) {
        Task {
            do {
                // 1. Extract contact names from the note
                let mentions = getMentionsFromNote(note)
                
                // 2. Form system prompt and user prompt
                let systemPrompt = """
                You are analyzing a social note about the following contacts: \(mentions.joined(separator: ", ")).
                Please analyze the note content and provide insights about:
                1. Key topics discussed
                2. Potential follow-up opportunities
                3. Relationship building suggestions
                """
                
                let userPrompt = note.content ?? ""
                
                // 3. Send request to LLM
                print("[NoteManager] Sending request to LLM:")
                print("System Prompt: \(systemPrompt)")
                print("User Prompt: \(userPrompt)")
                
                guard let chatService = AIServiceManager.shared.getChatService() else {
                    print("[NoteManager] Error: Chat service not available")
                    return
                }
                
                let messages = [
                    AIChatMessage(role: .system, content: systemPrompt),
                    AIChatMessage(role: .user, content: userPrompt)
                ]
                
                let response = try await chatService.sendMessage(userPrompt, context: messages)
                
                print("[NoteManager] Received response from LLM:")
                if let firstChoice = response.choices.first {
                    print("[NoteManager] \(firstChoice.message.content)")
                } else {
                    print("[NoteManager] No content in response")
                }
                
            } catch {
                print("[NoteManager] Error processing note: \(error)")
            }
        }
    }

    func createNoteWithMentions(content: String, type: NoteType = .social, mentions: [String]) -> Note? {
        let note = Note(context: context)
        note.noteId = UUID()
        note.content = content
        note.createdAt = Date()
        note.updatedAt = Date()
        note.recordStatus = 0 // unsynced
        note.type = Int16(type.rawValue)
        note.updateCompleted = 0 // false
        
        // Add contacts
        for mention in mentions {
            // Get or create contact
            let contact: Contact
            if let existingContact = ContactManager.shared.fetchContact(withName: mention) {
                contact = existingContact
            } else {
                // Create new contact if it doesn't exist
                guard let newContact = ContactManager.shared.createContact(name: mention) else {
                    continue
                }
                contact = newContact
            }
            
            // Create relationship in the same context
            let relationship = NoteContactRelationship(context: context)
            relationship.relationshipId = UUID()
            relationship.createdAt = Date()
            
            // Set up both sides of the relationship
            relationship.notes = note
            relationship.contacts = contact
            
            // Save immediately to ensure relationships are established
            do {
                try context.save()
            } catch {
                print("Error saving relationship: \(error)")
                continue
            }
        }
        
        do {
            try context.save()
            note.updateCompleted = 1 // true
            
            // Process note in background
            processNoteInBackground(note: note)
            
            return note
        } catch {
            print("Error creating note with mentions: \(error)")
            context.delete(note) // Clean up if save fails
            return nil
        }
    }
    
    func getMentionsFromNote(_ note: Note) -> [String] {
        guard let relationship = note.contacts,
              let contact = relationship.contacts,
              let name = contact.name else {
            return []
        }
        
        return [name]
    }
} 
