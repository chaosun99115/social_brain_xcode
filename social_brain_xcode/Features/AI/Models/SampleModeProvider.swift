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
    var contactSpecificQuestions: (Contact) -> [SocialBrainMessage] { get }
    
    // Updated to be async
    func generateSystemPrompt(for context: PromptContext) async throws -> String
}

// MARK: - Sample Mode Provider Protocol Extension
extension SampleModeProvider {
    /// Fetches and formats relevant notes for the given context
    func fetchRelevantNotes(for context: PromptContext) async throws -> String {
        print("[SampleModeProvider] Starting fetchRelevantNotes for context: mode=\(context.mode.rawValue), hasContact=\(context.contact != nil)")
        
        let viewContext = CoreDataManager.shared.viewContext
        
        // First, let's check if there are any notes at all
        let allNotesFetchRequest = NSFetchRequest<Note>(entityName: "Note")
        let allNotes = try viewContext.fetch(allNotesFetchRequest)
        print("[SampleModeProvider] Total notes in database: \(allNotes.count)")
        
        // Log all note types to see what we have
        let noteTypes = allNotes.map { $0.type }
        print("[SampleModeProvider] Note types in database: \(noteTypes)")
        
        let notesFetchRequest = NSFetchRequest<Note>(entityName: "Note")
        
        // Configure fetch request based on context
        if let contact = context.contact {
            print("[SampleModeProvider] Fetching notes for specific contact: \(contact.name ?? "unnamed")")
            notesFetchRequest.predicate = NSPredicate(format: "contacts.contacts == %@", contact)
        } else {
            print("[SampleModeProvider] Fetching notes for sample mode")
            // In sample mode, we want to include both sample notes (type 0) and social notes (type 2)
            notesFetchRequest.predicate = NSPredicate(format: "type == %d OR type == %d", 0, NoteType.social.rawValue)
            print("[SampleModeProvider] Using predicate to fetch both sample notes (type 0) and social notes (type \(NoteType.social.rawValue))")
        }
        
        // Sort by date, most recent first
        notesFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
        notesFetchRequest.fetchLimit = 10
        
        // Log the fetch request details
        print("[SampleModeProvider] Fetch request predicate: \(notesFetchRequest.predicate?.description ?? "nil")")
        
        let notes = try viewContext.fetch(notesFetchRequest)
        print("[SampleModeProvider] Fetched \(notes.count) notes")
        
        // Log details of fetched notes
        for (index, note) in notes.enumerated() {
            print("[SampleModeProvider] Note \(index + 1):")
            print("  - Type: \(note.type)")
            print("  - Content: \(note.content ?? "nil")")
            print("  - Created: \(note.createdAt?.description ?? "nil")")
        }
        
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
        print("[SampleModeProvider] Formatted notes result: \(result.isEmpty ? "empty" : "contains notes")")
        return result
    }
    
    /// Generates a system prompt with context and relevant notes
    func generateSystemPromptWithNotes(for context: PromptContext) async throws -> String {
        print("[SampleModeProvider] Starting generateSystemPromptWithNotes")
        
        // First get the base prompt
        var prompt = try await generateSystemPrompt(for: context)
        print("[SampleModeProvider] Base prompt generated: \(prompt)")
        
        // Fetch and append relevant notes
        let notesContext = try await fetchRelevantNotes(for: context)
        if !notesContext.isEmpty {
            print("[SampleModeProvider] Appending notes to prompt")
            prompt += notesContext
        } else {
            print("[SampleModeProvider] No notes to append")
        }
        
        print("[SampleModeProvider] Final prompt with notes: \(prompt)")
        return prompt
    }
}

// MARK: - Changed Job Provider
struct ChangedJobProvider: SampleModeProvider {
    var baseSystemPrompt: String {
        print("[ChangedJobProvider] Getting baseSystemPrompt")
        return SampleModePrompts.ChangedJob.basePrompt
    }
    
    func generateSystemPrompt(for context: PromptContext) async throws -> String {
        print("[ChangedJobProvider] Starting generateSystemPrompt")
        var prompt = baseSystemPrompt
        print("[ChangedJobProvider] Base prompt: \(prompt)")
        
        // Add debug logging
        print("[ChangedJobProvider] Received question: '\(context.question)'")
        print("[ChangedJobProvider] Question length: \(context.question.count)")
        print("[ChangedJobProvider] Question contains target string: \(context.question.contains("最近的社交"))")
        print("[ChangedJobProvider] Question exact match: \(context.question == "回顾我最近的社交")")
        print("[ChangedJobProvider] Question trimmed: '\(context.question.trimmingCharacters(in: .whitespacesAndNewlines))'")
        
        // Add context-specific guidance
        if context.isContactSpecific {
            print("[ChangedJobProvider] Adding contact-specific guidance")
            prompt += "\n\n" + String(format: SampleModePrompts.ChangedJob.contactSpecificGuidance, context.contact?.name ?? "the contact")
        }
        
        // Add question-specific guidance
        if context.question.contains("明天要跟张总一对一对聊") {
            print("[ChangedJobProvider] Matched one-on-one meeting question")
            prompt += SampleModePrompts.ChangedJob.oneOnOneMeetingGuidance
        } else if context.question.contains("最近的社交") {
            print("[ChangedJobProvider] Matched recent social interactions question")
            prompt += SampleModePrompts.ChangedJob.recentSocialGuidance
        } else {
            print("[ChangedJobProvider] No specific question pattern matched")
        }
        
        print("[ChangedJobProvider] Final prompt before notes: \(prompt)")
        return prompt
    }
    
