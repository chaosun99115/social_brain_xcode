import Foundation
import CoreData

protocol PromptFlowProtocol {
    func generatePrompts(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> PromptPair
}

struct PromptPair {
    let systemPrompt: String
    let userPrompt: String?
}

/// Flow for handling sample mode prompts
class SampleFlow: PromptFlowProtocol {
    private let promptManager = PromptConfigurationManager.shared
    
    func generatePrompts(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> PromptPair {
        print("[SampleFlow] Generating prompts for:")
        print("- Source Type: \(sourceType)")
        print("- Source Action: \(sourceAction)")
        print("- Source ID: \(sourceId)")
        print("- Sample Mode: \(sampleMode ?? "none")")
        print("- Prompt ID: \(promptIdentifier)")
        print("- Contact: \(contact?.name ?? "none")")
        
        guard let sampleMode = sampleMode else {
            print("[SampleFlow] Error: Invalid sample mode - mode is nil")
            throw PromptError.invalidSampleMode
        }
        
        print("[SampleFlow] Fetching prompts for sample mode: \(sampleMode)")
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
        
        print("[SampleFlow] Using prompt identifier: \(promptIdentifier)")
        
        if let prompt = prompts.first(where: { $0.identifier == promptIdentifier }) {
            print("[SampleFlow] Found configured prompt with ID: \(prompt.identifier)")
            let prompts = promptManager.getSystemAndUserPrompts(from: prompt)
            let promptPair = PromptPair(
                systemPrompt: prompts.systemPrompt,
                userPrompt: prompts.userPrompt
            )
            print("[SampleFlow] Returning PromptPair:")
            print("--------------------------------")
            print("System Prompt: \(promptPair.systemPrompt)")
            if let userPrompt = promptPair.userPrompt {
                print("User Prompt: \(userPrompt)")
            } else {
                print("User Prompt: nil")
            }
            print("--------------------------------")
            return promptPair
        }
        
        print("[SampleFlow] Error: No prompt found for identifier: \(promptIdentifier)")
        throw PromptError.promptNotFound
    }
}

/// Flow for handling contact-specific prompts
class ContactFlow: PromptFlowProtocol {
    private let promptManager = PromptConfigurationManager.shared
    
    func generatePrompts(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> PromptPair {
        print("[ContactFlow] Generating prompts for:")
        print("- Source Type: \(sourceType)")
        print("- Source Action: \(sourceAction)")
        print("- Source ID: \(sourceId)")
        print("- Sample Mode: \(sampleMode ?? "none")")
        print("- Prompt ID: \(promptIdentifier)")
        print("- Contact: \(contact?.name ?? "none")")
        
        guard let contact = contact else {
            print("[ContactFlow] Error: Contact is required but was nil")
            throw PromptError.contactRequired
        }
        
        print("[ContactFlow] Fetching prompts for contact: \(contact.name ?? "unnamed")")
        let context = try await CoreDataManager.shared.viewContext
        let prompts = promptManager.getPromptsForSourceType(
            sourceType,
            sampleMode: sampleMode,
            context: context,
            contact: contact
        )
        
        // Contact-specific prompts use identifier 5
        if let prompt = prompts.first(where: { $0.identifier == 5 }) {
            print("[ContactFlow] Found configured prompt with ID: \(prompt.identifier)")
            let prompts = promptManager.getSystemAndUserPrompts(from: prompt)
            let promptPair = PromptPair(
                systemPrompt: prompts.systemPrompt,
                userPrompt: prompts.userPrompt
            )
            print("[ContactFlow] Returning PromptPair:")
            print("--------------------------------")
            print("System Prompt: \(promptPair.systemPrompt)")
            if let userPrompt = promptPair.userPrompt {
                print("User Prompt: \(userPrompt)")
            } else {
                print("User Prompt: nil")
            }
            print("--------------------------------")
            return promptPair
        }
        
        print("[ContactFlow] No configured prompt found, using dynamic generation")
        // Fallback to dynamic generation if no configured prompt found
        var systemPrompt = "You are analyzing a specific contact with ID: \(sourceId). "
        systemPrompt += "Focus on providing insights about this contact's relationship with the user, "
        systemPrompt += "suggesting conversation topics, and identifying opportunities for deeper connection."
        
        if let display = promptDisplay {
            systemPrompt += "\n\nUser Question: \(display)"
        }
        
        let promptPair = PromptPair(systemPrompt: systemPrompt, userPrompt: nil)
        print("[ContactFlow] Returning PromptPair (dynamic):")
        print("--------------------------------")
        print("System Prompt: \(promptPair.systemPrompt)")
        print("User Prompt: nil")
        print("--------------------------------")
        return promptPair
    }
}

/// Flow for handling general prompts
class ChatFlow: PromptFlowProtocol {
    private let promptManager = PromptConfigurationManager.shared
    
