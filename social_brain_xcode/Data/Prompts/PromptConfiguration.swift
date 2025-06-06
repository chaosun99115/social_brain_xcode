import Foundation
import CoreData

/// Represents the mode in which prompts are displayed
enum PromptDisplayMode {
    case regular    // Shows prompt with identifier = 1
    case sample     // Shows prompts with identifier != 1
}

/// Configuration for sample mode prompt selection
struct SampleModePromptConfig {
    let identifier: Int
    let displayName: String
    let description: String
}

/// Protocol defining prompt display behavior
protocol PromptDisplayable {
    var identifier: Int { get }
    var display: String { get }
    var content: String { get }
}

/// Adapter to make Prompt conform to PromptDisplayable
struct PromptAdapter: PromptDisplayable {
    private let prompt: Prompt
    
    init(prompt: Prompt) {
        self.prompt = prompt
    }
    
    var identifier: Int { Int(prompt.identifier) }
    var display: String { prompt.display ?? "" }
    var content: String { prompt.content ?? "" }
}

/// Configuration for sample mode prompt mapping
struct SampleModePromptMapping {
    /// Maps sample mode identifiers to their prompt identifiers
    static let modeToPromptIdentifiers: [String: [Int]] = [
        // Changed Job scenario prompts
        "changedJob": [111],  // Prompts for job change scenario
        // Indie Dev scenario prompts
        "indieDev": [121],      // Prompts for indie developer scenario
        // Add more mappings as needed
    ]
    
    /// Get prompt identifiers for a specific sample mode
    static func getPromptIdentifiers(for mode: String) -> [Int] {
        return modeToPromptIdentifiers[mode] ?? []
    }
    
    /// Check if a prompt identifier belongs to a specific sample mode
    static func isPromptInMode(_ identifier: Int, mode: String) -> Bool {
        return modeToPromptIdentifiers[mode]?.contains(identifier) ?? false
    }
}

/// Manages prompt configuration and display logic
class PromptConfigurationManager {
    static let shared = PromptConfigurationManager()
    
    private init() {
        // Verify default prompts on initialization
        Task {
            await verifyAndIngestDefaultPrompts()
        }
    }
    
