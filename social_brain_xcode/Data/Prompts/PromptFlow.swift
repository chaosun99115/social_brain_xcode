import Foundation
import CoreData
import os.log

/// Flow for handling sample mode prompts
class SampleFlow {
    private let promptManager = PromptConfigurationManager.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "SampleFlow")
    
    private func logPromptGeneration(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        promptIdentifier: Int?,
        contactName: String?
    ) {
        logger.debug("""
            ╔════════════════════════════════════════════════════════════╗
            ║                    SampleFlow Input Parameters             ║
            ╠════════════════════════════════════════════════════════════╣
            ║ Source Type: \(sourceType.padding(toLength: 40, withPad: " ", startingAt: 0)) ║
            ║ Source Action: \(sourceAction.padding(toLength: 38, withPad: " ", startingAt: 0)) ║
            ║ Source ID: \(sourceId.padding(toLength: 42, withPad: " ", startingAt: 0)) ║
            ║ Sample Mode: \(sampleMode?.padding(toLength: 40, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 40, withPad: " ", startingAt: 0)) ║
            ║ Prompt ID: \(promptIdentifier?.description.padding(toLength: 42, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 42, withPad: " ", startingAt: 0)) ║
            ║ Contact: \(contactName?.padding(toLength: 43, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 43, withPad: " ", startingAt: 0)) ║
            ╚════════════════════════════════════════════════════════════╝
            """)
    }
    
    private func logPromptResult(success: Bool, error: Error? = nil) {
        if success {
            logger.debug("""
                ╔════════════════════════════════════════════════════════════╗
                ║                    SampleFlow Success                      ║
                ╚════════════════════════════════════════════════════════════╝
                """)
        } else {
            logger.error("""
                ╔════════════════════════════════════════════════════════════╗
                ║                    SampleFlow Error                        ║
                ╠════════════════════════════════════════════════════════════╣
                ║ Error: \(error?.localizedDescription.padding(toLength: 40, withPad: " ", startingAt: 0) ?? "unknown error".padding(toLength: 40, withPad: " ", startingAt: 0)) ║
                ╚════════════════════════════════════════════════════════════╝
                """)
        }
    }
    
    func generateSystemPrompt(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> String {
        logPromptGeneration(
            sourceType: sourceType,
            sourceAction: sourceAction,
            sourceId: sourceId,
            sampleMode: sampleMode,
            promptIdentifier: promptIdentifier,
            contactName: contact?.name
        )
        
        guard let sampleMode = sampleMode else {
            logger.error("""
                ╔════════════════════════════════════════════════════════════╗
                ║                    SampleFlow Error                        ║
                ╠════════════════════════════════════════════════════════════╣
                ║ Error: Invalid sample mode: mode is nil                    ║
                ╚════════════════════════════════════════════════════════════╝
                """)
            throw PromptError.invalidSampleMode
        }
        
        logger.debug("[SampleFlow] Fetching prompts for sample mode: \(sampleMode)")
        let context = try await CoreDataManager.shared.viewContext
        let prompts = promptManager.getPromptsForSourceType(
            sourceType,
            sampleMode: sampleMode,
            context: context,
            contact: contact
        )
        
        // Get the appropriate prompt identifier based on the sample mode
        let promptIdentifier: Int
        switch sampleMode {
        case "changedJob":
            promptIdentifier = 111
        case "indieDev":
            promptIdentifier = 121
        default:
            promptIdentifier = 1
        }
        
        logger.debug("[SampleFlow] Using prompt identifier: \(promptIdentifier)")
        
        if let prompt = prompts.first(where: { $0.identifier == promptIdentifier }) {
            logger.debug("[SampleFlow] Found configured prompt with ID: \(prompt.identifier)")
            let prompts = promptManager.getSystemAndUserPrompts(from: prompt)
            logPromptResult(success: true)
            return prompts.systemPrompt
        }
        
        logger.error("[SampleFlow] No prompt found for identifier: \(promptIdentifier)")
        throw PromptError.promptNotFound
    }
    
    func generateInitialMessage(
        sourceType: String,
        sourceAction: String,
        contact: Contact?
    ) -> String {
        logger.debug("""
            ╔════════════════════════════════════════════════════════════╗
            ║              SampleFlow Initial Message                     ║
            ╚════════════════════════════════════════════════════════════╝
            """)
        return "How can I help you with this scenario?"
    }
}

