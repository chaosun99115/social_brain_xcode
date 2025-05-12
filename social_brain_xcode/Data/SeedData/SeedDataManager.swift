import Foundation
import CoreData

enum SeedDataSource {
    case local
    case remote
}

enum SeedDataScenario: String {
    case changedJob = "changed_job"
    case changedSchool = "changed_school"
    case careerPivot = "career_pivot"
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
    
    // MARK: - Scenario Management
    
    private func loadScenarioData(from data: Data, scenario: SeedDataScenario) throws -> SeedData {
        print("\n[SeedDataManager] Loading scenario data for: \(scenario.rawValue)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct ScenarioContainer: Codable {
            let scenarios: [String: SeedData]
        }
        
        print("[SeedDataManager] Decoding JSON data...")
        let container = try decoder.decode(ScenarioContainer.self, from: data)
        guard let scenarioData = container.scenarios[scenario.rawValue] else {
            print("[SeedDataManager] ❌ ERROR: Scenario '\(scenario.rawValue)' not found in seed data")
            throw NSError(domain: "SeedDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Scenario not found"])
        }
        
        print("[SeedDataManager] ✅ Successfully loaded scenario data:")
        print("- Found \(scenarioData.notes.count) notes")
        print("- Found \(scenarioData.contacts.count) contacts")
        print("- Found \(scenarioData.contactInsights.count) insights")
        return scenarioData
    }
    
    // MARK: - Core Data Import
    
    func importSeedData(into context: NSManagedObjectContext, scenario: SeedDataScenario? = nil) async throws {
        print("\n[SeedDataManager] ===== Starting Seed Data Import =====")
        print("[SeedDataManager] Mode: \(scenario?.rawValue ?? "Full Import")")
        
        // Check if sample data already exists
        let noteFetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteFetchRequest.predicate = NSPredicate(format: "type == %d", 0) // Sample data has type 0
        let existingNotes: [Note]
        do {
            existingNotes = try context.fetch(noteFetchRequest)
            print("[SeedDataManager] 📊 Found \(existingNotes.count) existing sample notes")
            if !existingNotes.isEmpty {
                print("[SeedDataManager] ⚠️ Sample data already exists, aborting import")
                throw NSError(domain: "SeedDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sample data already exists"])
            }
        } catch {
            print("[SeedDataManager] ❌ Error checking existing notes: \(error)")
            throw error
        }
        
        print("\n[SeedDataManager] 📥 Loading seed data...")
        let data: Data
        do {
            data = try await loadSeedData()
            print("[SeedDataManager] ✅ Loaded seed data file (\(data.count) bytes)")
        } catch {
            print("[SeedDataManager] ❌ Error loading seed data: \(error)")
            throw error
        }
        
        let seedData: SeedData
        do {
            if let scenario = scenario {
                print("\n[SeedDataManager] 🎯 Loading specific scenario: \(scenario.rawValue)")
                seedData = try loadScenarioData(from: data, scenario: scenario)
            } else {
                print("\n[SeedDataManager] 📦 Loading complete seed data")
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                seedData = try decoder.decode(SeedData.self, from: data)
            }
            
            print("\n[SeedDataManager] 📊 Data Summary:")
            print("- Notes: \(seedData.notes.count)")
            print("- Contacts: \(seedData.contacts.count)")
            print("- Contact Insights: \(seedData.contactInsights.count)")
            print("- Note-Contact Relationships: \(seedData.noteContactRelationships.count)")
            print("- Insight-Contact Relationships: \(seedData.insightContactRelationships.count)")
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
        print("\n[SeedDataManager] 🔄 Starting entity creation...")
        
        try await context.perform {
            // Import Notes
            print("\n[SeedDataManager] 📝 Importing \(seedData.notes.count) notes...")
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
            print("[SeedDataManager] ✅ Notes imported")
            
            // Import Contacts
            print("\n[SeedDataManager] 👥 Importing \(seedData.contacts.count) contacts...")
            for contactData in seedData.contacts {
                let contact = Contact(context: context)
                let contactUUID = self.generateAndStoreUUID(for: contactData.uniqueIdentifier)
                contact.contactId = contactUUID
                contact.name = contactData.name
                contact.createdAt = contactData.createdAt
                contact.updatedAt = contactData.updatedAt
                contact.recordStatus = contactData.recordStatus
            }
            print("[SeedDataManager] ✅ Contacts imported")
            
            // Import Contact Insights
            print("\n[SeedDataManager] 💡 Importing \(seedData.contactInsights.count) insights...")
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
            }
            print("[SeedDataManager] ✅ Insights imported")
            
            // Save context after creating all entities
            print("\n[SeedDataManager] 💾 Saving context after entity creation...")
            do {
                try context.save()
                print("[SeedDataManager] ✅ Context saved successfully")
            } catch {
                print("[SeedDataManager] ❌ Error saving context after entity creation: \(error)")
                throw error
            }
            
            // Create Note-Contact Relationships
            print("\n[SeedDataManager] 🔗 Creating \(seedData.noteContactRelationships.count) note-contact relationships...")
            var relationshipErrors = 0
            for relationshipData in seedData.noteContactRelationships {
                let noteUUID = self.getUUID(for: relationshipData.noteIdentifier)
                let contactUUID = self.getUUID(for: relationshipData.contactIdentifier)
                
                if noteUUID == nil || contactUUID == nil {
                    relationshipErrors += 1
                    continue
                }
                
                let relationship = NoteContactRelationship(context: context)
                relationship.relationshipId = UUID()
                relationship.createdAt = relationshipData.createdAt
                
                let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
                noteRequest.predicate = NSPredicate(format: "noteId == %@", noteUUID! as CVarArg)
                
                let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                contactRequest.predicate = NSPredicate(format: "contactId == %@", contactUUID! as CVarArg)
                
                let notes = try? context.fetch(noteRequest)
                let contacts = try? context.fetch(contactRequest)
                
                guard let note = notes?.first, let contact = contacts?.first else {
                    relationshipErrors += 1
                    continue
                }
                
                relationship.notes = note
                relationship.contacts = contact
            }
            if relationshipErrors > 0 {
                print("[SeedDataManager] ⚠️ \(relationshipErrors) note-contact relationships failed to create")
            }
            print("[SeedDataManager] ✅ Note-contact relationships created")
            
            // Create Insight-Contact Relationships
            print("\n[SeedDataManager] 🔗 Creating \(seedData.insightContactRelationships.count) insight-contact relationships...")
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
                relationship.createdAt = relationshipData.createdAt
                
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
            print("[SeedDataManager] ✅ Insight-contact relationships created")
            
            print("\n[SeedDataManager] 💾 Saving final context...")
            do {
                try context.save()
                print("[SeedDataManager] ✅ Final context save successful")
            } catch {
                print("[SeedDataManager] ❌ Error saving final context: \(error)")
                throw error
            }
            
            // Verify the data was imported correctly
            print("\n[SeedDataManager] 🔍 Verifying imported data...")
            let finalNoteRequest: NSFetchRequest<Note> = Note.fetchRequest()
            let finalNotes = (try? context.fetch(finalNoteRequest)) ?? []
            print("\n[SeedDataManager] 📊 Final Data Summary:")
            print("- Total notes in database: \(finalNotes.count)")
        }
        
        print("\n[SeedDataManager] ===== Seed Data Import Completed =====")
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