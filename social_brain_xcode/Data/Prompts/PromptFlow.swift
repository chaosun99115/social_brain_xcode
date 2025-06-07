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