    /// Verifies and ingests default prompts if they don't exist
    private func verifyAndIngestDefaultPrompts() async {
        do {
            let context = try await CoreDataManager.shared.viewContext

            // First verify if we need to ingest at all
            let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            let existingCount = try context.count(for: fetchRequest)
            
            // Detailed verification for each prompt identifier
            for identifier in [111, 121] {
                let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "identifier == %d", identifier)
                
                let count = try context.count(for: fetchRequest)
                
                if count == 0 {
                    // Find the prompt in DefaultPrompts
                    if let prompt = DefaultPrompts.prompts.first(where: { $0.identifiers.contains(identifier) }) {
                        let newPrompt = Prompt(context: context)
                        newPrompt.identifier = Int16(identifier)
                        newPrompt.name = prompt.name
                        newPrompt.intro = prompt.intro
                        newPrompt.display = prompt.display
                        newPrompt.content = prompt.content
                        newPrompt.type = prompt.type
                        
                        // Save immediately after creating each prompt
                        do {
                            try context.save()
                            
                            // Verify the save immediately
                            let verifyRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
                            verifyRequest.predicate = NSPredicate(format: "identifier == %d", identifier)
                            _ = try context.count(for: verifyRequest)
                        } catch {
                            // Handle error silently
                        }
                    }
                }
            }
            
            // Final verification of all prompts
            let finalFetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            _ = try context.fetch(finalFetchRequest)
            
        } catch {
            // Handle error silently
        }
    }
    
    /// Debug function to print all prompts in the database
    func printAllPrompts(context: NSManagedObjectContext) {
        // Removed debug print statements
    }
    
    /// Returns the appropriate prompt based on the current display mode and sample mode
    /// - Parameters:
    ///   - mode: The current display mode
    ///   - sampleMode: The current sample mode (if in sample mode)
    ///   - context: CoreData context
    /// - Returns: Array of prompts that match the criteria
    func getPromptsForMode(_ mode: PromptDisplayMode, sampleMode: String? = nil, context: NSManagedObjectContext) -> [PromptDisplayable] {
        // Ensure we're using the main context
        let mainContext = context.concurrencyType == .mainQueueConcurrencyType ? context : context.parent ?? context
        
        // Perform a quick verification of the database state
        do {
            let verifyRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            _ = try mainContext.count(for: verifyRequest)
            
            // If in sample mode, verify the specific prompt we're looking for
            if mode == .sample, let sampleMode = sampleMode {
                let identifiers = SampleModePromptMapping.getPromptIdentifiers(for: sampleMode)
                for identifier in identifiers {
                    let specificRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
                    specificRequest.predicate = NSPredicate(format: "identifier == %d", identifier)
                    _ = try mainContext.count(for: specificRequest)
                }
            }
        } catch {
            // Handle error silently
        }
        
        switch mode {
        case .regular:
            return fetchPromptsWithIdentifier(1, context: mainContext)
        case .sample:
            guard let sampleMode = sampleMode else {
                return []
            }
            
            // Get available prompt identifiers for this sample mode
            let availableIdentifiers = SampleModePromptMapping.getPromptIdentifiers(for: sampleMode)
            
            guard !availableIdentifiers.isEmpty else {
                return []
            }
            
            // Return all prompts for the available identifiers
            var prompts: [PromptDisplayable] = []
            for identifier in availableIdentifiers {
                let fetchedPrompts = fetchPromptsWithIdentifier(identifier, context: mainContext)
                prompts.append(contentsOf: fetchedPrompts)
            }
            return prompts
        }
    }
    
    /// Fetches all prompts from CoreData by identifier
    private func fetchPromptsWithIdentifier(_ identifier: Int, context: NSManagedObjectContext) -> [PromptDisplayable] {
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %d", identifier)
        
        // Add sort descriptors to order by order (ascending) and updatedAt (descending)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Prompt.order, ascending: true),
            NSSortDescriptor(keyPath: \Prompt.updatedAt, ascending: false)
        ]
        
        do {
            // Ensure we're on the correct queue for the context
            if context.concurrencyType == .mainQueueConcurrencyType {
                if !Thread.isMainThread {
                    // Handle background thread access silently
                }
            }
            
            let results = try context.fetch(fetchRequest)
            
            // Verify the results are still valid
            if !results.isEmpty {
                for result in results {
                    if result.isFault {
                        context.refresh(result, mergeChanges: true)
                    }
                }
            }
            
            return results.map { PromptAdapter(prompt: $0) }
        } catch {
            return []
        }
    }
    
    /// Returns the appropriate prompt based on the current display mode and sample mode
    /// - Parameters:
    ///   - mode: The current display mode
    ///   - sampleMode: The current sample mode (if in sample mode)
    ///   - context: CoreData context
    /// - Returns: The selected prompt if available
    func getPromptForMode(_ mode: PromptDisplayMode, sampleMode: String? = nil, context: NSManagedObjectContext) -> PromptDisplayable? {
        let prompts = getPromptsForMode(mode, sampleMode: sampleMode, context: context)
        return prompts.first
    }
    
    /// Returns the system prompt and user prompt for a given prompt
    /// - Parameter prompt: The prompt to process
    /// - Returns: Tuple containing system prompt and user prompt
    func getSystemAndUserPrompts(from prompt: PromptDisplayable) -> (systemPrompt: String, userPrompt: String) {
        return (
            systemPrompt: prompt.content,
            userPrompt: prompt.display
        )
    }
    
    /// Validates if the current prompt configuration matches the available sample modes
    func validateSampleModeConfiguration() -> Bool {
        // Get all configured sample modes from SampleModeConfig
        let configuredModes = SampleModeConfig.availableModes.map { $0.id }
        
        // Check if all configured modes have prompt mappings
        for mode in configuredModes {
            if SampleModePromptMapping.getPromptIdentifiers(for: mode).isEmpty {
                print("Warning: Sample mode '\(mode)' has no prompt mappings")
                return false
            }
        }
        
        // Check if all prompt mappings correspond to configured modes
        for mode in SampleModePromptMapping.modeToPromptIdentifiers.keys {
            if !configuredModes.contains(mode) {
                print("Warning: Prompt mapping exists for undefined sample mode '\(mode)'")
                return false
            }
        }
        
        return true
    }
    
    // Add a new function to force re-ingestion if needed
    func forceReingestDefaultPrompts() async {
        do {
            let context = try await CoreDataManager.shared.viewContext
            
            // Clear existing prompts
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Prompt.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
            try context.save()
            
            // Re-ingest all prompts
            for prompt in DefaultPrompts.prompts {
                for identifier in prompt.identifiers {
                    let newPrompt = Prompt(context: context)
                    newPrompt.identifier = Int16(identifier)
                    newPrompt.name = prompt.name
                    newPrompt.intro = prompt.intro
                    newPrompt.display = prompt.display
                    newPrompt.content = prompt.content
                    newPrompt.type = prompt.type
                    newPrompt.order = Int16(prompt.order)
                    newPrompt.createdAt = Date()
                    newPrompt.updatedAt = Date()
                }
            }
            
            try context.save()
            
            // Verify final state
            let verifyRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            verifyRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Prompt.order, ascending: true),
                NSSortDescriptor(keyPath: \Prompt.updatedAt, ascending: false)
            ]
            _ = try context.fetch(verifyRequest)
            
        } catch {
            // Handle error silently
        }
    }
} 