import CoreData
import Foundation

class CircleManager: ObservableObject {
    static let shared = CircleManager()
    private let context = CoreDataManager.shared.viewContext
    
    private init() {}
    
    // MARK: - Debug Helpers
    private func debugCircleContacts(circleId: UUID, contextDescription: String) {
        // Debug helper function - keeping empty for now
    }
    
    // MARK: - Create
    func createCircle(name: String, type: Int16 = 0) -> Circle? {
        let circle = Circle(context: context)
        circle.circleId = UUID()
        circle.name = name
        circle.type = type
        circle.isArchived = false
        circle.createdAt = Date()
        circle.updatedAt = Date()
        circle.recordStatus = 0 // unsynced
        
        do {
            try context.save()
            return circle
        } catch {
            print("Error creating circle: \(error)")
            return nil
        }
    }
    
    // MARK: - Read
    func fetchCircles() -> [Circle] {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Circle.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching circles: \(error)")
            return []
        }
    }
    
    func fetchCircles(byType type: Int16) -> [Circle] {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.predicate = NSPredicate(format: "type == %d AND isArchived == NO", type)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Circle.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching circles by type: \(error)")
            return []
        }
    }
    
    func fetchCircle(withId circleId: UUID) -> Circle? {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.predicate = NSPredicate(format: "circleId == %@ AND isArchived == NO", circleId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching circle: \(error)")
            return nil
        }
    }
    
    func fetchCircle(withName name: String) -> Circle? {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND isArchived == NO", name)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching circle by name: \(error)")
            return nil
        }
    }
    
    func circleExists(withName name: String) -> Bool {
        return fetchCircle(withName: name) != nil
    }
    
    // MARK: - Update
    func updateCircle(circleId: UUID, name: String, type: Int16? = nil) -> Bool {
        guard let circle = fetchCircle(withId: circleId) else { return false }
        
        circle.name = name
        if let type = type {
            circle.type = type
        }
        circle.updatedAt = Date()
        circle.recordStatus = 0 // mark as unsynced
        
        do {
            try context.save()
            return true
        } catch {
            print("Error updating circle: \(error)")
            return false
        }
    }
    
    // MARK: - Delete
    func deleteCircle(circleId: UUID) -> Bool {
        guard let circle = fetchCircle(withId: circleId) else { return false }
        
        // Soft delete by marking as deleted
        circle.recordStatus = 2 // deleted
        circle.updatedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error deleting circle: \(error)")
            return false
        }
    }
    
    // MARK: - Archive
    func archiveCircle(circleId: UUID) -> Bool {
        // Use a different fetch method that doesn't filter by isArchived
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.predicate = NSPredicate(format: "circleId == %@", circleId as CVarArg)
        request.fetchLimit = 1
        
        do {
            guard let circle = try context.fetch(request).first else { return false }
            
            // Archive the circle
            circle.isArchived = true
            circle.updatedAt = Date()
            circle.recordStatus = 0 // mark as unsynced
            
            try context.save()
            return true
        } catch {
            print("Error archiving circle: \(error)")
            return false
        }
    }
    
    // MARK: - Sync Status
    func markCircleAsSynced(circleId: UUID) -> Bool {
        guard let circle = fetchCircle(withId: circleId) else { return false }
        
        circle.recordStatus = 1 // synced
        circle.updatedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error marking circle as synced: \(error)")
            return false
        }
    }
    
    // MARK: - Relationships
    func getContactsForCircle(circleId: UUID) -> [Contact] {
        // First verify the circle exists
        let circleRequest: NSFetchRequest<Circle> = Circle.fetchRequest()
        circleRequest.predicate = NSPredicate(format: "circleId == %@", circleId as CVarArg)
        let circles = try? context.fetch(circleRequest)
        guard let circle = circles?.first else {
            return []
        }
        
        // Get all relationships for this circle using a different predicate approach
        let request: NSFetchRequest<CircleContactRelationship> = CircleContactRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "ANY circles == %@", circle)
        
        do {
            let relationships = try context.fetch(request)
            
            // Verify the relationship is valid
            for relationship in relationships {
                if relationship.circles == nil || relationship.contacts == nil {
                    context.delete(relationship)
                }
            }
            
            // Save context if we deleted any invalid relationships
            if context.hasChanges {
                try context.save()
            }
            
            // Filter out archived contacts
            return relationships.compactMap { $0.contacts }.filter { !$0.isArchived }
        } catch {
            print("Error fetching contacts for circle: \(error)")
            return []
        }
    }
    
    func getInsightsForCircle(circleId: UUID) -> [CircleInsight] {
        let request: NSFetchRequest<InsightCircleRelationship> = InsightCircleRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "circles.circleId == %@", circleId as CVarArg)
        
        do {
            let relationships = try context.fetch(request)
            return relationships.compactMap { $0.insights }
        } catch {
            print("Error fetching insights for circle: \(error)")
            return []
        }
    }
    
    // MARK: - Contact Count
    func getContactsCount(forCircleId circleId: UUID) -> Int {
        let contacts = getContactsForCircle(circleId: circleId)
        return contacts.count
    }
    
    func validateCircleRelationships(_ circle: Circle) throws {
        // If circle has no relationships, that's valid
        guard let relationships = circle.contacts as? Set<CircleContactRelationship> else {
            return // No relationships is valid
        }
        
        // Check each relationship
        var invalidCount = 0
        for relationship in relationships {
            if relationship.contacts == nil {
                // Clean up invalid relationship
                context.delete(relationship)
                invalidCount += 1
            }
        }
        
        // Save changes if any relationships were deleted
        if invalidCount > 0 {
            do {
                try context.save()
            } catch {
                print("Error cleaning up invalid relationships: \(error)")
            }
        }
    }
    
    // MARK: - Relationship Management
    func addContactToCircle(circleId: UUID, contactId: UUID) -> Bool {
        guard let circle = fetchCircle(withId: circleId),
              let contact = ContactManager.shared.fetchContact(withId: contactId) else {
            return false
        }
        
        let relationship = CircleContactRelationship(context: context)
        relationship.relationshipId = UUID()
        relationship.circles = circle
        relationship.contacts = contact
        relationship.createdAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error adding contact to circle: \(error)")
            return false
        }
    }
    
    func removeContactFromCircle(circleId: UUID, contactId: UUID) -> Bool {
        let request: NSFetchRequest<CircleContactRelationship> = CircleContactRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "circles.circleId == %@ AND contacts.contactId == %@",
                                      circleId as CVarArg, contactId as CVarArg)
        
        do {
            let relationships = try context.fetch(request)
            for relationship in relationships {
                context.delete(relationship)
            }
            try context.save()
            return true
        } catch {
            print("Error removing contact from circle: \(error)")
            return false
        }
    }
    
    func addInsightToCircle(circleId: UUID, insightId: UUID) -> Bool {
        guard let circle = fetchCircle(withId: circleId),
              let insight = CircleInsightManager.shared.fetchInsight(withId: insightId) else {
            return false
        }
        
        let relationship = InsightCircleRelationship(context: context)
        relationship.relationshipId = UUID()
        relationship.circles = circle
        relationship.insights = insight
        relationship.createdAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("Error adding insight to circle: \(error)")
            return false
        }
    }
    
    func removeInsightFromCircle(circleId: UUID, insightId: UUID) -> Bool {
        let request: NSFetchRequest<InsightCircleRelationship> = InsightCircleRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "circles.circleId == %@ AND insights.insightId == %@",
                                      circleId as CVarArg, insightId as CVarArg)
        
        do {
            let relationships = try context.fetch(request)
            for relationship in relationships {
                context.delete(relationship)
            }
            try context.save()
            return true
        } catch {
            print("Error removing insight from circle: \(error)")
            return false
        }
    }
    
    /// Returns all circles for a given contactId
    func getCirclesForContact(contactId: UUID) -> [Circle] {
        let request: NSFetchRequest<CircleContactRelationship> = CircleContactRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "contacts.contactId == %@", contactId as CVarArg)
        do {
            let relationships = try context.fetch(request)
            // Filter out archived circles
            return relationships.compactMap { $0.circles }.filter { !$0.isArchived }
        } catch {
            print("Error fetching circles for contact: \(error)")
            return []
        }
    }
} 