/// Flow for handling contact-specific prompts
class ContactFlow {
    private let promptManager = PromptConfigurationManager.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "ContactFlow")
    
    private func logPromptGeneration(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        promptIdentifier: Int?,
        contactName: String?
    ) {
        logger.debug("""
            ╔════════════════════════════════════════════════════════════╗
            ║                    ContactFlow Input Parameters             ║
            ╠════════════════════════════════════════════════════════════╣
            ║ Source Type: \(sourceType.padding(toLength: 40, withPad: " ", startingAt: 0)) ║
            ║ Source Action: \(sourceAction.padding(toLength: 38, withPad: " ", startingAt: 0)) ║
            ║ Source ID: \(sourceId.padding(toLength: 42, withPad: " ", startingAt: 0)) ║
            ║ Sample Mode: \(sampleMode?.padding(toLength: 40, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 40, withPad: " ", startingAt: 0)) ║
            ║ Prompt ID: \(promptIdentifier?.description.padding(toLength: 42, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 42, withPad: " ", startingAt: 0)) ║
            ║ Contact: \(contactName?.padding(toLength: 43, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 43, withPad: " ", startingAt: 0)) ║
            ╚════════════════════════════════════════════════════════════╝
            """)
    }
    
    private func logPromptResult(success: Bool, error: Error? = nil) {
        if success {
            logger.debug("""
                ╔════════════════════════════════════════════════════════════╗
                ║                    ContactFlow Success                      ║
                ╚════════════════════════════════════════════════════════════╝
                """)
        } else {
            logger.error("""
                ╔════════════════════════════════════════════════════════════╗
                ║                    ContactFlow Error                        ║
                ╠════════════════════════════════════════════════════════════╣
                ║ Error: \(error?.localizedDescription.padding(toLength: 40, withPad: " ", startingAt: 0) ?? "unknown error".padding(toLength: 40, withPad: " ", startingAt: 0)) ║
                ╚════════════════════════════════════════════════════════════╝
                """)
        }
    }
    
    func generateSystemPrompt(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> String {
        logPromptGeneration(
            sourceType: sourceType,
            sourceAction: sourceAction,
            sourceId: sourceId,
            sampleMode: sampleMode,
            promptIdentifier: promptIdentifier,
            contactName: contact?.name
        )
        
        guard let contact = contact else {
            logger.error("""
                ╔════════════════════════════════════════════════════════════╗
                ║                    ContactFlow Error                       ║
                ╠════════════════════════════════════════════════════════════╣
                ║ Error: Contact is required but was nil                     ║
                ╚════════════════════════════════════════════════════════════╝
                """)
            throw PromptError.contactRequired
        }
        
        logger.debug("[ContactFlow] Fetching prompts for contact: \(contact.name ?? "unnamed")")
        let context = try await CoreDataManager.shared.viewContext
        let prompts = promptManager.getPromptsForSourceType(
            sourceType,
            sampleMode: sampleMode,
            context: context,
            contact: contact
        )
        
        // Contact-specific prompts use identifier 5
        if let prompt = prompts.first(where: { $0.identifier == 5 }) {
            logger.debug("[ContactFlow] Found configured prompt with ID: \(prompt.identifier)")
            let prompts = promptManager.getSystemAndUserPrompts(from: prompt)
            logPromptResult(success: true)
            return prompts.systemPrompt
        }
        
        logger.debug("[ContactFlow] No configured prompt found, using dynamic generation")
        // Fallback to dynamic generation if no configured prompt found
        var prompt = "You are analyzing a specific contact with ID: \(sourceId). "
        prompt += "Focus on providing insights about this contact's relationship with the user, "
        prompt += "suggesting conversation topics, and identifying opportunities for deeper connection."
        
        if let display = promptDisplay {
            prompt += "\nUser Question: \(display)\n"
        }
        
        logPromptResult(success: true)
        return prompt
    }
    
    func generateInitialMessage(
        sourceType: String,
        sourceAction: String,
        contact: Contact?
    ) -> String {
        logger.debug("""
            ╔════════════════════════════════════════════════════════════╗
            ║              ContactFlow Initial Message                    ║
            ╠════════════════════════════════════════════════════════════╣
            ║ Contact: \(contact?.name?.padding(toLength: 43, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 43, withPad: " ", startingAt: 0)) ║
            ╚════════════════════════════════════════════════════════════╝
            """)
        if let contact = contact {
            return "关于 \(contact.name ?? "这个联系人")，你想问什么"
        }
        return "关于这个联系人，你想问什么"
    }
}

