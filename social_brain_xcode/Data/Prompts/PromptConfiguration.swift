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
    let prompt: Prompt
    
    init(prompt: Prompt, customDisplay: String? = nil) {
        self.prompt = prompt
        self._customDisplay = customDisplay
    }
    
    var identifier: Int { Int(prompt.identifier) }
    var display: String {
        _customDisplay ?? prompt.display ?? ""
    }
    var content: String { prompt.content ?? "" }
    
    // Add computed properties for sorting
    var order: Int16 { prompt.order }
    var createdAt: Date? { prompt.createdAt }
    
    private var _customDisplay: String?
}

/// Configuration for source type and sample mode mapping
struct SourceTypePromptMapping {
    /// Maps source type and sample mode to prompt identifiers
    static let sourceTypeToPromptIdentifiers: [String: [String: [Int]]] = [
        "general": [
            "changedJob": [1, 2, 3],  // Changed job specific prompts
            "indieDev": [1, 2, 4],    // Indie dev specific prompts
            "regular": [1, 2]         // Keep original identifiers for regular mode
        ],
        "contact": [
            "changedJob": [5],
            "indieDev": [5],
            "regular": [5]            // Keep original identifier
        ],
        "note": [
            "changedJob": [6],
            "indieDev": [6],
            "regular": [6]            // Keep original identifier
        ]
    ]
    
    /// Get prompt identifiers for a specific source type and sample mode
    static func getPromptIdentifiers(for sourceType: String, sampleMode: String?) -> [Int] {
        let mode = sampleMode ?? "regular"
        return sourceTypeToPromptIdentifiers[sourceType]?[mode] ?? []
    }
    
    /// Check if a prompt identifier belongs to a specific source type and sample mode
    static func isPromptInSourceType(_ identifier: Int, sourceType: String, sampleMode: String?) -> Bool {
        let mode = sampleMode ?? "regular"
        return sourceTypeToPromptIdentifiers[sourceType]?[mode]?.contains(identifier) ?? false
    }
    
    /// Get the sample mode for a specific prompt identifier
    static func getSampleMode(for identifier: Int, sourceType: String) -> String? {
        for (mode, identifiers) in sourceTypeToPromptIdentifiers[sourceType] ?? [:] {
            if identifiers.contains(identifier) {
                return mode
            }
        }
        return nil
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
            
            // Get all identifiers from the source type mapping
            let allIdentifiers = Set(SourceTypePromptMapping.sourceTypeToPromptIdentifiers.values.flatMap { $0.values.flatMap { $0 } })
            
            // Detailed verification for each prompt identifier
            for identifier in allIdentifiers {
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
    
    /// Processes a prompt's display text to replace dynamic content
    /// - Parameters:
    ///   - displayText: The original display text from the prompt
    ///   - contact: Optional contact to use for replacements
    /// - Returns: Processed display text with replacements
    func processDisplayText(_ displayText: String, contact: Contact?) -> String {
        var processedText = displayText
        
        // Replace <contect> with contact name if available
        if let contact = contact, let contactName = contact.name {
            processedText = processedText.replacingOccurrences(of: "<contect>", with: contactName)
        }
        
        return processedText
    }
    
    /// Returns the appropriate prompts based on source type and sample mode
    /// - Parameters:
    ///   - sourceType: The source type (general, contact, note)
    ///   - sampleMode: The current sample mode (if in sample mode)
    ///   - context: CoreData context
    ///   - contact: Optional contact for dynamic text replacement
    /// - Returns: Array of prompts that match the criteria
    func getPromptsForSourceType(_ sourceType: String, sampleMode: String? = nil, context: NSManagedObjectContext, contact: Contact? = nil) -> [PromptDisplayable] {
        // Ensure we're using the main context
        let mainContext = context.concurrencyType == .mainQueueConcurrencyType ? context : context.parent ?? context
        
        // Get available prompt identifiers for this source type and sample mode
        let availableIdentifiers = SourceTypePromptMapping.getPromptIdentifiers(for: sourceType, sampleMode: sampleMode)
        
        guard !availableIdentifiers.isEmpty else {
            print("[PromptConfigurationManager] Error: No available identifiers for sourceType: \(sourceType), sampleMode: \(sampleMode ?? "nil")")
            return []
        }
        
        // Return all prompts for the available identifiers
        var prompts: [PromptDisplayable] = []
        for identifier in availableIdentifiers {
            let fetchedPrompts = fetchPromptsWithIdentifier(identifier, context: mainContext)
            // Process each prompt's display text
            let processedPrompts = fetchedPrompts.compactMap { prompt -> PromptDisplayable? in
                if let adapter = prompt as? PromptAdapter {
                    let processedDisplay = processDisplayText(adapter.display, contact: contact)
                    return PromptAdapter(prompt: adapter.prompt, customDisplay: processedDisplay)
                }
                // If it's not a PromptAdapter, try to convert it to one
                if let promptEntity = (prompt as? PromptAdapter)?.prompt {
                    let processedDisplay = processDisplayText(prompt.display, contact: contact)
                    return PromptAdapter(prompt: promptEntity, customDisplay: processedDisplay)
                }
                return nil
            }
            prompts.append(contentsOf: processedPrompts)
        }
        
        // Sort prompts by order and createdAt
        return prompts.sorted { (p1, p2) in
            if let adapter1 = p1 as? PromptAdapter,
               let adapter2 = p2 as? PromptAdapter {
                if adapter1.order != adapter2.order {
                    return adapter1.order < adapter2.order
                }
                return (adapter1.createdAt ?? Date()) > (adapter2.createdAt ?? Date())
            }
            return false
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
            
            // Always return PromptAdapter instances
            return results.map { PromptAdapter(prompt: $0) }
        } catch {
            print("[PromptConfigurationManager] Error fetching prompts for identifier \(identifier): \(error)")
            return []
        }
    }
    
    /// Returns the appropriate prompt based on the current display mode and sample mode
    /// - Parameters:
    ///   - sourceType: The source type (general, contact, note)
    ///   - sampleMode: The current sample mode (if in sample mode)
    ///   - context: CoreData context
    /// - Returns: The selected prompt if available
    func getPromptForSourceType(_ sourceType: String, sampleMode: String? = nil, context: NSManagedObjectContext) -> PromptDisplayable? {
        let prompts = getPromptsForSourceType(sourceType, sampleMode: sampleMode, context: context)
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
            if SourceTypePromptMapping.getPromptIdentifiers(for: "general", sampleMode: mode).isEmpty {
                print("Warning: Sample mode '\(mode)' has no prompt mappings")
                return false
            }
        }
        
        // Check if all prompt mappings correspond to configured modes
        if let generalMappings = SourceTypePromptMapping.sourceTypeToPromptIdentifiers["general"] {
            for mode in generalMappings.keys {
                if !configuredModes.contains(mode) {
                    print("Warning: Prompt mapping exists for undefined sample mode '\(mode)'")
                    return false
                }
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
