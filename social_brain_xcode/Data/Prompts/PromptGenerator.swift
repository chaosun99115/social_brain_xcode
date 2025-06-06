import Foundation
import CoreData

/// A class responsible for generating system and user prompts for the Social Brain feature
class PromptGenerator {
    static let shared = PromptGenerator()
    private let promptManager = PromptConfigurationManager.shared
    
    private init() {}
    
    /// Generates a system prompt based on the given context
    /// - Parameters:
    ///   - sourceType: The type of source (e.g., "contact")
    ///   - sourceAction: The action being performed (e.g., "general", "insights")
    ///   - sourceId: The ID of the source (e.g., contact ID)
    ///   - sampleMode: Optional sample mode type
    ///   - contact: Optional contact for context
    ///   - promptIdentifier: The identifier of the prompt (0 for custom questions)
    ///   - promptDisplay: The display text of the prompt (custom question for custom prompts)
    /// - Returns: A tuple containing the system prompt and any error that occurred
    func generateSystemPrompt(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptIdentifier: Int = 0,
        promptDisplay: String? = nil
    ) async throws -> String {
        // Log only metadata and identifiers
        print("[PromptGenerator] Generating prompt - Type: \(sourceType), Action: \(sourceAction), ID: \(sourceId), PromptID: \(promptIdentifier)")
        if let contactName = contact?.name {
            print("[PromptGenerator] Contact: \(contactName)")
        }
        if let mode = sampleMode {
            print("[PromptGenerator] Sample Mode: \(mode)")
        }
        if let display = promptDisplay {
            print("[PromptGenerator] Prompt Display: \(display)")
        }
        
        // First try to get prompts from configuration if we have a valid identifier
        if promptIdentifier > 0 {
            let context = try await CoreDataManager.shared.viewContext
            let prompts = promptManager.getPromptsForSourceType(
                sourceType,
                sampleMode: sampleMode,
                context: context,
                contact: contact
            )
            
            if let firstPrompt = prompts.first(where: { $0.identifier == promptIdentifier }) {
                print("[PromptGenerator] Using configured prompt with ID: \(firstPrompt.identifier)")
                let prompts = promptManager.getSystemAndUserPrompts(from: firstPrompt)
                return prompts.systemPrompt
            }
        }
        
        // Fallback to dynamic prompt generation
        var prompt = "system prompt"
        
        // Add prompt context if available
        if let display = promptDisplay {
            prompt += "\nUser Question: \(display)\n"
        }
        
        switch (sourceType, sourceAction) {
        case ("contact", "general"):
            if let contact = contact {
                prompt += "Contact is \(contact.name ?? "failed to load contact name"). "
                
                // Add contact-specific context
                prompt += "You are analyzing a specific contact with ID: \(sourceId). "
                prompt += "Focus on providing insights about this contact's relationship with the user, "
                prompt += "suggesting conversation topics, and identifying opportunities for deeper connection."
                
                // Add notes context if available
                if let sampleProvider = getSampleProvider(for: sampleMode) {
                    let context = PromptContext(
                        mode: SampleMode(rawValue: sampleMode ?? "") ?? .none,
                        question: "",
                        contact: contact
                    )
                    let notesContext = try await sampleProvider.fetchRelevantNotes(for: context)
                    if !notesContext.isEmpty {
                        prompt += notesContext
                    }
                }
            } else {
                prompt += "contact + general (ID: \(sourceId)). "
                prompt += "Focus on general relationship management, communication strategies, and maintaining healthy connections."
            }
            
        default:
            prompt += "You are providing general social relationship advice."
        }
        
        // Only log that we generated a prompt, not its content
        print("[PromptGenerator] Generated system prompt (content hidden)")
        return prompt
    }
    
    /// Updates an existing system prompt with additional notes
    /// - Parameters:
    ///   - currentPrompt: The current system prompt
    ///   - notes: The notes to add to the prompt
    /// - Returns: The updated system prompt
    func updateSystemPromptWithNotes(_ currentPrompt: String, notes: String) -> String {
        print("[PromptGenerator] Updating system prompt with notes")
        
        // First check if the system prompt already contains these notes
        if !currentPrompt.contains(notes) {
            // If not, append them or update accordingly
            if !currentPrompt.contains("相关笔记如下:") {
                return currentPrompt + "\n\n相关笔记如下:\n" + notes
            } else {
                // If it already has notes section but different notes, replace it
                let components = currentPrompt.components(separatedBy: "相关笔记如下:")
                if components.count > 1 {
                    return components[0] + "相关笔记如下:\n" + notes
                }
            }
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
        switch (sourceType, sourceAction) {
        case ("contact", "general"):
            if let contact = contact {
                return "关于 \(contact.name ?? "这个联系人")，你想问什么"
            }
            return "关于这个联系人，你想问什么"
        case ("contact", "insights"):
            return "Please analyze this contact and provide insights about our relationship."
        default:
            return "How can you help me with my social relationships?"
        }
    }
    
    /// Extracts the user's question from text that may contain notes
    /// - Parameter text: The input text that may contain both question and notes
    /// - Returns: The extracted question
    func extractUserQuestion(from text: String) -> String {
        let noteMarkers = ["相关笔记如下:", "笔记如下", "Notes:"]
        
        for marker in noteMarkers {
            if let range = text.range(of: marker) {
                let questionPart = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                return questionPart.isEmpty ? "请分析这些笔记" : questionPart
            }
        }
        return text
    }
    
    /// Extracts notes from text that may contain both question and notes
    /// - Parameter text: The input text that may contain both question and notes
    /// - Returns: The extracted notes, if any
    func extractNotes(from text: String) -> String? {
        let noteMarkers = ["相关笔记如下:", "笔记如下", "Notes:"]
        
        for marker in noteMarkers {
            if let range = text.range(of: marker) {
                return String(text[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func getSampleProvider(for sampleMode: String?) -> SampleModeProvider? {
        guard let modeType = sampleMode else { return nil }
        return SampleModeProviderFactory.getProvider(for: modeType)
    }
} 