    var suggestedQuestions: [SocialBrainMessage] {
        [
            SocialBrainMessage(content: "回顾我最近的社交", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "明天要跟张总一对一对聊，帮我准备一下", isFromUser: false, timestamp: Date())
        ]
    }
    
    var contactSpecificQuestions: (Contact) -> [SocialBrainMessage] {
        { contact in
            [
                SocialBrainMessage(content: "与\(contact.name ?? "这位同事")的第一次会议应该注意什么？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "如何与\(contact.name ?? "这位同事")建立工作默契？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "\(contact.name ?? "这位同事")在团队中扮演什么角色？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "如何与\(contact.name ?? "这位同事")进行有效的工作沟通？", isFromUser: false, timestamp: Date())
            ]
        }
    }
}

// MARK: - Changed School Provider
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
        
        // Fetch and append relevant notes
        let notesContext = try await fetchRelevantNotes(for: context)
        if !notesContext.isEmpty {
            prompt += notesContext
        }
        
        prompt += "\n\nUse the provided notes to give context-aware advice."
        return prompt
    }
    
    var suggestedQuestions: [SocialBrainMessage] {
        [
            SocialBrainMessage(content: "回顾我最近的社交", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "明天要跟张总一对一聊聊，帮我准备下社交素材？", isFromUser: false, timestamp: Date())
        ]
    }
    
    var contactSpecificQuestions: (Contact) -> [SocialBrainMessage] {
        { contact in
            [
                SocialBrainMessage(content: "如何与\(contact.name ?? "这位老师")沟通孩子的学习情况？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "\(contact.name ?? "这位老师")的教学风格是什么？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "如何配合\(contact.name ?? "这位老师")的教育工作？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "如何与\(contact.name ?? "这位老师")建立互信关系？", isFromUser: false, timestamp: Date())
            ]
        }
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
            prompt += "\n\n" + String(format: SampleModePrompts.CareerPivot.contactSpecificGuidance, context.contact?.name ?? "the mentor")
        }
        
        if context.question.contains("技能") {
            prompt += "\n\n" + SampleModePrompts.CareerPivot.skillAssessmentGuidance
        } else if context.question.contains("人脉") {
            prompt += "\n\n" + SampleModePrompts.CareerPivot.networkBuildingGuidance
        }
        
        // Fetch and append relevant notes
        let notesContext = try await fetchRelevantNotes(for: context)
        if !notesContext.isEmpty {
            prompt += notesContext
        }
        
        prompt += "\n\nUse the provided notes to give context-aware advice."
        return prompt
    }
    
    var suggestedQuestions: [SocialBrainMessage] {
        [
            SocialBrainMessage(content: "如何评估我的技能在新领域的价值？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "如何建立新的职业人脉？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "如何平衡当前工作与转型准备？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "如何制定可行的转型计划？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "如何准备面试和简历？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "如何管理转型期的压力？", isFromUser: false, timestamp: Date())
        ]
    }
    
    var contactSpecificQuestions: (Contact) -> [SocialBrainMessage] {
        { contact in
            [
                SocialBrainMessage(content: "如何向\(contact.name ?? "这位导师")请教职业建议？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "\(contact.name ?? "这位导师")在目标行业有什么经验？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "如何与\(contact.name ?? "这位导师")建立mentor关系？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "如何向\(contact.name ?? "这位导师")展示我的转型决心？", isFromUser: false, timestamp: Date())
            ]
        }
    }
}

// MARK: - Indie Dev Provider
struct IndieDevProvider: SampleModeProvider {
    var baseSystemPrompt: String {
        SampleModePrompts.IndieDev.basePrompt
    }
    
    func generateSystemPrompt(for context: PromptContext) async throws -> String {
        var prompt = baseSystemPrompt
        
        if context.isContactSpecific {
            prompt += "\n\n" + String(format: SampleModePrompts.IndieDev.contactSpecificGuidance, context.contact?.name ?? "the developer")
        }
        
        // Fetch and append relevant notes
        let notesContext = try await fetchRelevantNotes(for: context)
        if !notesContext.isEmpty {
            prompt += notesContext
        }
        
        prompt += "\n\nUse the provided notes to give context-aware advice."
        return prompt
    }
    
    var suggestedQuestions: [SocialBrainMessage] {
        [
            SocialBrainMessage(content: "最近有没有需要跟进的互动？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "@小蔡 邀请我下周去参加陶艺展，帮我准备一下社交素材", isFromUser: false, timestamp: Date())
        ]
    }
    
    var contactSpecificQuestions: (Contact) -> [SocialBrainMessage] {
        { contact in
            [
                SocialBrainMessage(content: "如何向\(contact.name ?? "这位开发者")请教独立开发经验？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "\(contact.name ?? "这位开发者")的独立开发项目有什么特点？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "如何与\(contact.name ?? "这位开发者")建立技术交流？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "如何向\(contact.name ?? "这位开发者")展示我的项目想法？", isFromUser: false, timestamp: Date())
            ]
        }
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