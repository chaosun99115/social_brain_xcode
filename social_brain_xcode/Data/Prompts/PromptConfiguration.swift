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
            "changedJob": [9, 7,  999],  // Changed job specific prompts
            "indieDev": [9, 8, 999],    // Indie dev specific prompts
            "regular": [1, 2, 9, 999]         // Keep original identifiers for regular mode
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
    
    // Add flag to track if cleanup has been performed
    private var hasPerformedCleanup = false
    
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
            
            // Get all identifiers from DefaultPrompts, not just from source type mapping
            let allDefaultIdentifiers = Set(DefaultPrompts.prompts.flatMap { $0.identifiers })
            
            // Detailed verification for each prompt identifier
            for prompt in DefaultPrompts.prompts {
                for identifier in prompt.identifiers {
                    let identifierFetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
                    identifierFetchRequest.predicate = NSPredicate(format: "identifier == %d", identifier)
                    let existingPrompts = try context.fetch(identifierFetchRequest)
                    
                    if existingPrompts.isEmpty {
                        // Create the missing prompt
                        let newPrompt = Prompt(context: context)
                        newPrompt.id = UUID()
                        newPrompt.identifier = Int16(identifier)
                        newPrompt.name = prompt.name
                        newPrompt.intro = prompt.intro
                        newPrompt.display = prompt.display
                        newPrompt.content = prompt.content
                        newPrompt.type = prompt.type
                        newPrompt.order = Int16(prompt.order)
                        newPrompt.createdAt = Date()
                        newPrompt.updatedAt = Date()
                        newPrompt.recordStatus = 0
                        newPrompt.isArchived = false // Set isArchived to false for default prompts
                    }
                }
            }
            
            // Final verification of all prompts
            let finalFetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            let finalResults = try context.fetch(finalFetchRequest)
            
        } catch {
            print("🔧 PromptConfigurationManager: Error in verifyAndIngestDefaultPrompts: \(error)")
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
    
    /// Debug function to check for duplicate prompts in the database
    func checkForDuplicatePrompts(context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Prompt.identifier, ascending: true)]
        
        do {
            let allPrompts = try context.fetch(fetchRequest)
            
            // Group by identifier
            let groupedPrompts = Dictionary(grouping: allPrompts) { $0.identifier }
            
            // Check for duplicates, but exclude user prompts from the duplicate check
            for (identifier, prompts) in groupedPrompts {
                if identifier == 999 {
                    continue
                }
                
                if prompts.count > 1 {
                    return true
                }
            }
            
            return false
        } catch {
            print("🔧 PromptConfigurationManager: Error checking for duplicates: \(error)")
            return false
        }
    }
    
    /// Returns the appropriate prompts based on source type and sample mode
    /// - Parameters:
    ///   - sourceType: The source type (general, contact, note)
    ///   - sampleMode: The current sample mode (if in sample mode)
    ///   - context: CoreData context
    ///   - contact: Optional contact for dynamic text replacement
    /// - Returns: Array of prompts that match the criteria
    func getPromptsForSourceType(_ sourceType: String, sampleMode: String? = nil, context: NSManagedObjectContext, contact: Contact? = nil) -> [PromptDisplayable] {
        // Check for duplicates first
        let hasDuplicates = checkForDuplicatePrompts(context: context)
        
        // If duplicates are found and we haven't cleaned up yet, clean them up synchronously
        if hasDuplicates && !hasPerformedCleanup {
            hasPerformedCleanup = true
            
            // Run cleanup synchronously to prevent returning duplicates
            cleanupDuplicatePromptsSync(context: context)
            
            // Refresh the context to ensure we get the cleaned data
            context.refreshAllObjects()
        }
        
        // Ensure we're using the main context
        let mainContext = context.concurrencyType == .mainQueueConcurrencyType ? context : context.parent ?? context
        
        // Get available prompt identifiers for this source type and sample mode
        let availableIdentifiers = SourceTypePromptMapping.getPromptIdentifiers(for: sourceType, sampleMode: sampleMode)
        
        guard !availableIdentifiers.isEmpty else {
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
        let sortedPrompts = prompts.sorted { (p1, p2) in
            if let adapter1 = p1 as? PromptAdapter,
               let adapter2 = p2 as? PromptAdapter {
                if adapter1.order != adapter2.order {
                    return adapter1.order < adapter2.order
                }
                return (adapter1.createdAt ?? Date()) > (adapter2.createdAt ?? Date())
            }
            return false
        }
        
        return sortedPrompts
    }
    
    /// Fetches all prompts from CoreData by identifier
    private func fetchPromptsWithIdentifier(_ identifier: Int, context: NSManagedObjectContext) -> [PromptDisplayable] {
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %d AND (isArchived == NO OR isArchived == nil)", identifier)
        
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
            print("🔧 PromptConfigurationManager: Error fetching prompts with identifier \(identifier): \(error)")
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
                return false
            }
        }
        
        // Check if all prompt mappings correspond to configured modes
        if let generalMappings = SourceTypePromptMapping.sourceTypeToPromptIdentifiers["general"] {
            for mode in generalMappings.keys {
                if !configuredModes.contains(mode) {
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
            
            // First, preserve user-created prompts (identifier = 999)
            let userPromptsFetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            userPromptsFetchRequest.predicate = NSPredicate(format: "identifier == 999")
            let userPrompts = try context.fetch(userPromptsFetchRequest)
            
            // Clear existing prompts (this will also delete user prompts, but we'll restore them)
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Prompt.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
            try context.save()
            
            // Re-ingest all default prompts
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
                    newPrompt.recordStatus = 0
                    newPrompt.isArchived = false // Set isArchived to false for default prompts
                }
            }
            
            // Restore user-created prompts
            for userPrompt in userPrompts {
                let restoredPrompt = Prompt(context: context)
                restoredPrompt.id = userPrompt.id
                restoredPrompt.identifier = userPrompt.identifier
                restoredPrompt.name = userPrompt.name
                restoredPrompt.intro = userPrompt.intro
                restoredPrompt.display = userPrompt.display
                restoredPrompt.content = userPrompt.content
                restoredPrompt.type = userPrompt.type
                restoredPrompt.order = userPrompt.order
                restoredPrompt.createdAt = userPrompt.createdAt
                restoredPrompt.updatedAt = userPrompt.updatedAt
                restoredPrompt.recordStatus = userPrompt.recordStatus
                restoredPrompt.isArchived = userPrompt.isArchived // Preserve isArchived status
            }
            
            try context.save()
            
            // Verify final state
            let verifyRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            verifyRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Prompt.order, ascending: true),
                NSSortDescriptor(keyPath: \Prompt.updatedAt, ascending: false)
            ]
            let finalResults = try context.fetch(verifyRequest)
            
        } catch {
            print("🔧 PromptConfigurationManager: Error in forceReingestDefaultPrompts: \(error)")
        }
    }
    
    /// Clean up duplicate prompts in the database synchronously, keeping only one prompt per identifier
    func cleanupDuplicatePromptsSync(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Prompt.identifier, ascending: true),
            NSSortDescriptor(keyPath: \Prompt.createdAt, ascending: true) // Keep the oldest one
        ]
        
        do {
            let allPrompts = try context.fetch(fetchRequest)
            
            // Group by identifier
            let groupedPrompts = Dictionary(grouping: allPrompts) { $0.identifier }
            
            var deletedCount = 0
            
            for (identifier, prompts) in groupedPrompts {
                // Skip deduplication for user-created prompts (identifier = 999)
                if identifier == 999 {
                    continue
                }
                
                if prompts.count > 1 {
                    // Keep the first (oldest) prompt, delete the rest
                    let promptsToDelete = Array(prompts.dropFirst())
                    
                    for prompt in promptsToDelete {
                        context.delete(prompt)
                        deletedCount += 1
                    }
                }
            }
            
            if deletedCount > 0 {
                try context.save()
                
                // Verify cleanup
                let verifyRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
                let finalCount = try context.count(for: verifyRequest)
            }
            
        } catch {
            print("🔧 PromptConfigurationManager: Error during cleanup: \(error)")
        }
    }
    
    /// Clean up duplicate prompts in the database, keeping only one prompt per identifier
    func cleanupDuplicatePrompts(context: NSManagedObjectContext) async {
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Prompt.identifier, ascending: true),
            NSSortDescriptor(keyPath: \Prompt.createdAt, ascending: true) // Keep the oldest one
        ]
        
        do {
            let allPrompts = try context.fetch(fetchRequest)
            
            // Group by identifier
            let groupedPrompts = Dictionary(grouping: allPrompts) { $0.identifier }
            
            var deletedCount = 0
            
            for (identifier, prompts) in groupedPrompts {
                // Skip deduplication for user-created prompts (identifier = 999)
                if identifier == 999 {
                    continue
                }
                
                if prompts.count > 1 {
                    // Keep the first (oldest) prompt, delete the rest
                    let promptsToDelete = Array(prompts.dropFirst())
                    
                    for prompt in promptsToDelete {
                        context.delete(prompt)
                        deletedCount += 1
                    }
                }
            }
            
            if deletedCount > 0 {
                try context.save()
                
                // Verify cleanup
                let verifyRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
                let finalCount = try context.count(for: verifyRequest)
            }
            
        } catch {
            print("🔧 PromptConfigurationManager: Error during cleanup: \(error)")
        }
    }
} 
