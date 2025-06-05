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
        logger.debug("Clearing all existing prompts from database")
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Prompt.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            logger.debug("Successfully cleared all prompts from database")
        } catch {
            logger.error("Error clearing prompts: \(error.localizedDescription)")
        }
    }
    
    /// Re-ingests all default prompts, clearing existing ones first
    /// - Parameter context: The managed object context to use
    func reingestDefaultPrompts(in context: NSManagedObjectContext) {
        logger.debug("Starting re-ingestion of default prompts")
        clearAllPrompts(in: context)
        ingestDefaultPrompts(in: context)
    }
    
    /// Ingests default prompts into Core Data
    /// - Parameter context: The managed object context to use
    func ingestDefaultPrompts(in context: NSManagedObjectContext) {
        logger.debug("Starting default prompts ingestion")
        logger.debug("Default prompts to be ingested: \(DefaultPrompts.prompts.count)")
        
        // Check if prompts already exist
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        
        do {
            let existingPrompts = try context.fetch(fetchRequest)
            logger.debug("Found \(existingPrompts.count) existing prompts")
            
            if !existingPrompts.isEmpty {
                logger.debug("Prompts already exist, skipping ingestion")
                return
            }
            
            // Log default prompts to be ingested
            logger.debug("Preparing to ingest \(DefaultPrompts.prompts.count) default prompts")
            
            // Ingest default prompts
            for (index, promptData) in DefaultPrompts.prompts.enumerated() {
                let prompt = Prompt(context: context)
                prompt.id = UUID()
                prompt.name = promptData.name
                prompt.display = promptData.display
                prompt.content = promptData.content
                prompt.type = promptData.type
                prompt.createdAt = Date()
                prompt.updatedAt = Date()
                prompt.recordStatus = 0
                prompt.order = 0
                prompt.intro = promptData.intro
                logger.debug("Ingested prompt \(index + 1): \(promptData.name) (Type: \(promptData.type)), Intro: \(promptData.intro)")
            }
            
            // Save context
            try context.save()
            logger.debug("Successfully saved all prompts to Core Data")
            
            // Verify ingestion
            let verifyFetch: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            let ingestedCount = try context.count(for: verifyFetch)
            logger.debug("Verification: Found \(ingestedCount) prompts in database after ingestion")
            
            if ingestedCount != DefaultPrompts.prompts.count {
                logger.error("""
                    Mismatch in prompt count:
                    - Expected: \(DefaultPrompts.prompts.count)
                    - Actual: \(ingestedCount)
                    """)
            }
            
        } catch {
            logger.error("Error during prompt ingestion: \(error.localizedDescription)")
        }
    }
    
    /// Checks if prompts need to be ingested
    /// - Parameter context: The managed object context to use
    /// - Returns: Boolean indicating if ingestion is needed
    func needsPromptIngestion(in context: NSManagedObjectContext) -> Bool {
        logger.debug("Checking if prompt ingestion is needed")
        
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        
        do {
            let count = try context.count(for: fetchRequest)
            logger.debug("Found \(count) existing prompts")
            return count == 0
        } catch {
            logger.error("Error checking prompt ingestion status: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Debug function to print all prompts in the database
    func debugPrintAllPrompts(in context: NSManagedObjectContext) {
        logger.debug("Debug: Printing all prompts in database")
        
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Prompt.name, ascending: true)]
        
        do {
            let prompts = try context.fetch(fetchRequest)
            logger.debug("Found \(prompts.count) prompts in database")
            
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