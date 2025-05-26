import CoreData
import Foundation

class CircleManager: ObservableObject {
    static let shared = CircleManager()
    private let context = CoreDataManager.shared.viewContext
    
    private init() {}
    
    // MARK: - Debug Helpers
    private func debugCircleContacts(circleId: UUID, contextDescription: String) {
        print("\n[DEBUG] 🔍 Circle-Contact Check (\(contextDescription))")
        print("[DEBUG] Checking circle: \(circleId)")
        
        // Get circle
        let circleRequest: NSFetchRequest<Circle> = Circle.fetchRequest()
        circleRequest.predicate = NSPredicate(format: "circleId == %@", circleId as CVarArg)
        guard let circle = try? self.context.fetch(circleRequest).first else {
            print("[DEBUG] ❌ Circle not found")
            return
        }
        print("[DEBUG] Found circle: \(circle.name ?? "nil")")
        
        // Get all relationships directly from circle
        if let relationships = circle.contacts as? Set<CircleContactRelationship> {
            print("[DEBUG] Direct relationships from circle: \(relationships.count)")
            for rel in relationships {
                print("[DEBUG] - Relationship ID: \(rel.relationshipId?.uuidString ?? "nil")")
                print("[DEBUG]   Contact: \(rel.contacts?.name ?? "nil")")
            }
        }
        
        // Get relationships through fetch request
        let request: NSFetchRequest<CircleContactRelationship> = CircleContactRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "ANY circles == %@", circle)
        if let fetchedRelationships = try? self.context.fetch(request) {
            print("[DEBUG] Fetched relationships: \(fetchedRelationships.count)")
            for rel in fetchedRelationships {
                print("[DEBUG] - Relationship ID: \(rel.relationshipId?.uuidString ?? "nil")")
                print("[DEBUG]   Contact: \(rel.contacts?.name ?? "nil")")
            }
        }
        
        print("[DEBUG] 🔍 End Circle-Contact Check\n")
    }
    
    // MARK: - Create
    func createCircle(name: String, type: Int16 = 0) -> Circle? {
        let circle = Circle(context: context)
        circle.circleId = UUID()
        circle.name = name
        circle.type = type
        circle.createdAt = Date()
        circle.updatedAt = Date()
        circle.recordStatus = 0 // unsynced
        
        do {
            try context.save()
            debugCircleContacts(circleId: circle.circleId!, contextDescription: "After circle creation")
            return circle
        } catch {
            print("Error creating circle: \(error)")
            return nil
        }
    }
    
    // MARK: - Read
    func fetchCircles() -> [Circle] {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Circle.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching circles: \(error)")
            return []
        }
    }
    
    func fetchCircle(withId circleId: UUID) -> Circle? {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.predicate = NSPredicate(format: "circleId == %@", circleId as CVarArg)
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
        request.predicate = NSPredicate(format: "name == %@", name)
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
        print("\n[DEBUG] Getting contacts for circle: \(circleId)")
        
        // First verify the circle exists
        let circleRequest: NSFetchRequest<Circle> = Circle.fetchRequest()
        circleRequest.predicate = NSPredicate(format: "circleId == %@", circleId as CVarArg)
        let circles = try? context.fetch(circleRequest)
        guard let circle = circles?.first else {
            print("[DEBUG] Circle not found")
            return []
        }
        print("[DEBUG] Found circle: \(circle.name ?? "nil")")
        
        // Debug before fetch
        debugCircleContacts(circleId: circleId, contextDescription: "Before fetching contacts")
        
        // Get all relationships for this circle using a different predicate approach
        let request: NSFetchRequest<CircleContactRelationship> = CircleContactRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "ANY circles == %@", circle)
        
        do {
            let relationships = try context.fetch(request)
            print("[DEBUG] Found \(relationships.count) relationships")
            
            // Debug each relationship
            for relationship in relationships {
                print("\n[DEBUG] Relationship details:")
                print("[DEBUG] Relationship ID: \(relationship.relationshipId?.uuidString ?? "nil")")
                print("[DEBUG] Circle: \(relationship.circles?.name ?? "nil") (ID: \(relationship.circles?.circleId?.uuidString ?? "nil"))")
                print("[DEBUG] Contact: \(relationship.contacts?.name ?? "nil") (ID: \(relationship.contacts?.contactId?.uuidString ?? "nil"))")
                print("[DEBUG] Created at: \(relationship.createdAt?.description ?? "nil")")
                
                // Verify the relationship is valid
                if relationship.circles == nil || relationship.contacts == nil {
                    print("[DEBUG] ⚠️ Invalid relationship found - cleaning up")
                    context.delete(relationship)
                }
            }
            
            // Save context if we deleted any invalid relationships
            if context.hasChanges {
                try context.save()
                print("[DEBUG] Saved context after cleaning invalid relationships")
                debugCircleContacts(circleId: circleId, contextDescription: "After cleaning invalid relationships")
            }
            
            let contacts = relationships.compactMap { $0.contacts }
            print("[DEBUG] Returning \(contacts.count) contacts")
            return contacts
        } catch {
            print("[DEBUG] Error fetching contacts for circle: \(error)")
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
        return getContactsForCircle(circleId: circleId).count
    }
    
    func validateCircleRelationships(_ circle: Circle) throws {
        print("\n[DEBUG] Validating relationships for circle: \(circle.name ?? "nil")")
        debugCircleContacts(circleId: circle.circleId!, contextDescription: "Before validation")
        
        // If circle has no relationships, that's valid
        guard let relationships = circle.contacts as? Set<CircleContactRelationship> else {
            print("[DEBUG] No relationships found")
            return // No relationships is valid
        }
        
        // Check each relationship
        var invalidCount = 0
        for relationship in relationships {
            if relationship.contacts == nil {
                // Clean up invalid relationship
                print("[DEBUG] Found invalid relationship: \(relationship.relationshipId?.uuidString ?? "nil")")
                context.delete(relationship)
                invalidCount += 1
            }
        }
        
        // Save changes if any relationships were deleted
        if invalidCount > 0 {
            print("[DEBUG] Cleaning up \(invalidCount) invalid relationships")
            do {
                try context.save()
                debugCircleContacts(circleId: circle.circleId!, contextDescription: "After validation cleanup")
            } catch {
                print("Error cleaning up invalid relationships: \(error)")
            }
        } else {
            print("[DEBUG] No invalid relationships found")
        }
    }
    
    // MARK: - Relationship Management
    func addContactToCircle(circleId: UUID, contactId: UUID) -> Bool {
        print("\n[DEBUG] Adding contact to circle")
        debugCircleContacts(circleId: circleId, contextDescription: "Before adding contact")
        
        guard let circle = fetchCircle(withId: circleId),
              let contact = ContactManager.shared.fetchContact(withId: contactId) else {
            print("[DEBUG] Failed to find circle or contact")
            return false
        }
        
        let relationship = CircleContactRelationship(context: context)
        relationship.relationshipId = UUID()
        relationship.circles = circle
        relationship.contacts = contact
        relationship.createdAt = Date()
        
        do {
            try context.save()
            print("[DEBUG] Successfully added contact to circle")
            debugCircleContacts(circleId: circleId, contextDescription: "After adding contact")
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
            return relationships.compactMap { $0.circles }
        } catch {
            print("Error fetching circles for contact: \(error)")
            return []
        }
    }
} 