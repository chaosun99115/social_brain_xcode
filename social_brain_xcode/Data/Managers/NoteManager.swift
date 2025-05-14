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
    
    func fetchAllNotes() async throws -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        
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
    private func processNoteInBackground(note: Note) async {
        
        print("==== Starting background processing for note: \(note.noteId?.uuidString ?? "unknown") ====")
        print("📝 Note content: \(note.content ?? "")")
        
        // Create a background context
        let backgroundContext = CoreDataManager.shared.newBackgroundContext()
        
        do {
            // Fetch the note in the background context
            let backgroundNote = try await backgroundContext.perform {
                let request: NSFetchRequest<Note> = Note.fetchRequest()
                request.predicate = NSPredicate(format: "noteId == %@", note.noteId! as CVarArg)
                return try backgroundContext.fetch(request).first
            }
            
            guard let backgroundNote = backgroundNote else {
                print("❌ Could not find note in background context")
                return
            }
            
            // Extract mentions from note text
            print("🔍 Extracting mentions from note...")
            let mentions = try await backgroundContext.perform {
                guard let content = backgroundNote.content else { return [] }
                // Match @ followed by one or more of: Chinese, English, numbers, underscore, hyphen, full-width parenthesis
                // Stop at whitespace or common punctuation
                let pattern = "@([\\u4e00-\\u9fa5A-Za-z0-9_\\-（）()]+)"
                let regex = try NSRegularExpression(pattern: pattern)
                let nsString = content as NSString
                let results = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
                
                return results.map { match in
                    return nsString.substring(with: match.range(at: 1))
                }
            }
            print("🔍 Found mentions in text: \(mentions)")
            
            // Fetch contacts based on mentions
            print("👥 Fetching contacts for mentions...")
            let relatedContacts = try await backgroundContext.perform {
                let request: NSFetchRequest<Contact> = Contact.fetchRequest()
                request.predicate = NSPredicate(format: "name IN %@", mentions)
                return try backgroundContext.fetch(request)
            }
            print("👥 Found related contacts: \(relatedContacts)")
            
            // Fetch notes related to these contacts
            print("📚 Fetching notes related to contacts...")
            let relatedNotes = try await backgroundContext.perform {
                let request: NSFetchRequest<Note> = Note.fetchRequest()
                request.predicate = NSPredicate(format: "ANY contacts.contacts IN %@", relatedContacts)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
                return try backgroundContext.fetch(request)
            }
            print("📚 Found \(relatedNotes.count) related notes")
            
            // Generate system and user prompts
            let systemPrompt = SystemPrompts.General.noteUpdateSytemPrompt()
            print("🤖 System Prompt: \(systemPrompt)")
            
            // Log the note text and related data before generating user prompt
            print("📝 Original note text: \(backgroundNote.content ?? "nil")")
            print("👥 Related contacts count: \(relatedContacts.count)")
            let contactNames = relatedContacts.compactMap { $0.name }
            for name in contactNames {
                print("👥 Contact name: \(name)")
            }
            print("📚 Related notes count: \(relatedNotes.count)")
            
            let userPrompt = SystemPrompts.General.noteupdateUserPrompt(
                noteText: backgroundNote.content ?? "",
                relatedNotes: relatedNotes,
                contactNames: contactNames
            )
            print("🤖 User Prompt: \(userPrompt)")
            
            // Get AI service and send request
            guard let chatService = AIServiceManager.shared.getChatService() else {
                print("❌ No AI service configured")
                throw AIChatServiceError.unauthorized
            }
            
            let messages = [
                AIChatMessage(role: .system, content: systemPrompt),
                AIChatMessage(role: .user, content: userPrompt)
            ]
            
            print("🤖 Sending request to LLM...")
            let response = try await chatService.sendMessage(userPrompt, context: messages)
            
            if let firstChoice = response.choices.first {
                print("🤖 Received LLM response: \(firstChoice.message.content)")
                
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
                
                print("✅ Successfully processed note with LLM")
            } else {
                print("❌ No content in LLM response")
                throw AIChatServiceError.invalidResponse
            }
            
        } catch {
            print("❌ Error processing note: \(error.localizedDescription)")
            // Update error state on main thread
            await MainActor.run {
                note.updateCompleted = 0
                try? context.save()
            }
        }
    }

    func createNoteWithMentions(content: String, type: NoteType = .social, mentions: [String]) async -> Note? {
        print("[NoteManager] Starting note creation with \(mentions.count) mentions")
        print("[NoteManager] Note content: \(content)")
        print("[NoteManager] Note type: \(type)")
        
        let note = Note(context: context)
        note.noteId = UUID()
        note.content = content
        note.createdAt = Date()
        note.updatedAt = Date()
        note.recordStatus = 0 // unsynced
        note.type = Int16(type.rawValue)
        note.updateCompleted = 0 // false
        
        print("[NoteManager] Created note object with ID: \(note.noteId?.uuidString ?? "nil")")
        
        // Add contacts
        for mention in mentions {
            print("[NoteManager] Processing mention: \(mention)")
            
            // Get or create contact
            let contact: Contact
            if let existingContact = ContactManager.shared.fetchContact(withName: mention) {
                print("[NoteManager] Found existing contact: \(mention)")
                contact = existingContact
            } else {
                print("[NoteManager] Creating new contact: \(mention)")
                // Create new contact if it doesn't exist
                guard let newContact = ContactManager.shared.createContact(name: mention) else {
                    print("[NoteManager] Failed to create contact: \(mention)")
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
            
            print("[NoteManager] Created relationship between note and contact: \(mention)")
            
            // Save immediately to ensure relationships are established
            do {
                try context.save()
                print("[NoteManager] Saved relationship for contact: \(mention)")
            } catch {
                print("[NoteManager] Error saving relationship for \(mention): \(error)")
                continue
            }
        }
        
        do {
            try context.save()
            note.updateCompleted = 1 // true
            print("[NoteManager] Successfully saved note with all relationships")
            
            // Process note in background (fire-and-forget)
            print("[NoteManager] Starting background processing for note")
            let noteId = note.noteId
            Task.detached { [weak self] in
                guard let self = self, let noteId = noteId, let note = self.fetchNote(withId: noteId) else { return }
                await self.processNoteInBackground(note: note)
            }
            
            return note
        } catch {
            print("[NoteManager] Error creating note with mentions: \(error)")
            context.delete(note) // Clean up if save fails
            return nil
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
