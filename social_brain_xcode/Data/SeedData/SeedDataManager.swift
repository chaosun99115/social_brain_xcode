import Foundation
import CoreData

enum SeedDataSource {
    case local
    case remote
}

final class SeedDataManager {
    static let shared = SeedDataManager()
    
    // Configuration
    private var dataSource: SeedDataSource = .local
    private let localSeedDataURL = Bundle.main.url(forResource: "seed_data", withExtension: "json")!
    private let remoteSeedDataURL = URL(string: "https://your-api-endpoint/seed_data.json")! // Replace with actual remote URL
    
    // Temporary storage for entity relationships
    private var entityUUIDs: [String: UUID] = [:] // Stores UUIDs for each entity by their unique identifier
    
    private init() {}
    
    // MARK: - Configuration
    
    func setDataSource(_ source: SeedDataSource) {
        self.dataSource = source
    }
    
    // MARK: - Data Loading
    
    func loadSeedData() async throws -> Data {
        switch dataSource {
        case .local:
            return try loadLocalSeedData()
        case .remote:
            return try await loadRemoteSeedData()
        }
    }
    
    private func loadLocalSeedData() throws -> Data {
        return try Data(contentsOf: localSeedDataURL)
    }
    
    private func loadRemoteSeedData() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: remoteSeedDataURL)
        return data
    }
    
    // MARK: - UUID Management
    
    private func generateAndStoreUUID(for identifier: String) -> UUID {
        let uuid = UUID()
        entityUUIDs[identifier] = uuid
        return uuid
    }
    
    private func getUUID(for identifier: String) -> UUID? {
        return entityUUIDs[identifier]
    }
    
    // MARK: - Core Data Import
    
    func importSeedData(into context: NSManagedObjectContext) async throws {
        print("\n[SeedDataManager] Starting seed data import...")
        
        // Check if sample data already exists
        let noteFetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteFetchRequest.predicate = NSPredicate(format: "type == %d", 0) // Sample data has type 0
        
        let existingNotes = try context.fetch(noteFetchRequest)
        print("[SeedDataManager] Found \(existingNotes.count) existing notes with type 0")
        if !existingNotes.isEmpty {
            print("[SeedDataManager] Sample data already exists, aborting import")
            throw NSError(domain: "SeedDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sample data already exists"])
        }
        
        print("[SeedDataManager] Loading seed data...")
        let data = try await loadSeedData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let seedData = try decoder.decode(SeedData.self, from: data)
        print("[SeedDataManager] Successfully decoded seed data:")
        print("- Notes: \(seedData.notes.count)")
        print("- Contacts: \(seedData.contacts.count)")
        print("- Contact Insights: \(seedData.contactInsights.count)")
        print("- Note-Contact Relationships: \(seedData.noteContactRelationships.count)")
        print("- Insight-Contact Relationships: \(seedData.insightContactRelationships.count)")
        
        // Clear previous UUID mapping
        entityUUIDs.removeAll()
        
        try await context.perform {
            print("\n[SeedDataManager] Starting entity creation...")
            
            // Import Notes
            print("\n[SeedDataManager] Importing notes...")
            for noteData in seedData.notes {
                let note = Note(context: context)
                let noteUUID = self.generateAndStoreUUID(for: noteData.uniqueIdentifier)
                note.noteId = noteUUID
                note.content = noteData.content
                note.type = noteData.type
                note.updateCompleted = noteData.updateCompleted
                note.createdAt = noteData.createdAt
                note.updatedAt = noteData.updatedAt
                note.recordStatus = noteData.recordStatus
                note.isArchived = false
                print("- Created note: \(noteUUID) with type \(noteData.type)")
            }
            
            // Import Contacts
            print("\n[SeedDataManager] Importing contacts...")
            for contactData in seedData.contacts {
                let contact = Contact(context: context)
                let contactUUID = self.generateAndStoreUUID(for: contactData.uniqueIdentifier)
                contact.contactId = contactUUID
                contact.name = contactData.name
                contact.createdAt = contactData.createdAt
                contact.updatedAt = contactData.updatedAt
                contact.recordStatus = contactData.recordStatus
                print("- Created contact: \(contactUUID) with name \(contactData.name)")
            }
            
            // Import Contact Insights
            print("\n[SeedDataManager] Importing contact insights...")
            for insightData in seedData.contactInsights {
                let insight = ContactInsight(context: context)
                let insightUUID = self.generateAndStoreUUID(for: insightData.uniqueIdentifier)
                insight.insightId = insightUUID
                insight.type = insightData.type
                insight.category = insightData.category
                insight.order = String(insightData.order)
                insight.content = insightData.content
                insight.createdAt = insightData.createdAt
                insight.updatedAt = insightData.updatedAt
                insight.recordStatus = insightData.recordStatus
                print("- Created insight: \(insightUUID) with type \(insightData.type)")
            }
            
            // Save context after creating all entities
            print("\n[SeedDataManager] Saving context after entity creation...")
            try context.save()
            print("[SeedDataManager] Context saved successfully")
            
            // Create Note-Contact Relationships
            print("\n[SeedDataManager] Creating note-contact relationships...")
            for relationshipData in seedData.noteContactRelationships {
                let relationship = NoteContactRelationship(context: context)
                relationship.relationshipId = UUID()
                relationship.createdAt = relationshipData.createdAt
                
                // Fetch note and contact using their UUIDs
                let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
                noteRequest.predicate = NSPredicate(format: "noteId == %@", self.getUUID(for: relationshipData.noteIdentifier)! as CVarArg)
                
                let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                contactRequest.predicate = NSPredicate(format: "contactId == %@", self.getUUID(for: relationshipData.contactIdentifier)! as CVarArg)
                
                let notes = try context.fetch(noteRequest)
                let contacts = try context.fetch(contactRequest)
                
                guard let note = notes.first, let contact = contacts.first else {
                    print("[SeedDataManager] Warning: Could not find note or contact for relationship")
                    print("- Note Identifier: \(relationshipData.noteIdentifier)")
                    print("- Contact Identifier: \(relationshipData.contactIdentifier)")
                    continue
                }
                
                relationship.notes = note
                relationship.contacts = contact
                print("- Created relationship between note \(note.noteId?.uuidString ?? "nil") and contact \(contact.name ?? "unnamed")")
            }
            
            // Create Insight-Contact Relationships
            print("\n[SeedDataManager] Creating insight-contact relationships...")
            for relationshipData in seedData.insightContactRelationships {
                let relationship = InsightContactRelationship(context: context)
                relationship.relationshipId = UUID()
                relationship.createdAt = relationshipData.createdAt
                
                // Fetch contact and insight using their UUIDs
                let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                contactRequest.predicate = NSPredicate(format: "contactId == %@", self.getUUID(for: relationshipData.contactIdentifier)! as CVarArg)
                
                let insightRequest: NSFetchRequest<ContactInsight> = ContactInsight.fetchRequest()
                insightRequest.predicate = NSPredicate(format: "insightId == %@", self.getUUID(for: relationshipData.insightIdentifier)! as CVarArg)
                
                let contacts = try context.fetch(contactRequest)
                let insights = try context.fetch(insightRequest)
                
                guard let contact = contacts.first, let insight = insights.first else {
                    print("[SeedDataManager] Warning: Could not find contact or insight for relationship")
                    print("- Contact Identifier: \(relationshipData.contactIdentifier)")
                    print("- Insight Identifier: \(relationshipData.insightIdentifier)")
                    continue
                }
                
                relationship.contacts = contact
                relationship.insights = insight
                print("- Created relationship between insight \(insight.insightId?.uuidString ?? "nil") and contact \(contact.name ?? "unnamed")")
            }
            
            print("\n[SeedDataManager] Saving final context...")
            try context.save()
            print("[SeedDataManager] Final context save successful")
            
            // Verify the data was imported correctly
            print("\n[SeedDataManager] Verifying imported data...")
            let finalNoteRequest: NSFetchRequest<Note> = Note.fetchRequest()
            let finalNotes = try context.fetch(finalNoteRequest)
            print("- Total notes in database: \(finalNotes.count)")
            for note in finalNotes {
                print("- Note: \(note.noteId?.uuidString ?? "nil")")
                print("  Content: \(note.content ?? "nil")")
                print("  Type: \(note.type)")
                print("  Is Archived: \(note.isArchived)")
                if let relationships = note.contacts as? Set<NoteContactRelationship> {
                    for relationship in relationships {
                        print("  Has Contact: \(relationship.contacts?.name ?? "nil")")
                    }
                } else {
                    print("  No Contact Relationship")
                }
            }
            
            // Verify Contact Insights
            print("\n[SeedDataManager] Verifying contact insights...")
            let finalInsightRequest: NSFetchRequest<ContactInsight> = ContactInsight.fetchRequest()
            let finalInsights = try context.fetch(finalInsightRequest)
            print("- Total insights in database: \(finalInsights.count)")
            for insight in finalInsights {
                print("- Insight: \(insight.insightId?.uuidString ?? "nil")")
                print("  Type: \(insight.type ?? "nil")")
                print("  Category: \(insight.category ?? "nil")")
                print("  Content: \(insight.content ?? "nil")")
                if let relationships = insight.contacts as? Set<InsightContactRelationship> {
                    for relationship in relationships {
                        print("  Has Contact: \(relationship.contacts?.name ?? "nil")")
                    }
                } else {
                    print("  No Contact Relationship")
                }
            }
        }
        
        print("\n[SeedDataManager] Seed data import completed")
    }
}

// MARK: - Seed Data Models

struct SeedData: Codable {
    let notes: [NoteData]
    let contacts: [ContactData]
    let contactInsights: [ContactInsightData]
    let noteContactRelationships: [NoteContactRelationshipData]
    let insightContactRelationships: [InsightContactRelationshipData]
}

struct NoteData: Codable {
    let uniqueIdentifier: String  // Used to generate and track UUID
    let content: String
    let type: Int16
    let updateCompleted: Int16
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
}

struct ContactData: Codable {
    let uniqueIdentifier: String  // Used to generate and track UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
}

struct ContactInsightData: Codable {
    let uniqueIdentifier: String  // Used to generate and track UUID
    let type: String
    let category: String
    let order: Int16
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
}

struct NoteContactRelationshipData: Codable {
    let createdAt: Date
    let noteIdentifier: String    // References the uniqueIdentifier of the note
    let contactIdentifier: String // References the uniqueIdentifier of the contact
}

struct InsightContactRelationshipData: Codable {
    let createdAt: Date
    let contactIdentifier: String // References the uniqueIdentifier of the contact
    let insightIdentifier: String // References the uniqueIdentifier of the insight
} 