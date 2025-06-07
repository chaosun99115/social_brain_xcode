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
    
    private init() {
        // Remove initialization log
    }
    
    /// Gets the appropriate flow based on the prompt identifier
    /// - Parameter promptIdentifier: The identifier of the prompt
    /// - Returns: The appropriate flow instance
    private func getFlow(for promptIdentifier: Int) -> Any {
        switch promptIdentifier {
        case 1, 2: // Sample mode prompts
            logger.debug("[PromptGenerator] Using SampleFlow for prompt ID: \(promptIdentifier)")
            return sampleFlow
        case 5: // Contact-specific prompts
            logger.debug("[PromptGenerator] Using ContactFlow for prompt ID: \(promptIdentifier)")
            return contactFlow
        case 0: 
            logger.debug("[PromptGenerator] Using ChatFlow for prompt ID: \(promptIdentifier)")
            return chatFlow
        case 6: 
            logger.debug("[PromptGenerator] Using NoteFlow for prompt ID: \(promptIdentifier)")
            return noteFlow
        default: // General prompts
            logger.debug("[PromptGenerator] Using ChatFlow for prompt ID: \(promptIdentifier)")
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
    func generateSystemPrompt(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> String {
        // Log input parameters
        logger.debug("""
            ╔════════════════════════════════════════════════════════════╗
            ║                PromptGenerator Input Parameters             ║
            ╠════════════════════════════════════════════════════════════╣
            ║ Source Type: \(sourceType.padding(toLength: 40, withPad: " ", startingAt: 0)) ║
            ║ Source Action: \(sourceAction.padding(toLength: 38, withPad: " ", startingAt: 0)) ║
            ║ Source ID: \(sourceId.padding(toLength: 42, withPad: " ", startingAt: 0)) ║
            ║ Sample Mode: \(sampleMode?.padding(toLength: 40, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 40, withPad: " ", startingAt: 0)) ║
            ║ Prompt ID: \(promptIdentifier.description.padding(toLength: 42, withPad: " ", startingAt: 0)) ║
            ║ Contact: \(contact?.name?.padding(toLength: 43, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 43, withPad: " ", startingAt: 0)) ║
            ║ Display: \(promptDisplay?.padding(toLength: 43, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 43, withPad: " ", startingAt: 0)) ║
            ╚════════════════════════════════════════════════════════════╝
            """)
        
        // Get the appropriate flow based on the prompt identifier
        let flow = getFlow(for: promptIdentifier)
        
        do {
            // Generate the prompt using the selected flow
            let prompt: String
            switch flow {
            case let sample as SampleFlow:
                prompt = try await sample.generateSystemPrompt(
                    sourceType: sourceType,
                    sourceAction: sourceAction,
                    sourceId: sourceId,
                    sampleMode: sampleMode,
                    contact: contact,
                    promptDisplay: promptDisplay,
                    promptIdentifier: promptIdentifier
                )
            case let contactFlow as ContactFlow:
                prompt = try await contactFlow.generateSystemPrompt(
                    sourceType: sourceType,
                    sourceAction: sourceAction,
                    sourceId: sourceId,
                    sampleMode: sampleMode,
                    contact: contact,
                    promptDisplay: promptDisplay,
                    promptIdentifier: promptIdentifier
                )
            case let chat as ChatFlow:
                prompt = try await chat.generateSystemPrompt(
                    sourceType: sourceType,
                    sourceAction: sourceAction,
                    sourceId: sourceId,
                    sampleMode: sampleMode,
                    contact: contact,
                    promptDisplay: promptDisplay,
                    promptIdentifier: promptIdentifier
                )
            case let note as NoteFlow:
                prompt = try await note.generateSystemPrompt(
                    sourceType: sourceType,
                    sourceAction: sourceAction,
                    sourceId: sourceId,
                    sampleMode: sampleMode,
                    contact: contact,
                    promptDisplay: promptDisplay,
                    promptIdentifier: promptIdentifier
                )
            default:
                logger.error("""
                    ╔════════════════════════════════════════════════════════════╗
                    ║              PromptGenerator Error                         ║
                    ╠════════════════════════════════════════════════════════════╣
                    ║ Error: Unknown flow type for prompt ID: \(promptIdentifier) ║
                    ╚════════════════════════════════════════════════════════════╝
                    """)
                throw PromptError.promptNotFound
            }
            
            logger.debug("""
                ╔════════════════════════════════════════════════════════════╗
                ║              PromptGenerator Success                        ║
                ╚════════════════════════════════════════════════════════════╝
                """)
            return prompt
        } catch {
            logger.error("""
                ╔════════════════════════════════════════════════════════════╗
                ║              PromptGenerator Error                         ║
                ╠════════════════════════════════════════════════════════════╣
                ║ Error: \(error.localizedDescription.padding(toLength: 40, withPad: " ", startingAt: 0)) ║
                ╚════════════════════════════════════════════════════════════╝
                """)
            throw error
        }
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
    
    /// Generates an initial message based on the context
    /// - Parameters:
    ///   - sourceType: The type of source
    ///   - sourceAction: The action being performed
    ///   - contact: Optional contact for context
    /// - Returns: The initial message
    func generateInitialMessage(
        sourceType: String,
        sourceAction: String,
        contact: Contact?
    ) -> String {
        logger.debug("""
            ╔════════════════════════════════════════════════════════════╗
            ║              Generating Initial Message                     ║
            ╠════════════════════════════════════════════════════════════╣
            ║ Source Type: \(sourceType.padding(toLength: 40, withPad: " ", startingAt: 0)) ║
            ║ Source Action: \(sourceAction.padding(toLength: 38, withPad: " ", startingAt: 0)) ║
            ║ Contact: \(contact?.name?.padding(toLength: 43, withPad: " ", startingAt: 0) ?? "none".padding(toLength: 43, withPad: " ", startingAt: 0)) ║
            ╚════════════════════════════════════════════════════════════╝
            """)
        
        // Determine which flow to use based on the source type
        let message: String
        switch sourceType {
        case "contact":
            logger.debug("[PromptGenerator] Using ContactFlow for initial message")
            message = contactFlow.generateInitialMessage(
                sourceType: sourceType,
                sourceAction: sourceAction,
                contact: contact
            )
        case "sample":
            logger.debug("[PromptGenerator] Using SampleFlow for initial message")
            message = sampleFlow.generateInitialMessage(
                sourceType: sourceType,
                sourceAction: sourceAction,
                contact: contact
            )
        default:
            logger.debug("[PromptGenerator] Using ChatFlow for initial message")
            message = chatFlow.generateInitialMessage(
                sourceType: sourceType,
                sourceAction: sourceAction,
                contact: contact
            )
        }
        
        logger.debug("[PromptGenerator] Generated initial message: \(message)")
        return message
    }
    
    /// Extracts the user's question from text that may contain notes
    /// - Parameter text: The input text that may contain both question and notes
    /// - Returns: The extracted question
    func extractUserQuestion(from text: String) -> String {
        logger.debug("[PromptGenerator] Extracting user question from text")
        
        let noteMarkers = ["相关笔记如下:", "笔记如下", "Notes:"]
        
        for marker in noteMarkers {
            if let range = text.range(of: marker) {
                let questionPart = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let question = questionPart.isEmpty ? "请分析这些笔记" : questionPart
                logger.debug("[PromptGenerator] Extracted question: \(question)")
                return question
            }
        }
        
        logger.debug("[PromptGenerator] No notes found, using full text as question")
        return text
    }
    
    /// Extracts notes from text that may contain both question and notes
    /// - Parameter text: The input text that may contain both question and notes
    /// - Returns: The extracted notes, if any
    func extractNotes(from text: String) -> String? {
        logger.debug("[PromptGenerator] Extracting notes from text")
        
        let noteMarkers = ["相关笔记如下:", "笔记如下", "Notes:"]
        
        for marker in noteMarkers {
            if let range = text.range(of: marker) {
                let notes = String(text[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                logger.debug("[PromptGenerator] Found notes with marker: \(marker)")
                return notes
            }
        }
        
        logger.debug("[PromptGenerator] No notes found in text")
        return nil
    }
} 