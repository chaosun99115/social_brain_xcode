import Foundation
import CoreData
import os.log

/// A class responsible for generating system and user prompts for the Social Brain feature
class PromptGenerator {
    static let shared = PromptGenerator()
    private let promptManager = PromptConfigurationManager.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "PromptGenerator")
    
    // Flow instancesx
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
            return questionFlow
        case 2: // Regular mode - Chat flow
            return questionFlow
        case 3: // Indie dev - Question flow
            return questionFlow
        case 4: // Changed job - Question flow
            return questionFlow
        case 5: // Contact - Contact flow
            return contactFlow
        case 6: // Note - Note flow
            return noteFlow
        case 7: // Sample 1 (Changed job)
            return questionFlow
        case 8: // Sample 2 (Indie dev)
            return questionFlow
        case 9: // Sample (Changed job & Indie dev)
            return questionFlow
        case 0: // Changed job contact - Contact flow
            return chatFlow
        case 999:
            return questionFlow
        default:
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
        // Use getFlow to determine the appropriate flow based on promptIdentifier
        let flow = getFlow(for: promptIdentifier) as! PromptFlowProtocol
        
        let result = try await flow.generatePrompts(
            sourceType: sourceType,
            sourceAction: sourceAction,
            sourceId: sourceId,
            sampleMode: sampleMode,
            contact: contact,
            promptDisplay: promptDisplay,
            promptIdentifier: promptIdentifier
        )
        
        return result
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
} 