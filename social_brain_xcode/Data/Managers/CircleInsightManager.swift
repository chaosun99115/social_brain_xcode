import CoreData
import Foundation

class CircleInsightManager: ObservableObject {
    static let shared = CircleInsightManager()
    private let context = CoreDataManager.shared.viewContext
    
    private init() {}
    
    // MARK: - Create
    func createInsight(type: Int16, category: String, subCategory: String = "", content: String, order: Int16 = 0, subOrder: Int16 = 0) -> CircleInsight? {
        let insight = CircleInsight(context: context)
        insight.insightId = UUID()
        insight.type = type
        insight.category = category
        insight.subCategory = subCategory
        insight.content = content
        insight.order = order
        insight.subOrder = subOrder
        insight.createdAt = Date()
        insight.updatedAt = Date()
        insight.recordStatus = 0 // unsynced
        
        do {
            try context.save()
            return insight
        } catch {
            print("Error creating circle insight: \(error)")
            return nil
        }
    }
    
    // MARK: - Read
    func fetchInsights() -> [CircleInsight] {
        let request: NSFetchRequest<CircleInsight> = CircleInsight.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CircleInsight.order, ascending: true),
            NSSortDescriptor(keyPath: \CircleInsight.subOrder, ascending: true),
            NSSortDescriptor(keyPath: \CircleInsight.updatedAt, ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching circle insights: \(error)")
            return []
        }
    }
    
    func fetchInsight(withId insightId: UUID) -> CircleInsight? {
        let request: NSFetchRequest<CircleInsight> = CircleInsight.fetchRequest()
        request.predicate = NSPredicate(format: "insightId == %@", insightId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching circle insight: \(error)")
            return nil
        }
    }
    
    // MARK: - Update
    func updateInsight(insightId: UUID, type: Int16, category: String, subCategory: String, content: String, order: Int16, subOrder: Int16) -> Bool {
        guard let insight = fetchInsight(withId: insightId) else { return false }
        
        insight.type = type
        insight.category = category
        insight.subCategory = subCategory
        insight.content = content
        insight.order = order
        insight.subOrder = subOrder
        insight.updatedAt = Date()
        insight.recordStatus = 0 // mark as unsynced
        
        do {
            try context.save()
            return true
        } catch {
            print("Error updating circle insight: \(error)")
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
            print("Error deleting circle insight: \(error)")
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
            print("Error marking circle insight as synced: \(error)")
            return false
        }
    }
    
    // MARK: - Relationships
    func getCirclesForInsight(insightId: UUID) -> [Circle] {
        let request: NSFetchRequest<InsightCircleRelationship> = InsightCircleRelationship.fetchRequest()
        request.predicate = NSPredicate(format: "insights.insightId == %@", insightId as CVarArg)
        
        do {
            let relationships = try context.fetch(request)
            return relationships.compactMap { $0.circles }
        } catch {
            print("Error fetching circles for insight: \(error)")
            return []
        }
    }
    
    func validateInsightRelationships(_ insight: CircleInsight) throws {
        // If insight has no relationships, that's valid
        guard let relationships = insight.circles as? Set<InsightCircleRelationship> else {
            return // No relationships is valid
        }
        
        // Check each relationship
        for relationship in relationships {
            if relationship.circles == nil {
                // Clean up invalid relationship
                context.delete(relationship)
            }
        }
        
        // Save changes if any relationships were deleted
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error cleaning up invalid relationships: \(error)")
            }
        }
    }
} 