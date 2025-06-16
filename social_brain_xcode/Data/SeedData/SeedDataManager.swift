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
        let uuidString = identifier.replacingOccurrences(of: "_", with: "-")
        if let existingUUID = entityUUIDs[identifier] {
            return existingUUID
        }
        
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
            throw NSError(domain: "SeedDataManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Scenario not found"])
        }
        
        return scenarioData
    }
    
    /// Switches to a different sample data scenario while preserving user data
    func switchToScenario(_ scenario: SeedDataScenario, in context: NSManagedObjectContext) async throws {
        // Import the new scenario data - this will automatically clean up existing sample data
        try await importSeedData(into: context, scenario: scenario)
    }
    
    /// Removes sample data while keeping user data
    func removeSampleData(from context: NSManagedObjectContext) throws {
        try deleteExistingStore(for: context)
    }
    
    /// Gets the current sample data scenario (if any)
    func getCurrentScenario(in context: NSManagedObjectContext) throws -> SeedDataScenario? {
        // This is a simplified implementation - in a real app, you might want to store
        // the current scenario in UserDefaults or as a separate entity
        let sampleData = try fetchSampleData(in: context)
        if !sampleData.notes.isEmpty {
            // Check if it matches known scenarios by examining the data
            // This is a basic implementation - you might want to add a scenario identifier
            // to your data model for more accurate detection
            return .changedJob // Default assumption
        }
        return nil
    }
    
    // MARK: - Store Management
    
    func deleteExistingStore(for context: NSManagedObjectContext) throws {
        // Only delete sample data (type == 0), keep user data (type != 0)
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
            
            // For entities that have a 'type' attribute, only delete those with type == 0
            if entityType == "Note" || entityType == "Contact" || entityType == "Circle" {
                fetchRequest.predicate = NSPredicate(format: "type == %d", 0)
                
                do {
                    let count = try context.count(for: fetchRequest)
                    if count > 0 {
                        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                        try context.execute(deleteRequest)
                    }
                } catch {
                    // Continue with other entities even if one fails
                }
            } else {
                // For other entities, we need to check if they're related to sample data
                // This is more complex and will be handled in the import logic
                continue
            }
        }
        
        // Clean up orphaned relationships (those pointing to deleted sample data)
        try cleanupOrphanedRelationships(in: context)
    }
    
    private func cleanupOrphanedRelationships(in context: NSManagedObjectContext) throws {
        // Ensure we're on the correct queue for this context
        guard context.concurrencyType == .mainQueueConcurrencyType || 
              context.concurrencyType == .privateQueueConcurrencyType else {
            throw NSError(domain: "SeedDataManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid context concurrency type"])
        }
        
        var totalDeleted = 0
        
        // Use batch delete requests instead of individual deletions to avoid collection mutation issues
        
        // Clean up NoteContactRelationships that reference deleted notes or contacts
        let noteContactRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest<NSFetchRequestResult>(entityName: "NoteContactRelationship")
        noteContactRequest.predicate = NSPredicate(format: "notes == nil OR contacts == nil")
        
        do {
            let count = try context.count(for: noteContactRequest)
            if count > 0 {
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: noteContactRequest)
                try context.execute(deleteRequest)
                totalDeleted += count
            }
        } catch {
            // Continue with other deletions even if one fails
        }
        
        // Clean up CircleContactRelationships that reference deleted circles or contacts
        let circleContactRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest<NSFetchRequestResult>(entityName: "CircleContactRelationship")
        circleContactRequest.predicate = NSPredicate(format: "circles == nil OR contacts == nil")
        
        do {
            let count = try context.count(for: circleContactRequest)
            if count > 0 {
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: circleContactRequest)
                try context.execute(deleteRequest)
                totalDeleted += count
            }
        } catch {
            // Continue with other deletions even if one fails
        }
        
        // Clean up InsightCircleRelationships that reference deleted circles or insights
        let insightCircleRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest<NSFetchRequestResult>(entityName: "InsightCircleRelationship")
        insightCircleRequest.predicate = NSPredicate(format: "circles == nil OR insights == nil")
        
        do {
            let count = try context.count(for: insightCircleRequest)
            if count > 0 {
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: insightCircleRequest)
                try context.execute(deleteRequest)
                totalDeleted += count
            }
        } catch {
            // Continue with other deletions even if one fails
        }
    }
    
    // MARK: - Data Import
    
    func importSeedData(into context: NSManagedObjectContext, scenario: SeedDataScenario? = nil) async throws {
        // Delete only sample data (type == 0) and keep user data (type != 0)
        // This will clean up any existing sample data before importing new data
        try deleteExistingStore(for: context)
        
        let data: Data
        do {
            data = try await loadSeedData()
        } catch {
            throw error
        }
        
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
            throw error
        }
        
        entityUUIDs.removeAll()
        
        try await context.perform {
            // Import Contacts (sample data with type == 0)
            for contactData in seedData.contacts {
                let contact = Contact(context: context)
                let contactUUID = self.generateAndStoreUUID(for: contactData.uniqueIdentifier)
                contact.contactId = contactUUID
                contact.name = contactData.name
                contact.type = contactData.type ?? 0
                contact.birthday = contactData.birthday
                contact.tel = contactData.tel
                contact.memo = contactData.memo
                contact.createdAt = contactData.createdAt
                contact.updatedAt = contactData.updatedAt
                contact.recordStatus = contactData.recordStatus
                contact.isArchived = false
            }
            
            // Import Notes (sample data with type == 0)
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
            
            // Import Contact Insights (sample data)
            for insightData in seedData.contactInsights {
                let insight = ContactInsight(context: context)
                let insightUUID = self.generateAndStoreUUID(for: insightData.uniqueIdentifier)
                insight.insightId = insightUUID
                insight.type = insightData.type
                insight.category = insightData.category
                insight.order = insightData.order
                insight.content = insightData.content
                insight.createdAt = insightData.createdAt
                insight.updatedAt = insightData.updatedAt
                insight.recordStatus = insightData.recordStatus
            }
            
            // Import Circles (sample data with type == 0)
            for circleData in seedData.circles {
                let circle = Circle(context: context)
                let circleUUID = self.generateAndStoreUUID(for: circleData.uniqueIdentifier)
                circle.circleId = circleUUID
                circle.name = circleData.name
                circle.type = circleData.type
                circle.createdAt = circleData.createdAt
                circle.updatedAt = circleData.updatedAt
                circle.recordStatus = circleData.recordStatus
                circle.isArchived = false
            }

            // Import Circle Insights (sample data)
            for insightData in seedData.circleInsights {
                let insight = CircleInsight(context: context)
                let insightUUID = self.generateAndStoreUUID(for: insightData.uniqueIdentifier)
                insight.insightId = insightUUID
                insight.type = insightData.type
                insight.category = insightData.category
                insight.subCategory = insightData.subCategory
                insight.order = insightData.order
                insight.subOrder = insightData.subOrder
                insight.content = insightData.content
                insight.createdAt = insightData.createdAt
                insight.updatedAt = insightData.updatedAt
                insight.recordStatus = insightData.recordStatus
            }

            do {
                try context.save()
                try self.validateContacts(in: context)
            } catch {
                throw error
            }
            
            // Create Note-Contact Relationships
            var relationshipErrors = 0

            let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
            let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
            let allNotes = try? context.fetch(noteRequest)
            let allContacts = try? context.fetch(contactRequest)

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

            for relationshipData in seedData.noteContactRelationships {
                let noteUUID = self.getUUID(for: relationshipData.noteIdentifier)
                let contactUUID = self.getUUID(for: relationshipData.contactIdentifier)
                
                guard let noteUUID = noteUUID,
                      let contactUUID = contactUUID else {
                    relationshipErrors += 1
                    continue
                }
                
                guard let note = notesByUUID[noteUUID],
                      let contact = contactsByUUID[contactUUID] else {
                    relationshipErrors += 1
                    continue
                }
                
                let existingRequest: NSFetchRequest<NoteContactRelationship> = NoteContactRelationship.fetchRequest()
                existingRequest.predicate = NSPredicate(format: "notes.noteId == %@ AND contacts.contactId == %@",
                                                      noteUUID as CVarArg, contactUUID as CVarArg)
                
                do {
                    let existingRelationships = try context.fetch(existingRequest)
                    if !existingRelationships.isEmpty {
                        continue
                    }
                    
                    let relationship = NoteContactRelationship(context: context)
                    relationship.relationshipId = UUID()
                    relationship.createdAt = relationshipData.createdAt
                    relationship.notes = note
                    relationship.contacts = contact
                    
                    try context.save()
                    
                    if relationship.notes == nil || relationship.contacts == nil {
                        context.delete(relationship)
                        try context.save()
                        relationshipErrors += 1
                        continue
                    }
                    
                } catch {
                    relationshipErrors += 1
                    continue
                }
            }

            // Create Circle-Contact Relationships
            relationshipErrors = 0
            
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
            
            for (circle, contact, createdAt) in validRelationships {
                let relationship = CircleContactRelationship(context: context)
                relationship.relationshipId = UUID()
                relationship.circles = circle
                relationship.contacts = contact
                relationship.createdAt = createdAt
            }
            
            do {
                try context.save()
            } catch {
                relationshipErrors += validRelationships.count
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
            
            let allRelationshipsRequest: NSFetchRequest<InsightCircleRelationship> = InsightCircleRelationship.fetchRequest()
            _ = try? context.fetch(allRelationshipsRequest)
            
            do {
                try context.save()
            } catch {
                throw error
            }

            try self.validateContacts(in: context)
        }
    }

    private func validateContacts(in context: NSManagedObjectContext) throws {
        let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        let allContacts = try context.fetch(contactRequest)
        
        let contactsWithNilId = allContacts.filter { $0.contactId == nil }
        if !contactsWithNilId.isEmpty {
            throw NSError(domain: "SeedDataManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Found contacts with nil contactId"])
        }
        
        let contactIds = allContacts.compactMap { $0.contactId }
        let uniqueIds = Set(contactIds)
        if contactIds.count != uniqueIds.count {
            throw NSError(domain: "SeedDataManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Found duplicate contactIds"])
        }
        
        for contact in allContacts {
            guard let contactId = contact.contactId else { continue }
            let relationshipRequest: NSFetchRequest<NoteContactRelationship> = NoteContactRelationship.fetchRequest()
            relationshipRequest.predicate = NSPredicate(format: "contacts.contactId == %@", contactId as CVarArg)
            _ = try context.fetch(relationshipRequest)
        }
    }
    
    // MARK: - Data Retrieval Utilities
    
    /// Fetches all contacts (both sample and user data)
    func fetchAllContacts(in context: NSManagedObjectContext) throws -> [Contact] {
        let request: NSFetchRequest<Contact> = Contact.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Contact.createdAt, ascending: false)]
        return try context.fetch(request)
    }
    
    /// Fetches all notes (both sample and user data)
    func fetchAllNotes(in context: NSManagedObjectContext) throws -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
        return try context.fetch(request)
    }
    
    /// Fetches all circles (both sample and user data)
    func fetchAllCircles(in context: NSManagedObjectContext) throws -> [Circle] {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Circle.createdAt, ascending: false)]
        return try context.fetch(request)
    }
    
    /// Fetches only sample data (type == 0)
    func fetchSampleData(in context: NSManagedObjectContext) throws -> (contacts: [Contact], notes: [Note], circles: [Circle]) {
        let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        contactRequest.predicate = NSPredicate(format: "type == %d", 0)
        contactRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Contact.createdAt, ascending: false)]
        
        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteRequest.predicate = NSPredicate(format: "type == %d", 0)
        noteRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
        
        let circleRequest: NSFetchRequest<Circle> = Circle.fetchRequest()
        circleRequest.predicate = NSPredicate(format: "type == %d", 0)
        circleRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Circle.createdAt, ascending: false)]
        
        let contacts = try context.fetch(contactRequest)
        let notes = try context.fetch(noteRequest)
        let circles = try context.fetch(circleRequest)
        
        return (contacts, notes, circles)
    }
    
    /// Fetches only user data (type != 0)
    func fetchUserData(in context: NSManagedObjectContext) throws -> (contacts: [Contact], notes: [Note], circles: [Circle]) {
        let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        contactRequest.predicate = NSPredicate(format: "type != %d", 0)
        contactRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Contact.createdAt, ascending: false)]
        
        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteRequest.predicate = NSPredicate(format: "type != %d", 0)
        noteRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
        
        let circleRequest: NSFetchRequest<Circle> = Circle.fetchRequest()
        circleRequest.predicate = NSPredicate(format: "type != %d", 0)
        circleRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Circle.createdAt, ascending: false)]
        
        let contacts = try context.fetch(contactRequest)
        let notes = try context.fetch(noteRequest)
        let circles = try context.fetch(circleRequest)
        
        return (contacts, notes, circles)
    }
    
    /// Checks if sample data exists
    func hasSampleData(in context: NSManagedObjectContext) throws -> Bool {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "type == %d", 0)
        request.fetchLimit = 1
        let count = try context.count(for: request)
        return count > 0
    }
    
    /// Checks if user data exists
    func hasUserData(in context: NSManagedObjectContext) throws -> Bool {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "type != %d", 0)
        request.fetchLimit = 1
        let count = try context.count(for: request)
        return count > 0
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
    let birthday: Date?
    let tel: String?
    let memo: String?
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
    
    // Custom decoding to provide default value for type
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uniqueIdentifier = try container.decode(String.self, forKey: .uniqueIdentifier)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(Int16.self, forKey: .type) ?? 0
        birthday = try container.decodeIfPresent(Date.self, forKey: .birthday)
        tel = try container.decodeIfPresent(String.self, forKey: .tel)
        memo = try container.decodeIfPresent(String.self, forKey: .memo)
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
        try container.encodeIfPresent(birthday, forKey: .birthday)
        try container.encodeIfPresent(tel, forKey: .tel)
        try container.encodeIfPresent(memo, forKey: .memo)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(recordStatus, forKey: .recordStatus)
    }
    
    private enum CodingKeys: String, CodingKey {
        case uniqueIdentifier, name, type, birthday, tel, memo, createdAt, updatedAt, recordStatus
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