import CoreData
import Foundation

class ContactInsightManager: ObservableObject {
    static let shared = ContactInsightManager()
    private let context = CoreDataManager.shared.viewContext
    
    private init() {}
    
    // MARK: - Create
    func createInsight(type: Int16, category: String, content: String, order: Int16 = 0) -> ContactInsight? {
        let insight = ContactInsight(context: context)
        insight.insightId = UUID()
        insight.type = type
        insight.category = category
        insight.content = content
        insight.order = order
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
            let insights = try context.fetch(request)
            print("[DEBUG] Fetched \(insights.count) insights")
            for insight in insights {
                print("[DEBUG] Insight ID: \(insight.insightId?.uuidString ?? "nil")")
                print("[DEBUG] Category: \(insight.category ?? "nil")")
                print("[DEBUG] Content: \(insight.content ?? "nil")")
                if let relationships = insight.contacts as? Set<InsightContactRelationship> {
                    print("[DEBUG] Related contacts: \(relationships.compactMap { $0.contacts?.name }.joined(separator: ", "))")
                }
            }
            return insights
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
    func updateInsight(insightId: UUID, type: Int16, category: String, content: String, order: Int16) -> Bool {
        guard let insight = fetchInsight(withId: insightId) else { return false }
        
        insight.type = type
        insight.category = category
        insight.content = content
        insight.order = order
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
        print("\n[DEBUG] Adding contact \(contactId) to insight \(insightId)")
        
        guard let insight = fetchInsight(withId: insightId),
              let contact = ContactManager.shared.fetchContact(withId: contactId) else {
            print("[DEBUG] Failed to find insight or contact")
            return false
        }
        
        print("[DEBUG] Found insight: \(insight.insightId?.uuidString ?? "nil")")
        print("[DEBUG] Found contact: \(contact.name ?? "unnamed")")
        
        // Check if relationship already exists
        let existingRequest: NSFetchRequest<InsightContactRelationship> = InsightContactRelationship.fetchRequest()
        existingRequest.predicate = NSPredicate(format: "insights.insightId == %@ AND contacts.contactId == %@",
                                              insightId as CVarArg, contactId as CVarArg)
        
        do {
            let existingRelationships = try context.fetch(existingRequest)
            if !existingRelationships.isEmpty {
                print("[DEBUG] Relationship already exists")
                return true
            }
            
            let relationship = InsightContactRelationship(context: context)
            relationship.relationshipId = UUID()
            relationship.insights = insight
            relationship.contacts = contact
            relationship.createdAt = Date()
            
            print("[DEBUG] Created new relationship with ID: \(relationship.relationshipId?.uuidString ?? "nil")")
            
            // Add to contact's insights (to-many)
            contact.addToInsights(relationship)
            
            print("[DEBUG] Added relationship to contact's insights set")
            
            try context.save()
            print("[DEBUG] Successfully saved relationship")
            
            // Verify the relationship was saved
            let verifyRequest: NSFetchRequest<InsightContactRelationship> = InsightContactRelationship.fetchRequest()
            verifyRequest.predicate = NSPredicate(format: "relationshipId == %@", relationship.relationshipId! as CVarArg)
            let savedRelationships = try context.fetch(verifyRequest)
            print("[DEBUG] Verification: Found \(savedRelationships.count) saved relationships")
            
            return true
        } catch {
            print("[DEBUG] Error adding contact to insight: \(error)")
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
            print("[DEBUG] Successfully removed contact from insight")
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
        let contacts = relationships.compactMap { $0.contacts }
        print("[DEBUG] Found \(contacts.count) contacts for insight \(insightId)")
        return contacts
    }
    
    func getInsightsForContact(contactId: UUID) -> [ContactInsight] {
        print("\n[DEBUG] Getting insights for contact: \(contactId)")
        
        // First, verify the contact exists
        let contactRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        contactRequest.predicate = NSPredicate(format: "contactId == %@", contactId as CVarArg)
        
        do {
            let contacts = try context.fetch(contactRequest)
            if let contact = contacts.first {
                print("[DEBUG] Found contact: \(contact.name ?? "unnamed")")
                if let relationships = contact.insights as? Set<InsightContactRelationship> {
                    print("[DEBUG] Contact has \(relationships.count) insight relationships")
                    for rel in relationships {
                        print("[DEBUG] Relationship ID: \(rel.relationshipId?.uuidString ?? "nil")")
                        print("[DEBUG] Related to insight: \(rel.insights?.insightId?.uuidString ?? "nil")")
                    }
                } else {
                    print("[DEBUG] Contact has no insight relationships")
                }
            } else {
                print("[DEBUG] Contact not found!")
            }
        } catch {
            print("[DEBUG] Error fetching contact: \(error)")
        }
        
        // Now fetch the relationships
        let request: NSFetchRequest<InsightContactRelationship> = InsightContactRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "contacts.contactId == %@", contactId as CVarArg)
        
        do {
            let relationships = try context.fetch(request)
            print("[DEBUG] Found \(relationships.count) relationships for contact")
            
            let insights = relationships.compactMap { $0.insights }
            print("[DEBUG] Extracted \(insights.count) insights from relationships")
            
            for insight in insights {
                print("[DEBUG] Insight ID: \(insight.insightId?.uuidString ?? "nil")")
                print("[DEBUG] Category: \(insight.category ?? "nil")")
                print("[DEBUG] Content: \(insight.content ?? "nil")")
            }
            
            return insights
        } catch {
            print("[DEBUG] Error fetching insights for contact: \(error)")
            return []
        }
    }
} 