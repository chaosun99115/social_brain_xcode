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
        print("[PromptConfigurationManager] ===== Starting Default Prompts Verification =====")
        do {
            let context = try await CoreDataManager.shared.viewContext
            print("[PromptConfigurationManager] Successfully obtained CoreData context")

            // First verify if we need to ingest at all
            let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            let existingCount = try context.count(for: fetchRequest)
            print("[PromptConfigurationManager] Found \(existingCount) total prompts in database")
            
            // Detailed logging for each prompt identifier
            for identifier in [111, 121] {
                print("\n[PromptConfigurationManager] ===== Checking Prompt \(identifier) =====")
                let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "identifier == %d", identifier)
                
                // Log the exact predicate being used
                print("[PromptConfigurationManager] Using predicate: \(fetchRequest.predicate?.description ?? "nil")")
                
                let count = try context.count(for: fetchRequest)
                print("[PromptConfigurationManager] Found \(count) prompts with identifier \(identifier)")
                
                if count == 0 {
                    print("[PromptConfigurationManager] Prompt \(identifier) not found, attempting to ingest")
                    // Find the prompt in DefaultPrompts
                    if let prompt = DefaultPrompts.prompts.first(where: { $0.identifiers.contains(identifier) }) {
                        print("[PromptConfigurationManager] Found matching prompt in DefaultPrompts:")
                        print("- Name: \(prompt.name)")
                        print("- Type: \(prompt.type)")
                        print("- Identifiers: \(prompt.identifiers)")
                        
                        let newPrompt = Prompt(context: context)
                        newPrompt.identifier = Int16(identifier)
                        newPrompt.name = prompt.name
                        newPrompt.intro = prompt.intro
                        newPrompt.display = prompt.display
                        newPrompt.content = prompt.content
                        newPrompt.type = prompt.type
                        
                        print("[PromptConfigurationManager] Created new prompt object:")
                        print("- Identifier: \(newPrompt.identifier)")
                        print("- Name: \(newPrompt.name ?? "nil")")
                        print("- Display: \(newPrompt.display ?? "nil")")
                        print("- Type: \(newPrompt.type)")
                        
                        // Save immediately after creating each prompt
                        do {
                            try context.save()
                            print("[PromptConfigurationManager] Successfully saved prompt \(identifier) to CoreData")
                            
                            // Verify the save immediately
                            let verifyRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
                            verifyRequest.predicate = NSPredicate(format: "identifier == %d", identifier)
                            let verifyCount = try context.count(for: verifyRequest)
                            print("[PromptConfigurationManager] Verification after save: Found \(verifyCount) prompts with identifier \(identifier)")
                            
                            if verifyCount > 0 {
                                // Fetch and log the actual saved prompt
                                let savedPrompts = try context.fetch(verifyRequest)
                                if let savedPrompt = savedPrompts.first {
                                    print("[PromptConfigurationManager] Saved prompt details:")
                                    print("- Identifier: \(savedPrompt.identifier)")
                                    print("- Name: \(savedPrompt.name ?? "nil")")
                                    print("- Display: \(savedPrompt.display ?? "nil")")
                                    print("- Type: \(savedPrompt.type)")
                                }
                            }
                        } catch {
                            print("[PromptConfigurationManager] Error saving prompt \(identifier): \(error)")
                            print("[PromptConfigurationManager] Error details: \(error.localizedDescription)")
                            if let nsError = error as NSError? {
                                print("[PromptConfigurationManager] CoreData error code: \(nsError.code)")
                                print("[PromptConfigurationManager] CoreData error domain: \(nsError.domain)")
                                print("[PromptConfigurationManager] CoreData error userInfo: \(nsError.userInfo)")
                            }
                        }
                    } else {
                        print("[PromptConfigurationManager] WARNING: No matching prompt found in DefaultPrompts for identifier \(identifier)")
                        print("[PromptConfigurationManager] Available DefaultPrompts:")
                        for prompt in DefaultPrompts.prompts {
                            print("- Prompt: \(prompt.name), Identifiers: \(prompt.identifiers)")
                        }
                    }
                } else {
                    // Log details of existing prompt
                    let existingPrompts = try context.fetch(fetchRequest)
                    if let existingPrompt = existingPrompts.first {
                        print("[PromptConfigurationManager] Existing prompt details:")
                        print("- Identifier: \(existingPrompt.identifier)")
                        print("- Name: \(existingPrompt.name ?? "nil")")
                        print("- Display: \(existingPrompt.display ?? "nil")")
                        print("- Type: \(existingPrompt.type)")
                    }
                }
            }
            
            // Final verification of all prompts
            print("\n[PromptConfigurationManager] ===== Final Verification =====")
            let finalFetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            let finalResults = try context.fetch(finalFetchRequest)
            print("[PromptConfigurationManager] Final verification - All prompts in database:")
            for prompt in finalResults {
                print("- Prompt: id=\(prompt.identifier), name=\(prompt.name ?? "nil"), display=\(prompt.display ?? "nil"), type=\(prompt.type)")
            }
            
        } catch {
            print("[PromptConfigurationManager] Error verifying/ingesting default prompts: \(error)")
            print("[PromptConfigurationManager] Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("[PromptConfigurationManager] CoreData error code: \(nsError.code)")
                print("[PromptConfigurationManager] CoreData error domain: \(nsError.domain)")
                print("[PromptConfigurationManager] CoreData error userInfo: \(nsError.userInfo)")
            }
        }
        print("[PromptConfigurationManager] ===== End Default Prompts Verification =====\n")
    }
    
    /// Debug function to print all prompts in the database
    func printAllPrompts(context: NSManagedObjectContext) {
        print("\n[PromptConfigurationManager] ===== DEBUG: All Prompts in Database =====")
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            print("Total prompts found: \(results.count)")
            for prompt in results {
                print("Prompt: id=\(prompt.identifier), name=\(prompt.name ?? "nil"), display=\(prompt.display ?? "nil"), type=\(prompt.type)")
            }
        } catch {
            print("Error fetching prompts: \(error)")
        }
        print("===== End Debug Print =====\n")
    }
    
    /// Returns the appropriate prompt based on the current display mode and sample mode
    /// - Parameters:
    ///   - mode: The current display mode
    ///   - sampleMode: The current sample mode (if in sample mode)
    ///   - context: CoreData context
    /// - Returns: Array of prompts that match the criteria
    func getPromptsForMode(_ mode: PromptDisplayMode, sampleMode: String? = nil, context: NSManagedObjectContext) -> [PromptDisplayable] {
        print("[PromptConfigurationManager] ===== Starting Prompt Fetch =====")
        
        // Add debug print at the start of the function
        printAllPrompts(context: context)
        
        print("[PromptConfigurationManager] Context details:")
        print("- Context: \(context)")
        print("- Has changes: \(context.hasChanges)")
        print("- Parent context: \(context.parent?.description ?? "nil")")
        
        // Ensure we're using the main context
        let mainContext = context.concurrencyType == .mainQueueConcurrencyType ? context : context.parent ?? context
        print("[PromptConfigurationManager] Using context type: \(mainContext.concurrencyType == .mainQueueConcurrencyType ? "Main" : "Background")")
        
        // Perform a quick verification of the database state
        do {
            let verifyRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            let totalCount = try mainContext.count(for: verifyRequest)
            print("[PromptConfigurationManager] Current database state - Total prompts: \(totalCount)")
            
            // If in sample mode, verify the specific prompt we're looking for
            if mode == .sample, let sampleMode = sampleMode {
                let identifiers = SampleModePromptMapping.getPromptIdentifiers(for: sampleMode)
                for identifier in identifiers {
                    let specificRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
                    specificRequest.predicate = NSPredicate(format: "identifier == %d", identifier)
                    let count = try mainContext.count(for: specificRequest)
                    print("[PromptConfigurationManager] Found \(count) prompts with identifier \(identifier) in database")
                }
            }
        } catch {
            print("[PromptConfigurationManager] Error verifying database state: \(error)")
        }
        
        switch mode {
        case .regular:
            print("[PromptConfigurationManager] Regular mode - fetching prompts with identifier 1")
            return fetchPromptsWithIdentifier(1, context: mainContext)
            
        case .sample:
            guard let sampleMode = sampleMode else {
                print("[PromptConfigurationManager] Sample mode but no sampleMode provided")
                return []
            }
            
            // Get available prompt identifiers for this sample mode
            let availableIdentifiers = SampleModePromptMapping.getPromptIdentifiers(for: sampleMode)
            print("[PromptConfigurationManager] Available identifiers for sample mode '\(sampleMode)': \(availableIdentifiers)")
            
            guard !availableIdentifiers.isEmpty else {
                print("[PromptConfigurationManager] No available identifiers found for sample mode '\(sampleMode)'")
                return []
            }
            
            // Return all prompts for the available identifiers
            var prompts: [PromptDisplayable] = []
            for identifier in availableIdentifiers {
                print("[PromptConfigurationManager] Fetching prompts for identifier: \(identifier)")
                let fetchedPrompts = fetchPromptsWithIdentifier(identifier, context: mainContext)
                print("[PromptConfigurationManager] Found \(fetchedPrompts.count) prompts for identifier \(identifier)")
                prompts.append(contentsOf: fetchedPrompts)
            }
            print("[PromptConfigurationManager] Total prompts found: \(prompts.count)")
            return prompts
        }
    }
    
    /// Fetches all prompts from CoreData by identifier
    private func fetchPromptsWithIdentifier(_ identifier: Int, context: NSManagedObjectContext) -> [PromptDisplayable] {
        print("[PromptConfigurationManager] Fetching prompts with identifier: \(identifier)")
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
                    print("[PromptConfigurationManager] WARNING: Fetching on main context from background thread")
                }
            }
            
            let results = try context.fetch(fetchRequest)
            print("[PromptConfigurationManager] CoreData fetch results for identifier \(identifier):")
            for result in results {
                print("- Prompt: id=\(result.identifier), name=\(result.name ?? "nil"), display=\(result.display ?? "nil"), order=\(result.order)")
            }
            
            // Verify the results are still valid
            if !results.isEmpty {
                for result in results {
                    if result.isFault {
                        print("[PromptConfigurationManager] WARNING: Found faulted prompt object")
                        context.refresh(result, mergeChanges: true)
                    }
                }
            }
            
            return results.map { PromptAdapter(prompt: $0) }
        } catch {
            print("[PromptConfigurationManager] Error fetching prompts: \(error)")
            print("[PromptConfigurationManager] Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("[PromptConfigurationManager] CoreData error code: \(nsError.code)")
                print("[PromptConfigurationManager] CoreData error domain: \(nsError.domain)")
            }
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
        print("[PromptConfigurationManager] Force re-ingesting default prompts")
        do {
            let context = try await CoreDataManager.shared.viewContext
            
            // Clear existing prompts
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Prompt.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
            try context.save()
            print("[PromptConfigurationManager] Cleared existing prompts")
            
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
                    newPrompt.order = Int16(prompt.order)  // Set the order from DefaultPrompts
                    newPrompt.createdAt = Date()
                    newPrompt.updatedAt = Date()
                    print("[PromptConfigurationManager] Created new prompt with identifier \(identifier), order \(prompt.order)")
                }
            }
            
            try context.save()
            print("[PromptConfigurationManager] Saved all prompts to CoreData")
            
            // Verify final state
            let verifyRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            verifyRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Prompt.order, ascending: true),
                NSSortDescriptor(keyPath: \Prompt.updatedAt, ascending: false)
            ]
            let results = try context.fetch(verifyRequest)
            print("[PromptConfigurationManager] Verification after re-ingestion - Found \(results.count) total prompts")
            for prompt in results {
                print("""
                    Prompt details:
                    - Name: \(prompt.name ?? "nil")
                    - Display: \(prompt.display ?? "nil")
                    - Type: \(prompt.type)
                    - Order: \(prompt.order)
                    - Identifier: \(prompt.identifier)
                    - Updated: \(prompt.updatedAt?.description ?? "nil")
                    """)
            }
            
        } catch {
            print("[PromptConfigurationManager] Error during force re-ingestion: \(error)")
        }
    }
} 