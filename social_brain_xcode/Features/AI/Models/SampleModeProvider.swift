import Foundation
import CoreData

// MARK: - Prompt Context
struct PromptContext {
    let mode: SampleMode
    let question: String
    let contact: Contact?
    
    var isContactSpecific: Bool {
        contact != nil
    }
}

// MARK: - Sample Mode Enum
enum SampleMode: String {
    case changedJob
    case indieDev
    case contact  // Add new case for contact-specific mode
    case none
}

// MARK: - Sample Mode Provider Protocol
protocol SampleModeProvider {
    var baseSystemPrompt: String { get }
    var suggestedQuestions: [SocialBrainMessage] { get }
    
    // Updated to be async
    func generateSystemPrompt(for context: PromptContext) async throws -> String
    
    // Add new method for context-aware questions
    func getSuggestedQuestions(for context: PromptContext) -> [SocialBrainMessage]
}

// MARK: - Sample Mode Provider Protocol Extension
extension SampleModeProvider {
    /// Fetches and formats relevant notes for the given context
    func fetchRelevantNotes(for context: PromptContext) async throws -> String {
        let viewContext = CoreDataManager.shared.viewContext
        
        // First, let's check if there are any notes at all
        let allNotesFetchRequest = NSFetchRequest<Note>(entityName: "Note")
        let allNotes = try viewContext.fetch(allNotesFetchRequest)
        
        let notesFetchRequest = NSFetchRequest<Note>(entityName: "Note")
        
        // Configure fetch request based on context
        if let contact = context.contact {
            // Use a more explicit predicate that follows the relationship path
            notesFetchRequest.predicate = NSPredicate(format: "SUBQUERY(contacts, $r, $r.contacts == %@).@count > 0", contact)
        } else {
            // In sample mode, we want to include both sample notes (type 0) and regular notes (type 1)
            notesFetchRequest.predicate = NSPredicate(format: "type == %d OR type == %d", NoteType.sample.rawValue, NoteType.regular.rawValue)
        }
        
        // Sort by date, most recent first
        notesFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
        notesFetchRequest.fetchLimit = 10
        
        let notes = try viewContext.fetch(notesFetchRequest)
        
        // Format notes for the prompt
        let formattedNotes = notes.compactMap { note -> String? in
            guard let content = note.content,
                  let date = note.createdAt else { return nil }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let dateStr = dateFormatter.string(from: date)
            
            // Format each note with date and content
            return "[\(dateStr)] \(content)"
        }.joined(separator: "\n")
        
        let result = formattedNotes.isEmpty ? "" : "\n\n相关笔记如下:\n\(formattedNotes)"
        return result
    }
    
    /// Generates a system prompt with context and relevant notes
    func generateSystemPromptWithNotes(for context: PromptContext) async throws -> String {
        // First get the base prompt
        var prompt = try await generateSystemPrompt(for: context)
        
        // Fetch and append relevant notes
        let notesContext = try await fetchRelevantNotes(for: context)
        if !notesContext.isEmpty {
            // Append notes to the prompt instead of replacing it
            prompt += notesContext
        }
        
        return prompt
    }
}

// MARK: - New Job 
struct ChangedJobProvider: SampleModeProvider {
    var baseSystemPrompt: String {
        ""  // Empty string since basePrompt is not available
    }

    var suggestedQuestions: [SocialBrainMessage] {
        // This will be overridden by forContext
        [
            SocialBrainMessage(content: "回顾一下我最近聊过的社交话题", isFromUser: false, timestamp: Date(), promptIdentifier: 1),
            SocialBrainMessage(content: "最近有哪些适合联络的人？", isFromUser: false, timestamp: Date(), promptIdentifier: 2),
            SocialBrainMessage(content: "明天要跟张总一对一面聊，帮我准备一下", isFromUser: false, timestamp: Date(), promptIdentifier: 3)
        ]
    }
    
    // Override to only show social memo question for contacts
    func getSuggestedQuestions(for context: PromptContext) -> [SocialBrainMessage] {
        if let contact = context.contact, let name = contact.name {
            return [
                SocialBrainMessage(content: "查看 \(name) 的社交备忘录", isFromUser: false, timestamp: Date(), promptIdentifier: 1)
            ]
        }
        return suggestedQuestions
    }
    
    func generateSystemPrompt(for context: PromptContext) async throws -> String {
        var prompt = ""
        
        // Add question-specific guidance
        if context.question.contains("回顾") {
            prompt += "\n\n" + SampleModePrompts.UnifiedPrompt.review
        } else if context.question.contains("联络") {
            prompt += "\n\n" + SampleModePrompts.UnifiedPrompt.followUp
        } 
        else if context.question.contains("一对一面聊") {
            prompt += SampleModePrompts.ChangedJob.oneOnOneMeetingGuidance
        }
        
        return prompt
    }
}

