import Foundation
import CoreData
import os.log

/// A class responsible for generating system and user prompts for the Social Brain feature
class PromptGenerator {
    static let shared = PromptGenerator()
    private let promptManager = PromptConfigurationManager.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "PromptGenerator")
    
    // Flow instances
    private let sampleFlow = SampleFlow()
    private let contactFlow = ContactFlow()
    private let chatFlow = ChatFlow()
    private let noteFlow = NoteFlow()
    private let questionFlow = QuestionFlow()
    
    private init() {
        // Remove initialization log
    }
    
    /// Gets the appropriate flow based on the prompt identifier
    /// - Parameter promptIdentifier: The identifier of the prompt
    /// - Returns: The appropriate flow instance
    private func getFlow(for promptIdentifier: Int) -> Any {
        // Each prompt identifier should map to exactly one flow
        switch promptIdentifier {
        case 1: // Regular mode - Chat flow
            logger.debug("[PromptGenerator] Using ChatFlow for prompt ID: \(promptIdentifier)")
            return chatFlow
        case 2: // Regular mode - Chat flow
            logger.debug("[PromptGenerator] Using ChatFlow for prompt ID: \(promptIdentifier)")
            return chatFlow
        case 3: // Indie dev - Question flow
            logger.debug("[PromptGenerator] Using QuestionFlow for prompt ID: \(promptIdentifier)")
            return questionFlow
        case 4: // Changed job - Question flow
            logger.debug("[PromptGenerator] Using QuestionFlow for prompt ID: \(promptIdentifier)")
            return questionFlow
        case 5: // Contact - Contact flow
            logger.debug("[PromptGenerator] Using ContactFlow for prompt ID: \(promptIdentifier)")
            return contactFlow
        case 6: // Note - Note flow
            logger.debug("[PromptGenerator] Using NoteFlow for prompt ID: \(promptIdentifier)")
            return noteFlow
        case 9: // Changed job contact - Contact flow
            logger.debug("[PromptGenerator] Using ContactFlow for prompt ID: \(promptIdentifier)")
            return contactFlow
        case 10: // Indie dev contact - Contact flow
            logger.debug("[PromptGenerator] Using ContactFlow for prompt ID: \(promptIdentifier)")
            return contactFlow
        case 12: // Changed job note - Note flow
            logger.debug("[PromptGenerator] Using NoteFlow for prompt ID: \(promptIdentifier)")
            return noteFlow
        case 13: // Indie dev note - Note flow
            logger.debug("[PromptGenerator] Using NoteFlow for prompt ID: \(promptIdentifier)")
            return noteFlow
        default:
            logger.debug("[PromptGenerator] Using ChatFlow for default prompt ID: \(promptIdentifier)")
            return chatFlow
        }
    }
    
    /// Generates a system prompt based on the given context
    /// - Parameters:
    ///   - sourceType: The type of source (e.g., "contact")
    ///   - sourceAction: The action being performed (e.g., "general", "insights")
    ///   - sourceId: The unique identifier of the source
    ///   - sampleMode: Optional sample mode for testing
    ///   - contact: Optional contact for context
    ///   - promptDisplay: Optional display text for the prompt
    ///   - promptIdentifier: The identifier of the prompt to use
    /// - Returns: The generated system prompt
    func generatePrompts(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> PromptPair {
        print("[PromptGenerator] Generating prompts for:")
        print("- Source Type: \(sourceType)")
        print("- Source Action: \(sourceAction)")
        print("- Source ID: \(sourceId)")
        print("- Sample Mode: \(sampleMode ?? "none")")
        print("- Prompt ID: \(promptIdentifier)")
        print("- Contact: \(contact?.name ?? "none")")
        
        // Use getFlow to determine the appropriate flow based on promptIdentifier
        let flow = getFlow(for: promptIdentifier) as! PromptFlowProtocol
        
        return try await flow.generatePrompts(
            sourceType: sourceType,
            sourceAction: sourceAction,
            sourceId: sourceId,
            sampleMode: sampleMode,
            contact: contact,
            promptDisplay: promptDisplay,
            promptIdentifier: promptIdentifier
        )
    }
    
    /// Generates a system prompt based on the given context
    /// - Parameters:
    ///   - sourceType: The type of source (e.g., "contact")
    ///   - sourceAction: The action being performed (e.g., "general", "insights")
    ///   - sourceId: The unique identifier of the source
    ///   - sampleMode: Optional sample mode for testing
    ///   - contact: Optional contact for context
    ///   - promptDisplay: Optional display text for the prompt
    ///   - promptIdentifier: The identifier of the prompt to use
    /// - Returns: The generated system prompt
    func generateSystemPrompt(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> String {
        let promptPair = try await generatePrompts(
            sourceType: sourceType,
            sourceAction: sourceAction,
            sourceId: sourceId,
            sampleMode: sampleMode,
            contact: contact,
            promptDisplay: promptDisplay,
            promptIdentifier: promptIdentifier
        )
        return promptPair.systemPrompt
    }
    
    /// Updates an existing system prompt with additional notes
    /// - Parameters:
    ///   - currentPrompt: The current system prompt
    ///   - notes: The notes to add to the prompt
    /// - Returns: The updated system prompt
    func updateSystemPromptWithNotes(_ currentPrompt: String, notes: String) -> String {
        logger.debug("""
            ╔════════════════════════════════════════════════════════════╗
            ║              Updating System Prompt with Notes              ║
            ╚════════════════════════════════════════════════════════════╝
            """)
        
        // First check if the system prompt already contains these notes
        if !currentPrompt.contains(notes) {
            logger.debug("[PromptGenerator] Adding new notes to prompt")
            // If not, append them or update accordingly
            if !currentPrompt.contains("相关笔记如下:") {
                return currentPrompt + "\n\n相关笔记如下:\n" + notes
            } else {
                // If it already has notes section but different notes, replace it
                logger.debug("[PromptGenerator] Replacing existing notes section")
                let components = currentPrompt.components(separatedBy: "相关笔记如下:")
                if components.count > 1 {
                    return components[0] + "相关笔记如下:\n" + notes
                }
            }
        } else {
            logger.debug("[PromptGenerator] Notes already present in prompt, no update needed")
        }
        
        return currentPrompt
    }
    
    /// Extracts the user's question from text that may contain notes
    /// - Parameter text: The input text that may contain both question and notes
    /// - Returns: The extracted question
    func extractUserQuestion(from text: String) -> String {
        // Remove any notes section if present
        let components = text.components(separatedBy: "\n\nNotes:")
        let questionPart = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        return questionPart
    }
    
    /// Extracts notes from text that may contain both question and notes
    /// - Parameter text: The input text that may contain both question and notes
    /// - Returns: The extracted notes, if any
    func extractNotes(from text: String) -> String? {
        let components = text.components(separatedBy: "\n\nNotes:")
        guard components.count > 1 else { return nil }
        return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 