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
    
    // UUID mapping for maintaining relationships
    private var uuidMapping: [String: UUID] = [:]
    
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
    
    private func getOrCreateUUID(for originalId: String) -> UUID {
        if let existingUUID = uuidMapping[originalId] {
            return existingUUID
        }
        let newUUID = UUID()
        uuidMapping[originalId] = newUUID
        return newUUID
    }
    
    // MARK: - Core Data Import
    
    func importSeedData(into context: NSManagedObjectContext) async throws {
        let data = try await loadSeedData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let seedData = try decoder.decode(SeedData.self, from: data)
        
        // Clear previous mapping
        uuidMapping.removeAll()
        
        try await context.perform {
            // Import Notes
            for noteData in seedData.notes {
                let note = Note(context: context)
                note.noteId = self.getOrCreateUUID(for: noteData.noteId)
                note.content = noteData.content
                note.type = noteData.type
                note.updateCompleted = noteData.updateCompleted
                note.createdAt = noteData.createdAt
                note.updatedAt = noteData.updatedAt
                note.recordStatus = noteData.recordStatus
            }
            
            // Import Contacts
            for contactData in seedData.contacts {
                let contact = Contact(context: context)
                contact.contactId = self.getOrCreateUUID(for: contactData.contactId)
                contact.name = contactData.name
                contact.createdAt = contactData.createdAt
                contact.updatedAt = contactData.updatedAt
                contact.recordStatus = contactData.recordStatus
            }
            
            // Import Contact Insights
            for insightData in seedData.contactInsights {
                let insight = ContactInsight(context: context)
                insight.insightId = self.getOrCreateUUID(for: insightData.insightId)
                insight.type = insightData.type
                insight.category = insightData.category
                insight.order = String(insightData.order)
                insight.content = insightData.content
                insight.createdAt = insightData.createdAt
                insight.updatedAt = insightData.updatedAt
                insight.recordStatus = insightData.recordStatus
            }
            
            // Import Note-Contact Relationships
            for relationshipData in seedData.noteContactRelationships {
                let relationship = NoteContactRelationship(context: context)
                relationship.relationshipId = self.getOrCreateUUID(for: relationshipData.relationshipId)
                relationship.createdAt = relationshipData.createdAt
                
                // Set up relationships using mapped UUIDs
                if let note = try? context.fetch(Note.fetchRequest()).first(where: { $0.noteId == self.uuidMapping[relationshipData.noteId] }),
                   let contact = try? context.fetch(Contact.fetchRequest()).first(where: { $0.contactId == self.uuidMapping[relationshipData.contactId] }) {
                    relationship.notes = note
                    relationship.contacts = contact
                }
            }
            
            // Import Insight-Contact Relationships
            for relationshipData in seedData.insightContactRelationships {
                let relationship = InsightContactRelationship(context: context)
                relationship.relationshipId = self.getOrCreateUUID(for: relationshipData.relationshipId)
                relationship.createdAt = relationshipData.createdAt
                
                // Set up relationships using mapped UUIDs
                if let contact = try? context.fetch(Contact.fetchRequest()).first(where: { $0.contactId == self.uuidMapping[relationshipData.contactId] }),
                   let insight = try? context.fetch(ContactInsight.fetchRequest()).first(where: { $0.insightId == self.uuidMapping[relationshipData.insightId] }) {
                    relationship.contacts = contact
                    relationship.insights = insight
                }
            }
            
            try context.save()
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
}

struct NoteData: Codable {
    let noteId: String
    let content: String
    let type: Int16
    let updateCompleted: Int16
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
}

struct ContactData: Codable {
    let contactId: String
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
}

struct ContactInsightData: Codable {
    let insightId: String
    let type: String
    let category: String
    let order: Int16
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
}

struct NoteContactRelationshipData: Codable {
    let relationshipId: String
    let createdAt: Date
    let noteId: String
    let contactId: String
}

struct InsightContactRelationshipData: Codable {
    let relationshipId: String
    let createdAt: Date
    let contactId: String
    let insightId: String
} 