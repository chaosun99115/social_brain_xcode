import Foundation
import CoreData

enum SeedDataSource {
    case local
    case remote
}

enum SeedDataScenario: String {
    case changedJob = "changed_job"
    case indie = "indie"
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
        // Use a deterministic UUID generation based on the identifier
        // This ensures the same identifier always gets the same UUID
        let uuidString = identifier.replacingOccurrences(of: "_", with: "-")
        if let existingUUID = entityUUIDs[identifier] {
            print("[SeedDataManager] 🔄 Reusing existing UUID for \(identifier): \(existingUUID)")
            return existingUUID
        }
        
        // For identifiers that don't already have a UUID, generate one deterministically
        let uuid = UUID(uuidString: uuidString) ?? UUID()
        entityUUIDs[identifier] = uuid
        print("[SeedDataManager] ✨ Generated new UUID for \(identifier): \(uuid)")
        return uuid
    }
    
    private func getUUID(for identifier: String) -> UUID? {
        return entityUUIDs[identifier]
    }
    
    // MARK: - Scenario Management
    
    private func loadScenarioData(from data: Data, scenario: SeedDataScenario) throws -> SeedData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct ScenarioContainer: Codable {
            let seed_data: [String: SeedData]
        }
        
        let container = try decoder.decode(ScenarioContainer.self, from: data)
        guard let scenarioData = container.seed_data[scenario.rawValue] else {
            print("[SeedDataManager] ❌ ERROR: Scenario '\(scenario.rawValue)' not found in seed data")
            throw NSError(domain: "SeedDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Scenario not found"])
        }
        
        return scenarioData
    }
    
    // MARK: - Store Management
    
    func deleteExistingStore(for context: NSManagedObjectContext) throws {
        print("\n[SeedDataManager] 🗑️ Deleting existing seed data...")
        
        // Instead of deleting the entire store, only delete specific entities
        let entityTypes = [
            "Note",
            "Contact",
            "ContactInsight",
            "NoteContactRelationship",
            "Circle",
            "CircleInsight",
            "CircleContactRelationship",
            "InsightCircleRelationship"
        ]
        
        for entityType in entityTypes {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityType)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                print("[SeedDataManager] ✅ Deleted existing \(entityType) entities")
            } catch {
                print("[SeedDataManager] ⚠️ Error deleting \(entityType) entities: \(error)")
                // Continue with other entities even if one fails
            }
        }
        
        // Save the context after batch deletes
        do {
            try context.save()
            print("[SeedDataManager] ✅ Saved context after deleting seed data")
        } catch {
            print("[SeedDataManager] ❌ Error saving context after deletion: \(error)")
            throw error
        }
    }
    
    // MARK: - Data Import
    
    func importSeedData(into context: NSManagedObjectContext, scenario: SeedDataScenario? = nil) async throws {
        print("\n[SeedDataManager] 🚀 Starting seed data import...")
        
        // Delete existing store before importing new data
        try deleteExistingStore(for: context)
        
        // Check if sample data already exists
        let noteFetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteFetchRequest.predicate = NSPredicate(format: "type == %d", 0) // Sample data has type 0
        let existingNotes: [Note]
        do {
            existingNotes = try context.fetch(noteFetchRequest)
            if !existingNotes.isEmpty {
                print("[SeedDataManager] ⚠️ Sample data already exists, aborting import")
                throw NSError(domain: "SeedDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sample data already exists"])
            }
        } catch {
            print("[SeedDataManager] ❌ Error checking existing notes: \(error)")
            throw error
        }
        
        // Load seed data
        let data: Data
        do {
            data = try await loadSeedData()
        } catch {
            print("[SeedDataManager] ❌ Error loading seed data: \(error)")
            throw error
        }
        
        // Parse seed data
        let seedData: SeedData
        do {
            if let scenario = scenario {
                seedData = try loadScenarioData(from: data, scenario: scenario)
            } else {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                seedData = try decoder.decode(SeedData.self, from: data)
            }
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("\n[SeedDataManager] 📄 Raw JSON Data:")
                print(jsonString)
            }
            print("\n[SeedDataManager] ❌ JSON Decoding Error: \(error)")
            throw error
        }
        
        // Clear previous UUID mapping
        entityUUIDs.removeAll()
        
        try await context.perform {
            print("\n[SeedDataManager] 📝 Creating contacts...")
            // Import Contacts
            for contactData in seedData.contacts {
                let contact = Contact(context: context)
                let contactUUID = self.generateAndStoreUUID(for: contactData.uniqueIdentifier)
                contact.contactId = contactUUID
                contact.name = contactData.name
                contact.type = contactData.type ?? 0
                contact.createdAt = contactData.createdAt
                contact.updatedAt = contactData.updatedAt
                contact.recordStatus = contactData.recordStatus
                print("[SeedDataManager] ✅ Created contact: \(contactData.name) with ID: \(contactUUID)")
            }
            
            // Import Notes
            for noteData in seedData.notes {
                let note = Note(context: context)
                let noteUUID = self.generateAndStoreUUID(for: noteData.uniqueIdentifier)
                note.noteId = noteUUID
                note.content = noteData.content
                note.type = noteData.type
                note.subType = noteData.subType
                note.updateCompleted = noteData.updateCompleted
                note.createdAt = noteData.createdAt
                note.updatedAt = noteData.updatedAt
                note.recordStatus = noteData.recordStatus
                note.isArchived = false
            }
            
            // Import Contact Insights
            for insightData in seedData.contactInsights {
                let insight = ContactInsight(context: context)
                let insightUUID = self.generateAndStoreUUID(for: insightData.uniqueIdentifier)
                insight.insightId = insightUUID
                insight.type = insightData.type  // Use Int16 directly
                insight.category = insightData.category
                insight.order = insightData.order  // Use Int16 directly
                insight.content = insightData.content
                insight.createdAt = insightData.createdAt
                insight.updatedAt = insightData.updatedAt
                insight.recordStatus = insightData.recordStatus
            }
            
            // Import Circles
            for circleData in seedData.circles {
                let circle = Circle(context: context)
                let circleUUID = self.generateAndStoreUUID(for: circleData.uniqueIdentifier)
                circle.circleId = circleUUID
                circle.name = circleData.name
                circle.type = circleData.type
                circle.createdAt = circleData.createdAt
                circle.updatedAt = circleData.updatedAt
                circle.recordStatus = circleData.recordStatus
            }

            // Import Circle Insights
            for insightData in seedData.circleInsights {
                let insight = CircleInsight(context: context)
                let insightUUID = self.generateAndStoreUUID(for: insightData.uniqueIdentifier)
                insight.insightId = insightUUID
                insight.type = insightData.type  // Use Int16 directly
                insight.category = insightData.category
                insight.subCategory = insightData.subCategory
                insight.order = insightData.order  // Already Int16
                insight.subOrder = insightData.subOrder  // Already Int16
                insight.content = insightData.content
                insight.createdAt = insightData.createdAt
                insight.updatedAt = insightData.updatedAt
                insight.recordStatus = insightData.recordStatus
            }

            // Save context after creating all entities
            do {
                try context.save()
                print("\n[SeedDataManager] 💾 Saved context after entity creation")
                
                // Validate contacts after creation
                print("\n[SeedDataManager] 🔍 Validating contacts after creation...")
                try self.validateContacts(in: context)
            } catch {
                print("[SeedDataManager] ❌ Error saving context after entity creation: \(error)")
                throw error
            }
            
            // Create Note-Contact Relationships
            var relationshipErrors = 0
            print("\n[SeedDataManager] 🔗 Creating note-contact relationships...")

            // First, fetch all notes and contacts to avoid repeated fetches
            let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
            let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
            let allNotes = try? context.fetch(noteRequest)
            let allContacts = try? context.fetch(contactRequest)

            print("[SeedDataManager] 📊 Found \(allNotes?.count ?? 0) notes and \(allContacts?.count ?? 0) contacts")

            // Create dictionaries for quick lookup
            var notesByUUID: [UUID: Note] = [:]
            var contactsByUUID: [UUID: Contact] = [:]

            allNotes?.forEach { note in
                if let noteId = note.noteId {
                    notesByUUID[noteId] = note
                    print("[SeedDataManager] 📝 Note: \(noteId) - \(note.content?.prefix(20) ?? "no content")")
                }
            }

            allContacts?.forEach { contact in
                if let contactId = contact.contactId {
                    contactsByUUID[contactId] = contact
                    print("[SeedDataManager] 👤 Contact: \(contactId) - \(contact.name ?? "unnamed")")
                }
            }

            // Process each relationship individually to better handle errors
            for relationshipData in seedData.noteContactRelationships {
                print("\n[SeedDataManager] 🔄 Processing relationship: note=\(relationshipData.noteIdentifier), contact=\(relationshipData.contactIdentifier)")
                
                let noteUUID = self.getUUID(for: relationshipData.noteIdentifier)
                let contactUUID = self.getUUID(for: relationshipData.contactIdentifier)
                
                print("[SeedDataManager] ℹ️ Generated UUIDs - note: \(noteUUID?.uuidString ?? "nil"), contact: \(contactUUID?.uuidString ?? "nil")")
                
                // Check if we have valid UUIDs and can find the entities
                guard let noteUUID = noteUUID,
                      let contactUUID = contactUUID else {
                    print("[SeedDataManager] ⚠️ Failed to find UUIDs for relationship")
                    if noteUUID == nil { print("  - Note UUID not found for: \(relationshipData.noteIdentifier)") }
                    if contactUUID == nil { print("  - Contact UUID not found for: \(relationshipData.contactIdentifier)") }
                    relationshipErrors += 1
                    continue
                }
                
                // Find the note and contact
                guard let note = notesByUUID[noteUUID],
                      let contact = contactsByUUID[contactUUID] else {
                    print("[SeedDataManager] ⚠️ Failed to find entities for relationship")
                    if notesByUUID[noteUUID] == nil { print("  - Note not found with UUID: \(noteUUID)") }
                    if contactsByUUID[contactUUID] == nil { print("  - Contact not found with UUID: \(contactUUID)") }
                    relationshipErrors += 1
                    continue
                }
                
                // Check if relationship already exists
                let existingRequest: NSFetchRequest<NoteContactRelationship> = NoteContactRelationship.fetchRequest()
                existingRequest.predicate = NSPredicate(format: "notes.noteId == %@ AND contacts.contactId == %@",
                                                      noteUUID as CVarArg, contactUUID as CVarArg)
                
                do {
                    let existingRelationships = try context.fetch(existingRequest)
                    if !existingRelationships.isEmpty {
                        print("[SeedDataManager] ℹ️ Relationship already exists, skipping")
                        continue
                    }
                    
                    // Create new relationship
                    let relationship = NoteContactRelationship(context: context)
                    relationship.relationshipId = UUID()
                    relationship.createdAt = relationshipData.createdAt
                    relationship.notes = note
                    relationship.contacts = contact
                    
                    print("[SeedDataManager] ✅ Created relationship: \(relationship.relationshipId?.uuidString ?? "nil")")
                    
                    // Save immediately after each relationship creation
                    try context.save()
                    print("[SeedDataManager] 💾 Saved relationship to context")
                    
                    // Verify the relationship was created correctly
                    if relationship.notes == nil || relationship.contacts == nil {
                        print("[SeedDataManager] ⚠️ Relationship verification failed after creation")
                        context.delete(relationship)
                        try context.save()
                        relationshipErrors += 1
                        continue
                    }
                    
                    // Double-check the relationship exists in the database
                    let verifyRequest: NSFetchRequest<NoteContactRelationship> = NoteContactRelationship.fetchRequest()
                    verifyRequest.predicate = NSPredicate(format: "relationshipId == %@", relationship.relationshipId! as CVarArg)
                    let verifyResults = try context.fetch(verifyRequest)
                    print("[SeedDataManager] 🔍 Verification: Found \(verifyResults.count) relationships after save")
                    
                } catch {
                    print("[SeedDataManager] ⚠️ Error creating relationship: \(error)")
                    relationshipErrors += 1
                    continue
                }
            }

            if relationshipErrors > 0 {
                print("[SeedDataManager] ⚠️ \(relationshipErrors) note-contact relationships failed to create")
            } else {
                print("[SeedDataManager] ✅ All note-contact relationships created successfully")
            }
            
            // Create Circle-Contact Relationships
            relationshipErrors = 0
            
            // First collect all valid relationships
            var validRelationships: [(Circle, Contact, Date)] = []
            for relationshipData in seedData.circleContactRelationships {
                let circleUUID = self.getUUID(for: relationshipData.circleIdentifier)
                let contactUUID = self.getUUID(for: relationshipData.contactIdentifier)
                
                if circleUUID == nil || contactUUID == nil {
                    relationshipErrors += 1
                    continue
                }
                
                let circleRequest: NSFetchRequest<Circle> = Circle.fetchRequest()
                circleRequest.predicate = NSPredicate(format: "circleId == %@", circleUUID! as CVarArg)
                
                let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                contactRequest.predicate = NSPredicate(format: "contactId == %@", contactUUID! as CVarArg)
                
                let circles = try? context.fetch(circleRequest)
                let contacts = try? context.fetch(contactRequest)
                
                guard let circle = circles?.first, let contact = contacts?.first else {
                    relationshipErrors += 1
                    continue
                }
                
                validRelationships.append((circle, contact, relationshipData.createdAt))
            }
            
            // Then create all relationships in a single batch
            for (circle, contact, createdAt) in validRelationships {
                let relationship = CircleContactRelationship(context: context)
                relationship.relationshipId = UUID()
                relationship.circles = circle
                relationship.contacts = contact
                relationship.createdAt = createdAt
            }
            
            // Save all relationships at once
            do {
                try context.save()
            } catch {
                relationshipErrors += validRelationships.count
            }
            
            if relationshipErrors > 0 {
                print("[SeedDataManager] ⚠️ \(relationshipErrors) circle-contact relationships failed to create")
            }

            // Create Insight-Circle Relationships
            relationshipErrors = 0
            for relationshipData in seedData.insightCircleRelationships {
                let circleUUID = self.getUUID(for: relationshipData.circleIdentifier)
                let insightUUID = self.getUUID(for: relationshipData.insightIdentifier)
                
                if circleUUID == nil || insightUUID == nil {
                    relationshipErrors += 1
                    continue
                }
                
                let circleRequest: NSFetchRequest<Circle> = Circle.fetchRequest()
                circleRequest.predicate = NSPredicate(format: "circleId == %@", circleUUID! as CVarArg)
                let insightRequest: NSFetchRequest<CircleInsight> = CircleInsight.fetchRequest()
                insightRequest.predicate = NSPredicate(format: "insightId == %@", insightUUID! as CVarArg)
                
                let circles = try? context.fetch(circleRequest)
                let insights = try? context.fetch(insightRequest)
                
                guard let circle = circles?.first, let insight = insights?.first else {
                    relationshipErrors += 1
                    continue
                }
                
                let relationship = InsightCircleRelationship(context: context)
                relationship.relationshipId = UUID()
                relationship.createdAt = relationshipData.createdAt
                relationship.circles = circle
                relationship.insights = insight
            }
            if relationshipErrors > 0 {
                print("[SeedDataManager] ⚠️ \(relationshipErrors) insight-circle relationships failed to create")
            }
            
            // Remove debug logging of relationships
            let allRelationshipsRequest: NSFetchRequest<InsightCircleRelationship> = InsightCircleRelationship.fetchRequest()
            // Just fetch the data but don't log it
            _ = try? context.fetch(allRelationshipsRequest)
            
            // Save final context
            do {
                try context.save()
            } catch {
                print("[SeedDataManager] ❌ Error saving final context: \(error)")
                throw error
            }

            // Final validation before completion
            print("\n[SeedDataManager] 🔍 Performing final validation...")
            try self.validateContacts(in: context)
            
            print("\n[SeedDataManager] ✅ Seed data import completed successfully")
        }
    }

    // Add validation function
    private func validateContacts(in context: NSManagedObjectContext) throws {
        let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        let allContacts = try context.fetch(contactRequest)
        
        // Check for nil contactIds
        let contactsWithNilId = allContacts.filter { $0.contactId == nil }
        if !contactsWithNilId.isEmpty {
            print("\n[SeedDataManager] ⚠️ VALIDATION ERROR: Found \(contactsWithNilId.count) contacts with nil contactId:")
            for contact in contactsWithNilId {
                print("  - Contact: \(contact.name ?? "unnamed")")
            }
        }
        
        // Check for duplicate contactIds
        let contactIds = allContacts.compactMap { $0.contactId }
        let uniqueIds = Set(contactIds)
        if contactIds.count != uniqueIds.count {
            print("\n[SeedDataManager] ⚠️ VALIDATION ERROR: Found duplicate contactIds")
            let duplicates = Dictionary(grouping: contactIds) { $0 }
                .filter { $1.count > 1 }
                .keys
            for duplicateId in duplicates {
                print("  - Duplicate ID: \(duplicateId)")
                let contactsWithId = allContacts.filter { $0.contactId == duplicateId }
                for contact in contactsWithId {
                    print("    * Contact: \(contact.name ?? "unnamed")")
                }
            }
        }
        
        // Verify relationships
        for contact in allContacts {
            guard let contactId = contact.contactId else { continue }
            let relationshipRequest: NSFetchRequest<NoteContactRelationship> = NoteContactRelationship.fetchRequest()
            relationshipRequest.predicate = NSPredicate(format: "contacts.contactId == %@", contactId as CVarArg)
            let relationships = try context.fetch(relationshipRequest)
            
            if relationships.isEmpty {
                print("[SeedDataManager] ℹ️ Contact \(contact.name ?? "unnamed") (\(contactId)) has no note relationships")
            }
        }
    }
}