/// Flow for handling general prompts
class ChatFlow {
    private let promptManager = PromptConfigurationManager.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "ChatFlow")
    
    private func logPromptGeneration(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        promptIdentifier: Int?,
        contactName: String?
    ) {
        logger.debug("[ChatFlow] Generating prompt - ID: \(promptIdentifier ?? -1), Type: \(sourceType), Action: \(sourceAction)")
    }
    
    private func logPromptResult(success: Bool, error: Error? = nil) {
        if success {
            logger.debug("[ChatFlow] Prompt generation successful")
        } else {
            logger.error("[ChatFlow] Prompt generation failed: \(error?.localizedDescription ?? "unknown error")")
        }
    }
    
    func generateSystemPrompt(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> String {
        logPromptGeneration(
            sourceType: sourceType,
            sourceAction: sourceAction,
            sourceId: sourceId,
            sampleMode: sampleMode,
            promptIdentifier: promptIdentifier,
            contactName: contact?.name
        )
        
        let context = try await CoreDataManager.shared.viewContext
        
        // Fetch prompt entity directly using identifier
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %d", promptIdentifier)
        fetchRequest.fetchLimit = 1
        
        let prompts = try context.fetch(fetchRequest)
        
        if let prompt = prompts.first {
            guard let content = prompt.content else {
                logger.error("[ChatFlow] Prompt \(promptIdentifier) found but content is nil")
                throw PromptError.promptNotFound
            }
            
            logger.debug("""
                ╔════════════════════════════════════════════════════════════╗
                ║              ChatFlow Prompt Content                        ║
                ╠════════════════════════════════════════════════════════════╣
                ║ Prompt ID: \(promptIdentifier)                             ║
                ║ Content: \(content)                                        ║
                ╚════════════════════════════════════════════════════════════╝
                """)
            
            var systemPrompt = content
            
            if let display = promptDisplay {
                systemPrompt += "\n\nUser Question: \(display)"
            }
            
            logPromptResult(success: true)
            return systemPrompt
        }
        
        logger.error("[ChatFlow] No prompt found with identifier: \(promptIdentifier)")
        throw PromptError.promptNotFound
    }
    
    func generateInitialMessage(
        sourceType: String,
        sourceAction: String,
        contact: Contact?
    ) -> String {
        logger.debug("[ChatFlow] Generating initial message")
        return "How can you help me with my social relationships?"
    }
}

