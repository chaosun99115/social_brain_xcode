import Foundation
import CoreData
import os.log

/// Service for managing prompts in the app
class PromptService {
    static let shared = PromptService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "PromptService")
    
    private init() {}
    
    /// Clears all existing prompts from the database
    /// - Parameter context: The managed object context to use
    private func clearAllPrompts(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Prompt.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            logger.error("Error clearing prompts: \(error.localizedDescription)")
        }
    }
    
    /// Re-ingests all default prompts, clearing existing ones first
    /// - Parameter context: The managed object context to use
    func reingestDefaultPrompts(in context: NSManagedObjectContext) {
        // First, preserve user-created prompts (identifier = 999)
        let userPromptsFetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        userPromptsFetchRequest.predicate = NSPredicate(format: "identifier == 999")
        let userPrompts: [Prompt]
        
        do {
            userPrompts = try context.fetch(userPromptsFetchRequest)
        } catch {
            logger.error("Error fetching user prompts: \(error.localizedDescription)")
            userPrompts = []
        }
        
        clearAllPrompts(in: context)
        ingestDefaultPrompts(in: context)
        
        // Restore user-created prompts
        for userPrompt in userPrompts {
            let restoredPrompt = Prompt(context: context)
            restoredPrompt.id = userPrompt.id
            restoredPrompt.identifier = userPrompt.identifier
            restoredPrompt.name = userPrompt.name
            restoredPrompt.intro = userPrompt.intro
            restoredPrompt.display = userPrompt.display
            restoredPrompt.content = userPrompt.content
            restoredPrompt.type = userPrompt.type
            restoredPrompt.order = userPrompt.order
            restoredPrompt.createdAt = userPrompt.createdAt
            restoredPrompt.updatedAt = userPrompt.updatedAt
            restoredPrompt.recordStatus = userPrompt.recordStatus
            restoredPrompt.isArchived = userPrompt.isArchived // Preserve isArchived status
        }
        
        do {
            try context.save()
        } catch {
            logger.error("Error restoring user prompts: \(error.localizedDescription)")
        }
    }
    
    /// Ingests default prompts into Core Data
    /// - Parameter context: The managed object context to use
    func ingestDefaultPrompts(in context: NSManagedObjectContext) {
        for prompt in DefaultPrompts.prompts {
            for identifier in prompt.identifiers {
                let newPrompt = Prompt(context: context)
                newPrompt.id = UUID()
                newPrompt.identifier = Int16(identifier)
                newPrompt.name = prompt.name
                newPrompt.intro = prompt.intro
                newPrompt.display = prompt.display
                newPrompt.content = prompt.content
                newPrompt.type = prompt.type
                newPrompt.order = Int16(prompt.order)
                newPrompt.createdAt = Date()
                newPrompt.updatedAt = Date()
                newPrompt.recordStatus = 0
                newPrompt.isArchived = false // Set isArchived to false for default prompts
            }
        }
        
        do {
            try context.save()
        } catch {
            logger.error("Error ingesting default prompts: \(error.localizedDescription)")
        }
    }
    
    /// Checks if prompts need to be ingested
    /// - Parameter context: The managed object context to use
    /// - Returns: Boolean indicating if ingestion is needed
    func needsPromptIngestion(in context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        
        do {
            let count = try context.count(for: fetchRequest)
            return count == 0
        } catch {
            logger.error("Error checking prompt ingestion status: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Debug function to print all prompts in the database
    func debugPrintAllPrompts(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Prompt.name, ascending: true)]
        
        do {
            let prompts = try context.fetch(fetchRequest)
            
            for (index, prompt) in prompts.enumerated() {
                logger.debug("""
                    Prompt \(index + 1):
                    - Name: \(prompt.name ?? "nil")
                    - Display: \(prompt.display ?? "nil")
                    - Type: \(prompt.type)
                    - Content Length: \(prompt.content?.count ?? 0)
                    - Created: \(prompt.createdAt?.description ?? "nil")
                    - Updated: \(prompt.updatedAt?.description ?? "nil")
                    """)
            }
        } catch {
            logger.error("Error fetching prompts for debug: \(error.localizedDescription)")
        }
    }
} 