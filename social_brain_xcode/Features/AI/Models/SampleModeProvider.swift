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
    case changedSchool
    case careerPivot
    case indieDev
    case none
}

// MARK: - Sample Mode Provider Protocol
protocol SampleModeProvider {
    var baseSystemPrompt: String { get }
    var suggestedQuestions: [SocialBrainMessage] { get }
    
    // Updated to be async
    func generateSystemPrompt(for context: PromptContext) async throws -> String
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
            notesFetchRequest.predicate = NSPredicate(format: "contacts.contacts == %@", contact)
        } else {
            // In sample mode, we want to include both sample notes (type 0) and social notes (type 2)
            notesFetchRequest.predicate = NSPredicate(format: "type == %d OR type == %d", 0, NoteType.social.rawValue)
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

// MARK: - New Job Provider
struct ChangedJobProvider: SampleModeProvider {
    var baseSystemPrompt: String {
        return SampleModePrompts.ChangedJob.basePrompt
    }
    
    func generateSystemPrompt(for context: PromptContext) async throws -> String {
        var prompt = baseSystemPrompt
        
        // Add context-specific guidance
        if context.isContactSpecific {
            prompt += "\n\n" + String(format: SampleModePrompts.ChangedJob.contactSpecificGuidance, context.contact?.name ?? "the contact")
        }
        
        // Add question-specific guidance
        if context.question.contains("明天要跟张总一对一对聊") {
            prompt += SampleModePrompts.ChangedJob.oneOnOneMeetingGuidance
        } else if context.question.contains("最近的社交") {
            prompt += SampleModePrompts.ChangedJob.recentSocialGuidance
        }
        
        return prompt
    }
    
    var suggestedQuestions: [SocialBrainMessage] {
        [
            SocialBrainMessage(content: "回顾我最近的社交", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "明天要跟张总一对一对聊，帮我准备一下", isFromUser: false, timestamp: Date())
        ]
    }
}

// MARK: - New School
struct ChangedSchoolProvider: SampleModeProvider {
    var baseSystemPrompt: String {
        SampleModePrompts.ChangedSchool.basePrompt
    }
    
    func generateSystemPrompt(for context: PromptContext) async throws -> String {
        var prompt = baseSystemPrompt
        
        if context.isContactSpecific {
            prompt += "\n\n" + String(format: SampleModePrompts.ChangedSchool.contactSpecificGuidance, context.contact?.name ?? "the teacher")
        }
        
        if context.question.contains("一对一聊聊") {
            prompt += "\n\n" + SampleModePrompts.ChangedSchool.oneOnOneMeetingGuidance
        }
        
        // Remove duplicate notes appending
        return prompt
    }
    
    var suggestedQuestions: [SocialBrainMessage] {
        [
            SocialBrainMessage(content: "回顾我最近的社交", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "明天要跟张总一对一聊聊，帮我准备下社交素材？", isFromUser: false, timestamp: Date())
        ]
    }
}

// MARK: - Career Pivot Provider
struct CareerPivotProvider: SampleModeProvider {
    var baseSystemPrompt: String {
        SampleModePrompts.CareerPivot.basePrompt
    }
    
    func generateSystemPrompt(for context: PromptContext) async throws -> String {
        var prompt = baseSystemPrompt
        
        if context.isContactSpecific {
            prompt += "\n\n" + String(format: SampleModePrompts.CareerPivot.review, context.contact?.name ?? "the mentor")
        }
        
        if context.question.contains("回顾") {
            prompt += "\n\n" + SampleModePrompts.CareerPivot.review
        }

        if context.question.contains("社交备忘录") {
            prompt += "\n\n" + SampleModePrompts.CareerPivot.contact
        }
        
        // Remove the duplicate notes appending since it's handled by generateSystemPromptWithNotes
        return prompt
    }
    
    var suggestedQuestions: [SocialBrainMessage] {
        [
            SocialBrainMessage(content: "回顾我最近的社交？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "明天我要跟 林伟 聊聊，帮我回顾下关于他的社交备忘录", isFromUser: false, timestamp: Date())
        ]
    }
}

// MARK: - Indie Dev Provider
struct IndieDevProvider: SampleModeProvider {
    var baseSystemPrompt: String {
        SampleModePrompts.IndieDev.basePrompt
    }
    
    func generateSystemPrompt(for context: PromptContext) async throws -> String {
        var prompt = baseSystemPrompt
        
        // Add contact-specific guidance if applicable
        if context.isContactSpecific {
            prompt += "\n\n" + String(format: SampleModePrompts.IndieDev.contactSpecificGuidance, context.contact?.name ?? "the developer")
        }
        
        // Add question-specific guidance based on patterns
        let question = context.question.lowercased()
        if question.contains("回顾") || question.contains("最近") {
            prompt += "\n\n" + SampleModePrompts.IndieDev.followUpGuidance
        } else if question.contains("陶艺展") || question.contains("展览") {
            prompt += "\n\n" + SampleModePrompts.IndieDev.exhibitionGuidance
        } else if question.contains("项目") || question.contains("介绍") || question.contains("展示") {
            prompt += "\n\n" + SampleModePrompts.IndieDev.projectShowcaseGuidance
        }
        
        // Remove duplicate notes appending
        return prompt
    }
    
    var suggestedQuestions: [SocialBrainMessage] {
        [
            SocialBrainMessage(content: "回顾我最近的社交互动？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "@小蔡 邀请我下周去参加陶艺展，我想给陶艺展的艺术家介绍我的 社交大脑 ，怎么介绍比较好", isFromUser: false, timestamp: Date()),
        ]
    }
}

// MARK: - Sample Mode Provider Factory
struct SampleModeProviderFactory {
    static func getProvider(for mode: String) -> SampleModeProvider? {
        switch mode {
        case SampleMode.changedJob.rawValue:
            return ChangedJobProvider()
        case SampleMode.changedSchool.rawValue:
            return ChangedSchoolProvider()
        case SampleMode.careerPivot.rawValue:
            return CareerPivotProvider()
        case SampleMode.indieDev.rawValue:
            return IndieDevProvider()
        default:
            return nil
        }
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