import CoreData
import Foundation

class ContactInsightManager: ObservableObject {
    static let shared = ContactInsightManager()
    private let context = CoreDataManager.shared.viewContext
    
    private init() {}
    
    // MARK: - Create
    func createInsight(type: String, category: String, content: String, order: Int16 = 0) -> ContactInsight? {
        let insight = ContactInsight(context: context)
        insight.insightId = UUID()
        insight.type = type
        insight.category = category
        insight.content = content
        insight.order = String(order) // Convert Int16 to String
        insight.createdAt = Date()
        insight.updatedAt = Date()
        insight.recordStatus = 0 // unsynced
        
        do {
            try context.save()
            return insight
        } catch {
            print("Error creating insight: \(error)")
            return nil
        }
    }
    
    // MARK: - Read
    func fetchInsights() -> [ContactInsight] {
        let request: NSFetchRequest<ContactInsight> = ContactInsight.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ContactInsight.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching insights: \(error)")
            return []
        }
    }
    
    func fetchInsight(withId insightId: UUID) -> ContactInsight? {
        let request: NSFetchRequest<ContactInsight> = ContactInsight.fetchRequest()
        request.predicate = NSPredicate(format: "insightId == %@", insightId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching insight: \(error)")
            return nil
        }
    }
    
    // MARK: - Update
    func updateInsight(insightId: UUID, type: String, category: String, content: String, order: Int16) -> Bool {
        guard let insight = fetchInsight(withId: insightId) else { return false }
        
        insight.type = type
        insight.category = category
        insight.content = content
        insight.order = String(order) // Convert Int16 to String
        insight.updatedAt = Date()
        insight.recordStatus = 0 // mark as unsynced
        
        do {
            try context.save()
            return true
        } catch {
            print("Error updating insight: \(error)")
            return false
        }
    }
    
    // MARK: - Delete
    func deleteInsight(insightId: UUID) -> Bool {
        guard let insight = fetchInsight(withId: insightId) else { return false }
        
        // Soft delete by marking as deleted
        insight.recordStatus = 2 // deleted
        insight.updatedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error deleting insight: \(error)")
            return false
        }
    }
    
    // MARK: - Sync Status
    func markInsightAsSynced(insightId: UUID) -> Bool {
        guard let insight = fetchInsight(withId: insightId) else { return false }
        
        insight.recordStatus = 1 // synced
        insight.updatedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error marking insight as synced: \(error)")
            return false
        }
    }
    
    // MARK: - Relationships
    func addContactToInsight(insightId: UUID, contactId: UUID) -> Bool {
        guard let insight = fetchInsight(withId: insightId),
              let contact = ContactManager.shared.fetchContact(withId: contactId) else {
            return false
        }
        
        let relationship = InsightContactRelationship(context: context)
        relationship.relationshipId = UUID()
        relationship.insights = insight
        relationship.contacts = contact
        relationship.createdAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error adding contact to insight: \(error)")
            return false
        }
    }
    
    func removeContactFromInsight(insightId: UUID, contactId: UUID) -> Bool {
        let request: NSFetchRequest<InsightContactRelationship> = InsightContactRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "insights.insightId == %@ AND contacts.contactId == %@",
                                      insightId as CVarArg, contactId as CVarArg)
        
        do {
            let relationships = try context.fetch(request)
            for relationship in relationships {
                context.delete(relationship)
            }
            try context.save()
            return true
        } catch {
            print("Error removing contact from insight: \(error)")
            return false
        }
    }
    
    func getContactsForInsight(insightId: UUID) -> [Contact] {
        guard let insight = fetchInsight(withId: insightId) else { return [] }
        
        // Get the relationships
        let relationships = insight.contacts as? Set<InsightContactRelationship> ?? []
        
        // Extract contacts from relationships
        return relationships.compactMap { $0.contacts }
    }
} 