// MARK: - Seed Data Models

struct SeedData: Codable {
    let notes: [NoteData]
    let contacts: [ContactData]
    let contactInsights: [ContactInsightData]
    let noteContactRelationships: [NoteContactRelationshipData]
    let circles: [CircleData]
    let circleInsights: [CircleInsightData]
    let circleContactRelationships: [CircleContactRelationshipData]
    let insightCircleRelationships: [InsightCircleRelationshipData]
}

struct NoteData: Codable {
    let uniqueIdentifier: String  // Used to generate and track UUID
    let content: String
    let type: Int16
    let subType: Int16  // Added subType field
    let updateCompleted: Int16
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
}

struct ContactData: Codable {
    let uniqueIdentifier: String  // Used to generate and track UUID
    let name: String
    let type: Int16?
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
    
    // Custom decoding to provide default value for type
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uniqueIdentifier = try container.decode(String.self, forKey: .uniqueIdentifier)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(Int16.self, forKey: .type) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        recordStatus = try container.decode(Int16.self, forKey: .recordStatus)
    }
    
    // Custom encoding to ensure type is always included
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uniqueIdentifier, forKey: .uniqueIdentifier)
        try container.encode(name, forKey: .name)
        try container.encode(type ?? 0, forKey: .type)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(recordStatus, forKey: .recordStatus)
    }
    
    private enum CodingKeys: String, CodingKey {
        case uniqueIdentifier, name, type, createdAt, updatedAt, recordStatus
    }
}

struct ContactInsightData: Codable {
    let uniqueIdentifier: String  // Used to generate and track UUID
    let type: Int16
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

struct CircleData: Codable {
    let uniqueIdentifier: String  // Used to generate and track UUID
    let name: String
    let type: Int16
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
}

struct CircleInsightData: Codable {
    let uniqueIdentifier: String  // Used to generate and track UUID
    let type: Int16
    let category: String
    let subCategory: String
    let order: Int16
    let subOrder: Int16
    let content: String
    let createdAt: Date
    let updatedAt: Date  // Keep as Date to match Core Data model
    let recordStatus: Int16
}

struct CircleContactRelationshipData: Codable {
    let createdAt: Date
    let contactIdentifier: String // References the uniqueIdentifier of the contact
    let circleIdentifier: String  // References the uniqueIdentifier of the circle
}

struct InsightCircleRelationshipData: Codable {
    let createdAt: Date
    let circleIdentifier: String  // References the uniqueIdentifier of the circle
    let insightIdentifier: String // References the uniqueIdentifier of the insight
} 