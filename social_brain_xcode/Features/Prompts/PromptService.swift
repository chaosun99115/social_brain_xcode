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
        clearAllPrompts(in: context)
        ingestDefaultPrompts(in: context)
    }
    
    /// Ingests default prompts into Core Data
    /// - Parameter context: The managed object context to use
    func ingestDefaultPrompts(in context: NSManagedObjectContext) {
        // Track created prompts to avoid duplicates
        var createdPrompts: [(identifier: Int, name: String)] = []
        
        do {
            for (_, promptData) in DefaultPrompts.prompts.enumerated() {
                // Create a prompt entry for each identifier
                for identifier in promptData.identifiers {
                    // Check if we already created this identifier for this prompt
                    if createdPrompts.contains(where: { $0.identifier == identifier && $0.name == promptData.name }) {
                        continue
                    }
                    
                    let prompt = Prompt(context: context)
                    prompt.id = UUID()
                    prompt.name = promptData.name
                    prompt.display = promptData.display
                    prompt.content = promptData.content
                    prompt.type = promptData.type
                    prompt.createdAt = Date()
                    prompt.updatedAt = Date()
                    prompt.recordStatus = 0
                    prompt.order = Int16(promptData.order)
                    prompt.intro = promptData.intro
                    prompt.identifier = Int16(identifier)
                    
                    // Track created prompt
                    createdPrompts.append((identifier: identifier, name: promptData.name))
                }
            }
            
            // Save context
            try context.save()
            
            // Verify ingestion
            let verifyRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            let results = try context.fetch(verifyRequest)
            
            // Only log if there's a mismatch
            if results.count != createdPrompts.count {
                logger.error("""
                    Prompt ingestion verification failed:
                    - Expected prompts: \(createdPrompts.count)
                    - Actual prompts in DB: \(results.count)
                    - Created prompt IDs: \(createdPrompts.map { $0.identifier }.sorted())
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