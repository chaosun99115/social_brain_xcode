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
    var type: Int16 { get }
}

/// Adapter to make Note conform to PromptDisplayable
struct NotePromptAdapter: PromptDisplayable {
    private let note: Note
    
    init(note: Note) {
        self.note = note
    }
    
    var identifier: Int { Int(note.noteId?.hashValue ?? 0) }
    var display: String { note.content ?? "" }
    var content: String { note.content ?? "" }
    var type: Int16 { note.type }
}

/// Dedicated mapping from sample mode to prompt identifiers
/// Configure the matching between sample modes and prompt identifiers here.
let sampleModePromptIdentifiers: [String: [Int]] = [
    "changedJob": [1, 2],
    "indieDev": [2],
    "contact": [1]
    // Add more mappings as needed
]

/// Manages prompt configuration and display logic
class PromptConfigurationManager {
    static let shared = PromptConfigurationManager()
    
    private init() {}
    
    /// Maps sample mode identifiers to their configurations
    private let sampleModeConfigs: [Int: SampleModePromptConfig] = [
        2: SampleModePromptConfig(
            identifier: 2,
            displayName: "社交场合话题指南",
            description: "在不同社交场合中，合适的话题选择可以帮助建立良好的互动氛围"
        ),
        // Add more sample mode configurations as needed
    ]
    
    /// Returns the appropriate prompt based on the current display mode
    /// - Parameters:
    ///   - mode: The current display mode
    ///   - context: CoreData context
    /// - Returns: The selected prompt if available
    func getPromptForMode(_ mode: PromptDisplayMode, context: NSManagedObjectContext) -> PromptDisplayable? {
        switch mode {
        case .regular:
            return fetchPromptWithIdentifier(1, context: context)
        case .sample:
            // Get a random sample mode prompt that's not identifier 1
            let sampleIdentifiers = Array(sampleModeConfigs.keys)
            guard let randomIdentifier = sampleIdentifiers.randomElement() else { return nil }
            return fetchPromptWithIdentifier(randomIdentifier, context: context)
        }
    }
    
    /// Fetches a prompt from CoreData by identifier
    private func fetchPromptWithIdentifier(_ identifier: Int, context: NSManagedObjectContext) -> PromptDisplayable? {
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %d", identifier)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            guard let note = results.first else { return nil }
            return NotePromptAdapter(note: note)
        } catch {
            print("Error fetching prompt: \(error)")
            return nil
        }
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
} 