/// Flow for handling note-specific prompts
class NoteFlow {
    private let promptManager = PromptConfigurationManager.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "NoteFlow")
    
    /// Verifies that all default prompts are properly ingested
    static func verifyPromptIngestion() async {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "PromptVerification")
        
        logger.debug("""
            ╔════════════════════════════════════════════════════════════╗
            ║              Starting Prompt Verification                   ║
            ╚════════════════════════════════════════════════════════════╝
            """)
        
        do {
            let context = try await CoreDataManager.shared.viewContext
            let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            let existingPrompts = try context.fetch(fetchRequest)
            
            // Log existing prompts
            logger.debug("""
                ╔════════════════════════════════════════════════════════════╗
                ║              Existing Prompts in CoreData                   ║
                ╠════════════════════════════════════════════════════════════╣
                \(existingPrompts.map { "║ ID: \($0.identifier) - \($0.name ?? "unnamed")".padding(toLength: 58, withPad: " ", startingAt: 0) + "║" }.joined(separator: "\n"))
                ╚════════════════════════════════════════════════════════════╝
                """)
            
            // Get all expected prompt IDs from DefaultPrompts
            let expectedIds = Set(DefaultPrompts.prompts.flatMap { $0.identifiers })
            let existingIds = Set(existingPrompts.map { Int($0.identifier) })
            
            // Find missing prompts
            let missingIds = expectedIds.subtracting(existingIds)
            if !missingIds.isEmpty {
                logger.error("""
                    ╔════════════════════════════════════════════════════════════╗
                    ║              Missing Prompts                               ║
                    ╠════════════════════════════════════════════════════════════╣
                    \(missingIds.map { "║ Missing Prompt ID: \($0)".padding(toLength: 58, withPad: " ", startingAt: 0) + "║" }.joined(separator: "\n"))
                    ╚════════════════════════════════════════════════════════════╝
                    """)
            }
            
            // Find prompts with missing content
            let promptsWithMissingContent = existingPrompts.filter { $0.content == nil }
            if !promptsWithMissingContent.isEmpty {
                logger.error("""
                    ╔════════════════════════════════════════════════════════════╗
                    ║              Prompts with Missing Content                  ║
                    ╠════════════════════════════════════════════════════════════╣
                    \(promptsWithMissingContent.map { "║ ID: \($0.identifier) - \($0.name ?? "unnamed")".padding(toLength: 58, withPad: " ", startingAt: 0) + "║" }.joined(separator: "\n"))
                    ╚════════════════════════════════════════════════════════════╝
                    """)
            }
            
            // Log verification summary
            logger.debug("""
                ╔════════════════════════════════════════════════════════════╗
                ║              Verification Summary                           ║
                ╠════════════════════════════════════════════════════════════╣
                ║ Total Expected Prompts: \(expectedIds.count)                ║
                ║ Total Existing Prompts: \(existingIds.count)                ║
                ║ Missing Prompts: \(missingIds.count)                        ║
                ║ Prompts with Missing Content: \(promptsWithMissingContent.count) ║
                ╚════════════════════════════════════════════════════════════╝
                """)
            
        } catch {
            logger.error("""
                ╔════════════════════════════════════════════════════════════╗
                ║              Verification Error                            ║
                ╠════════════════════════════════════════════════════════════╣
                ║ Error: \(error.localizedDescription.padding(toLength: 40, withPad: " ", startingAt: 0)) ║
                ╚════════════════════════════════════════════════════════════╝
                """)
        }
    }
    
    func generateSystemPrompt(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> String {
        print("[NoteFlow] Starting generateSystemPrompt") // Direct print for immediate visibility
        
        // Log input parameters
        logger.debug("""
            ╔════════════════════════════════════════════════════════════╗
            ║                    NoteFlow Input Parameters                ║
            ╠════════════════════════════════════════════════════════════╣
            ║ Source Type: \(sourceType.padding(toLength: 40, withPad: " ", startingAt: 0)) ║
            ║ Source Action: \(sourceAction.padding(toLength: 38, withPad: " ", startingAt: 0)) ║
            ║ Source ID: \(sourceId.padding(toLength: 42, withPad: " ", startingAt: 0)) ║
            ║ Sample Mode: \(sampleMode?.padding(toLength: 40, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 40, withPad: " ", startingAt: 0)) ║
            ║ Prompt ID: \(promptIdentifier.description.padding(toLength: 42, withPad: " ", startingAt: 0)) ║
            ║ Contact: \(contact?.name?.padding(toLength: 43, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 43, withPad: " ", startingAt: 0)) ║
            ╚════════════════════════════════════════════════════════════╝
            """)
        
        print("[NoteFlow] About to get CoreData context") // Direct print
        let context = try await CoreDataManager.shared.viewContext
        print("[NoteFlow] Got CoreData context") // Direct print
        
        // First, let's verify all prompts in the database
        print("[NoteFlow] Starting to fetch all prompts") // Direct print
        let allPromptsRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        let allPrompts = try context.fetch(allPromptsRequest)
        print("[NoteFlow] Found \(allPrompts.count) total prompts") // Direct print
        
        // Log each prompt's details directly
        for prompt in allPrompts {
            print("[NoteFlow] Prompt in DB - ID: \(prompt.identifier), Name: \(prompt.name ?? "nil"), Content Length: \(prompt.content?.count ?? 0)")
        }
        
        // Now try to fetch the specific prompt
        print("[NoteFlow] Attempting to fetch prompt ID: \(promptIdentifier)") // Direct print
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %d", promptIdentifier)
        fetchRequest.fetchLimit = 1
        
        // Log the exact predicate being used
        print("[NoteFlow] Using predicate: identifier == \(promptIdentifier)") // Direct print
        
        let prompts = try context.fetch(fetchRequest)
        print("[NoteFlow] Fetch completed. Found \(prompts.count) matching prompts") // Direct print
        
        if let prompt = prompts.first {
            print("[NoteFlow] Found prompt - ID: \(prompt.identifier), Name: \(prompt.name ?? "nil")") // Direct print
            
            guard let content = prompt.content else {
                print("[NoteFlow] ERROR: Prompt found but content is nil") // Direct print
                logger.error("""
                    ╔════════════════════════════════════════════════════════════╗
                    ║                    NoteFlow Error                           ║
                    ╠════════════════════════════════════════════════════════════╣
                    ║ Error: Prompt \(promptIdentifier) found but content is nil  ║
                    ║ Name: \(prompt.name ?? "nil")                              ║
                    ║ Type: \(prompt.type)                                      ║
                    ║ Order: \(prompt.order)                                    ║
                    ╚════════════════════════════════════════════════════════════╝
                    """)
                throw PromptError.promptNotFound
            }
            
            // Log the prompt details
            print("[NoteFlow] Prompt content length: \(content.count)") // Direct print
            logger.debug("""
                ╔════════════════════════════════════════════════════════════╗
                ║                    NoteFlow Prompt Details                 ║
                ╠════════════════════════════════════════════════════════════╣
                ║ Prompt ID: \(promptIdentifier)                             ║
                ║ Content: \(content)                                        ║
                ║ User Prompt: \(promptDisplay ?? "none")                    ║
                ╚════════════════════════════════════════════════════════════╝
                """)
            
            // Use content as system prompt
            var systemPrompt = content
            
            // Append user prompt if available
            if let display = promptDisplay {
                systemPrompt += "\n\nUser Question: \(display)"
            }
            
            print("[NoteFlow] Successfully generated system prompt") // Direct print
            return systemPrompt
        } else {
            print("[NoteFlow] ERROR: No prompt found with ID: \(promptIdentifier)") // Direct print
            print("[NoteFlow] Available prompt IDs: \(allPrompts.map { String($0.identifier) }.joined(separator: ", "))") // Direct print
            
            logger.error("""
                ╔════════════════════════════════════════════════════════════╗
                ║                    NoteFlow Error                           ║
                ╠════════════════════════════════════════════════════════════╣
                ║ Error: No prompt found with identifier: \(promptIdentifier)  ║
                ║ Context:                                                    ║
                ║ - Source Type: \(sourceType)                                ║
                ║ - Source Action: \(sourceAction)                            ║
                ║ - Sample Mode: \(sampleMode ?? "none")                      ║
                ║ Available Prompt IDs: \(allPrompts.map { String($0.identifier) }.joined(separator: ", ")) ║
                ╚════════════════════════════════════════════════════════════╝
                """)
            throw PromptError.promptNotFound
        }
    }
    
    func generateInitialMessage(
        sourceType: String,
        sourceAction: String,
        contact: Contact?
    ) -> String {
        logger.debug("""
            ╔════════════════════════════════════════════════════════════╗
            ║              NoteFlow Initial Message                       ║
            ╚════════════════════════════════════════════════════════════╝
            """)
        return "What would you like to know about this note?"
    }
}

/// Errors that can occur during prompt generation
enum PromptError: Error {
    case invalidSampleMode
    case promptNotFound
    case contactRequired
    
    var localizedDescription: String {
        switch self {
        case .invalidSampleMode:
            return "Invalid or missing sample mode"
        case .promptNotFound:
            return "No prompt found for the given context"
        case .contactRequired:
            return "Contact is required but was not provided"
        }
    }
} 