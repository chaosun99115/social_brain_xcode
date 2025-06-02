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
            return existingUUID
        }
        
        // For identifiers that don't already have a UUID, generate one deterministically
        let uuid = UUID(uuidString: uuidString) ?? UUID()
        entityUUIDs[identifier] = uuid
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
        // print("\n[SeedDataManager] 🗑️ Deleting existing store...")
        
        guard let coordinator = context.persistentStoreCoordinator,
              let store = coordinator.persistentStores.first,
              let storeURL = store.url else {
            print("[SeedDataManager] ⚠️ No existing store found")
            return
        }
        
        do {
            // Remove the store from coordinator
            try coordinator.remove(store)
            
            // Delete the store file
            try FileManager.default.removeItem(at: storeURL)
            // print("[SeedDataManager] ✅ Store file deleted successfully")
            
            // Add a new store to the coordinator
            let options = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]
            
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
            // print("[SeedDataManager] ✅ New store added to coordinator")
            
        } catch {
            print("[SeedDataManager] ❌ Error managing store: \(error)")
            throw error
        }
    }
    
    // MARK: - Data Import
    
    func importSeedData(into context: NSManagedObjectContext, scenario: SeedDataScenario? = nil) async throws {
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
            // Import Notes
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
            }
            
            // Import Contacts
            for contactData in seedData.contacts {
                let contact = Contact(context: context)
                let contactUUID = self.generateAndStoreUUID(for: contactData.uniqueIdentifier)
                contact.contactId = contactUUID
                contact.name = contactData.name
                contact.type = contactData.type ?? 0  // Unwrap the optional with a default value of 0
                contact.createdAt = contactData.createdAt
                contact.updatedAt = contactData.updatedAt
                contact.recordStatus = contactData.recordStatus
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
            } catch {
                print("[SeedDataManager] ❌ Error saving context after entity creation: \(error)")
                throw error
            }
            
            // Create Note-Contact Relationships
            var relationshipErrors = 0

            // First, fetch all notes and contacts to avoid repeated fetches
            let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
            let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
            let allNotes = try? context.fetch(noteRequest)
            let allContacts = try? context.fetch(contactRequest)

            // Create dictionaries for quick lookup
            var notesByUUID: [UUID: Note] = [:]
            var contactsByUUID: [UUID: Contact] = [:]

            allNotes?.forEach { note in
                if let noteId = note.noteId {
                    notesByUUID[noteId] = note
                }
            }

            allContacts?.forEach { contact in
                if let contactId = contact.contactId {
                    contactsByUUID[contactId] = contact
                }
            }

            // Group relationships by contact for batch processing
            var relationshipsByContact: [UUID: [(Note, Date)]] = [:]

            // First pass: validate and group relationships
            for relationshipData in seedData.noteContactRelationships {
                let noteUUID = self.getUUID(for: relationshipData.noteIdentifier)
                let contactUUID = self.getUUID(for: relationshipData.contactIdentifier)
                
                guard let noteUUID = noteUUID,
                      let contactUUID = contactUUID,
                      let note = notesByUUID[noteUUID],
                      let contact = contactsByUUID[contactUUID] else {
                    relationshipErrors += 1
                    continue
                }
                
                // Group by contact for batch processing
                relationshipsByContact[contactUUID, default: []].append((note, relationshipData.createdAt))
            }

            // Second pass: create relationships in batches per contact
            for (contactUUID, noteData) in relationshipsByContact {
                guard let contact = contactsByUUID[contactUUID] else { continue }
                
                // Create all relationships for this contact
                let relationships = noteData.map { (note, createdAt) -> NoteContactRelationship in
                    let relationship = NoteContactRelationship(context: context)
                    relationship.relationshipId = UUID()
                    relationship.createdAt = createdAt
                    
                    // Set both sides of the relationship
                    relationship.notes = note
                    relationship.contacts = contact
                    
                    // Add to contact's notes set
                    contact.addToNotes(relationship)
                    
                    return relationship
                }
                
                // Save relationships for this contact
                do {
                    // Verify relationships before saving
                    for relationship in relationships {
                        guard relationship.notes != nil && relationship.contacts != nil else {
                            throw NSError(domain: "SeedDataManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid relationship state"])
                        }
                    }
                    
                    // Save this batch
                    try context.save()
                    
                    // Verify relationships after saving
                    for relationship in relationships {
                        guard relationship.notes != nil && relationship.contacts != nil else {
                            throw NSError(domain: "SeedDataManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Relationship lost references"])
                        }
                    }
                } catch {
                    relationshipErrors += noteData.count
                    
                    // Rollback this batch
                    context.rollback()
                    
                    // Try individual saves as fallback
                    for (note, createdAt) in noteData {
                        do {
                            let relationship = NoteContactRelationship(context: context)
                            relationship.relationshipId = UUID()
                            relationship.createdAt = createdAt
                            relationship.notes = note
                            relationship.contacts = contact
                            contact.addToNotes(relationship)
                            
                            try context.save()
                        } catch {
                            relationshipErrors += 1
                        }
                    }
                }
            }

            if relationshipErrors > 0 {
                print("[SeedDataManager] ⚠️ \(relationshipErrors) note-contact relationships failed to create")
            }
            
            // Create Insight-Contact Relationships
            relationshipErrors = 0
            for relationshipData in seedData.insightContactRelationships {
                let contactUUID = self.getUUID(for: relationshipData.contactIdentifier)
                let insightUUID = self.getUUID(for: relationshipData.insightIdentifier)
                
                if contactUUID == nil || insightUUID == nil {
                    relationshipErrors += 1
                    continue
                }
                
                let relationship = InsightContactRelationship(context: context)
                relationship.relationshipId = UUID()
                relationship.createdAt = relationshipData.createdAt  // Date from seed data
                
                let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                contactRequest.predicate = NSPredicate(format: "contactId == %@", contactUUID! as CVarArg)
                
                let insightRequest: NSFetchRequest<ContactInsight> = ContactInsight.fetchRequest()
                insightRequest.predicate = NSPredicate(format: "insightId == %@", insightUUID! as CVarArg)
                
                let contacts = try? context.fetch(contactRequest)
                let insights = try? context.fetch(insightRequest)
                
                guard let contact = contacts?.first, let insight = insights?.first else {
                    relationshipErrors += 1
                    continue
                }
                
                relationship.contacts = contact
                relationship.insights = insight
            }
            if relationshipErrors > 0 {
                print("[SeedDataManager] ⚠️ \(relationshipErrors) insight-contact relationships failed to create")
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
        }
    }
}

// MARK: - Seed Data Models

struct SeedData: Codable {
    let notes: [NoteData]
    let contacts: [ContactData]
    let contactInsights: [ContactInsightData]
    let noteContactRelationships: [NoteContactRelationshipData]
    let insightContactRelationships: [InsightContactRelationshipData]
    let circles: [CircleData]
    let circleInsights: [CircleInsightData]
    let circleContactRelationships: [CircleContactRelationshipData]
    let insightCircleRelationships: [InsightCircleRelationshipData]
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

struct InsightContactRelationshipData: Codable {
    let createdAt: Date
    let contactIdentifier: String // References the uniqueIdentifier of the contact
    let insightIdentifier: String // References the uniqueIdentifier of the insight
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