// MARK: - Indie Dev 
struct IndieDevProvider: SampleModeProvider {
    var baseSystemPrompt: String {
        ""  // Empty string since basePrompt is not available
    }

    var suggestedQuestions: [SocialBrainMessage] {
        // This will be overridden by forContext
        [
            SocialBrainMessage(content: "回顾一下我最近聊过的社交话题", isFromUser: false, timestamp: Date(), promptIdentifier: 1),
            SocialBrainMessage(content: "最近有哪些适合联络的人？", isFromUser: false, timestamp: Date(), promptIdentifier: 2),
            SocialBrainMessage(content: "@小蔡 邀请我下周去参加陶艺展，我想给陶艺展的艺术家介绍我的 社交大脑 ，怎么介绍比较好", isFromUser: false, timestamp: Date(), promptIdentifier: 4)
        ]
    }
    
    // Override to only show social memo question for contacts
    func getSuggestedQuestions(for context: PromptContext) -> [SocialBrainMessage] {
        if let contact = context.contact, let name = contact.name {
            return [
                SocialBrainMessage(content: "查看 \(name) 的社交备忘录", isFromUser: false, timestamp: Date(), promptIdentifier: 1)
            ]
        }
        return suggestedQuestions
    }
    
    func generateSystemPrompt(for context: PromptContext) async throws -> String {
        var prompt = ""
        
        // Add question-specific guidance based on patterns
        let question = context.question.lowercased()
        if question.contains("回顾") {
            prompt += "\n\n" + SampleModePrompts.UnifiedPrompt.review
        } else if question.contains("联络") {
            prompt += "\n\n" + SampleModePrompts.UnifiedPrompt.followUp
        } else if question.contains("陶艺展") || question.contains("展览") {
            prompt += "\n\n" + SampleModePrompts.IndieDev.exhibitionGuidance
        }
        
        return prompt
    }
}

// MARK: - Contact Provider
struct ContactProvider: SampleModeProvider {
    var baseSystemPrompt: String {
        """
        """
    }

    var suggestedQuestions: [SocialBrainMessage] {
        [
            SocialBrainMessage(content: "回顾一下我们最近的互动", isFromUser: false, timestamp: Date(), promptIdentifier: 1),
            SocialBrainMessage(content: "有什么值得关注的话题？", isFromUser: false, timestamp: Date(), promptIdentifier: 2),
            SocialBrainMessage(content: "如何更好地维护这段关系？", isFromUser: false, timestamp: Date(), promptIdentifier: 3)
        ]
    }
    
    func getSuggestedQuestions(for context: PromptContext) -> [SocialBrainMessage] {
        if let contact = context.contact, let name = contact.name {
            return [
                SocialBrainMessage(content: "查看 \(name) 的社交备忘录", isFromUser: false, timestamp: Date(), promptIdentifier: 1)
            ]
        }
        
        return suggestedQuestions
    }
    
    func generateSystemPrompt(for context: PromptContext) async throws -> String {
        var prompt = baseSystemPrompt
        
        // Add contact-specific context if available
        if let contact = context.contact, let name = contact.name {
            
            // Add question-specific guidance
            if context.question.contains("备忘录") || context.question.contains("社交记录") {
                prompt += "\n\n" + SampleModePrompts.UnifiedPrompt.contact
            }
        }
        
        return prompt
    }
}

// MARK: - Sample Mode Provider Factory
struct SampleModeProviderFactory {
    static func getProvider(for mode: String) -> SampleModeProvider? {
        print("[SampleModeProviderFactory] Getting provider for mode: \(mode)")
        let provider: SampleModeProvider?
        
        switch mode {
        case SampleMode.changedJob.rawValue:
            provider = ChangedJobProvider()
        case SampleMode.indieDev.rawValue:
            provider = IndieDevProvider()
        case SampleMode.contact.rawValue:
            provider = ContactProvider()
        default:
            provider = nil
        }
        
        print("[SampleModeProviderFactory] Provider type: \(type(of: provider ?? ChangedJobProvider()))")
        return provider
    }
    
    static func generatePrompt(for mode: String, question: String, contact: Contact? = nil) async throws -> String? {
        guard let provider = getProvider(for: mode) else { return nil }
        let context = PromptContext(
            mode: SampleMode(rawValue: mode) ?? .none,
            question: question,
            contact: contact
        )
        return try await provider.generateSystemPrompt(for: context)
    }
}

// Add default implementation
extension SampleModeProvider {
    func getSuggestedQuestions(for context: PromptContext) -> [SocialBrainMessage] {
        if let contact = context.contact, let name = contact.name {
            return [
                SocialBrainMessage(content: "查看 \(name) 的社交备忘录", isFromUser: false, timestamp: Date(), promptIdentifier: 1)
            ]
        }
        return suggestedQuestions
    }
} 