    func generatePrompts(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> PromptPair {
        print("[ChatFlow] Generating prompt - ID: \(promptIdentifier), Type: \(sourceType), Action: \(sourceAction)")
        
        let context = try await CoreDataManager.shared.viewContext
        
        // Fetch prompt entity directly using identifier
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %d", promptIdentifier)
        fetchRequest.fetchLimit = 1
        
        let prompts = try context.fetch(fetchRequest)
        
        if let prompt = prompts.first {
            guard let content = prompt.content else {
                print("[ChatFlow] Error: Prompt \(promptIdentifier) found but content is nil")
                throw PromptError.promptNotFound
            }
            
            print("[ChatFlow] Found prompt with ID: \(promptIdentifier)")
            print("Content: \(content)")
            
            var systemPrompt = content
            
            if let display = promptDisplay {
                systemPrompt += "\n\nUser Question: \(display)"
            }
            
            let promptPair = PromptPair(systemPrompt: systemPrompt, userPrompt: nil)
            print("[ChatFlow] Returning PromptPair:")
            print("--------------------------------")
            print("System Prompt: \(promptPair.systemPrompt)")
            print("User Prompt: nil")
            print("--------------------------------")
            return promptPair
        }
        
        print("[ChatFlow] Error: No prompt found with identifier: \(promptIdentifier)")
        throw PromptError.promptNotFound
    }
}

/// Flow for handling note-specific prompts
class NoteFlow: PromptFlowProtocol {
    private let promptManager = PromptConfigurationManager.shared
    
    func generatePrompts(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> PromptPair {
        let context = try await CoreDataManager.shared.viewContext
        
        // Fetch prompt entity directly using identifier
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %d", promptIdentifier)
        fetchRequest.fetchLimit = 1
        
        let prompts = try context.fetch(fetchRequest)
        
        if let prompt = prompts.first {
            guard let content = prompt.content else {
                print("[NoteFlow] Error - Prompt found but content is nil")
                throw PromptError.promptNotFound
            }
            
            let systemPrompt = content
            let promptPair = PromptPair(
                systemPrompt: systemPrompt,
                userPrompt: promptDisplay
            )
            
            print("[NoteFlow] Returning PromptPair:")
            print("--------------------------------")
            print("System Prompt: \(promptPair.systemPrompt)")
            if let userPrompt = promptPair.userPrompt {
                print("User Prompt: \(userPrompt)")
            } else {
                print("User Prompt: nil")
            }
            print("--------------------------------")
            
            return promptPair
        }
        
        print("[NoteFlow] Error - No prompt found with identifier: \(promptIdentifier)")
        throw PromptError.promptNotFound
    }
}

/// Flow for handling question-specific prompts
class QuestionFlow: PromptFlowProtocol {
    private let promptManager = PromptConfigurationManager.shared
    
    func generatePrompts(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> PromptPair {
        print("[QuestionFlow] Generating prompts for:")
        print("- Source Type: \(sourceType)")
        print("- Source Action: \(sourceAction)")
        print("- Source ID: \(sourceId)")
        print("- Sample Mode: \(sampleMode ?? "none")")
        print("- Prompt ID: \(promptIdentifier)")
        print("- Contact: \(contact?.name ?? "none")")
        
        guard let promptDisplay = promptDisplay else {
            print("[QuestionFlow] Error: Question display text is required but was nil")
            throw PromptError.questionRequired
        }
        
        let context = try await CoreDataManager.shared.viewContext
        
        // Fetch prompt entity directly using identifier
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %d", promptIdentifier)
        fetchRequest.fetchLimit = 1
        
        let prompts = try context.fetch(fetchRequest)
        
        if let prompt = prompts.first {
            guard let content = prompt.content else {
                print("[QuestionFlow] Error: Prompt \(promptIdentifier) found but content is nil")
                throw PromptError.promptNotFound
            }
            
            print("[QuestionFlow] Found prompt with ID: \(promptIdentifier)")
            
            // For questions, we'll use the prompt content as system prompt
            // and the promptDisplay as the user prompt
            let systemPrompt = content
            let userPrompt = promptDisplay
            
            let promptPair = PromptPair(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
            
            print("[QuestionFlow] Returning PromptPair:")
            print("--------------------------------")
            print("System Prompt: \(promptPair.systemPrompt)")
            if let userPrompt = promptPair.userPrompt {
                print("User Prompt: \(userPrompt)")
            } else {
                print("User Prompt: nil")
            }
            print("--------------------------------")
            
            return promptPair
        }
        
        print("[QuestionFlow] Error: No prompt found with identifier: \(promptIdentifier)")
        throw PromptError.promptNotFound
    }
}

/// Errors that can occur during prompt generation
enum PromptError: Error {
    case invalidSampleMode
    case promptNotFound
    case contactRequired
    case invalidFlow
    case questionRequired
    
    var localizedDescription: String {
        switch self {
        case .invalidSampleMode:
            return "Invalid or missing sample mode"
        case .promptNotFound:
            return "No prompt found for the given context"
        case .contactRequired:
            return "Contact is required but was not provided"
        case .invalidFlow:
            return "Invalid flow type for the given prompt identifier"
        case .questionRequired:
            return "Question text is required but was not provided"
        }
    }
} 