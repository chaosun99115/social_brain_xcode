import Foundation
import CoreData
import os

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

// MARK: - System Prompt Update Framework

/// Protocol for atomic prompt update functions
protocol PromptUpdateFunction {
    func update(_ prompt: String, userInput: String, sampleMode: String?, sourceType: String, sourceId: String, contact: Contact?) async throws -> String
}

/// Context for prompt updates
struct PromptUpdateContext {
    let sampleMode: String?
    let sourceType: String
    let sourceId: String
    let contact: Contact?
    let userInput: String
    let additionalContext: [String: Any]
    
    init(
        sampleMode: String? = nil,
        sourceType: String = "",
        sourceId: String = "",
        contact: Contact? = nil,
        userInput: String = "",
        additionalContext: [String: Any] = [:]
    ) {
        self.sampleMode = sampleMode
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.contact = contact
        self.userInput = userInput
        self.additionalContext = additionalContext
    }
}

// MARK: - Atomic Update Functions

/// Add notes to system prompt
class AddNoteFunction: PromptUpdateFunction {
    func update(_ prompt: String, userInput: String, sampleMode: String?, sourceType: String, sourceId: String, contact: Contact?) async throws -> String {
        // Extract notes from CoreData based on sample mode
        let notes = extractNotes(sampleMode: sampleMode, sourceType: sourceType, sourceId: sourceId)
        
        // Prepare the notes section
        let notesSection: String
        if let notes = notes, !notes.isEmpty {
            notesSection = "\n\n==== 互动记录如下: ==== \n\(notes)"
        } else {
            notesSection = "\n\n==== 互动记录如下: ==== \n暂时没有记录"
        }
        
        // Check if notes section already exists and replace it
        if prompt.contains("==== 互动记录如下: ====") {
            let pattern = "==== 互动记录如下: ====.*?(?=\n\n====|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
                let result = regex.stringByReplacingMatches(in: prompt, options: [], range: range, withTemplate: notesSection)
                return result
            }
        }
        
        return prompt + notesSection
    }
    
    private func extractNotes(sampleMode: String?, sourceType: String, sourceId: String) -> String? {
        // Determine note type and subtype based on sample mode
        let noteType: Int16
        let noteSubType: Int16 = 1 // Always subtype 1 as per requirements
        
        if let mode = sampleMode, !mode.isEmpty {
            noteType = 0 // All sample modes: type = 0, subtype = 1
        } else {
            noteType = 1 // Non-sample mode: type = 1, subtype = 1
        }
        
        // Fetch notes from CoreData
        let notes = NoteManager.shared.fetchNotes(type: noteType, subType: noteSubType)
        
        // Format notes for the prompt
        let formattedNotes = notes.compactMap { note -> String? in
            guard let content = note.content,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let date = note.createdAt else { return nil }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let dateStr = dateFormatter.string(from: date)
            
            return "[\(dateStr)] \(content)"
        }.joined(separator: "\n")
        
        guard !formattedNotes.isEmpty else {
            return nil
        }
        
        // Add context information if available
        var enhancedNotes = formattedNotes
    
        
        return enhancedNotes
    }
}

/// Add topics to system prompt
class AddTopicFunction: PromptUpdateFunction {
    func update(_ prompt: String, userInput: String, sampleMode: String?, sourceType: String, sourceId: String, contact: Contact?) async throws -> String {
        // Extract topics from user input with context
        let topics = extractTopics(from: userInput, sampleMode: sampleMode, sourceType: sourceType, sourceId: sourceId)
        
        // Prepare the topics section
        let topicsSection: String
        if let topics = topics, !topics.isEmpty {
            topicsSection = "\n\n==== 话题库如下: ==== \n\(topics)"
        } else {
            topicsSection = "\n\n==== 话题库如下: ==== \n暂时没有记录"
        }
        
        // Check if topics section already exists and replace it
        if prompt.contains("==== 话题库如下: ====") {
            let pattern = "==== 话题库如下: ====.*?(?=\n\n====|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
                let result = regex.stringByReplacingMatches(in: prompt, options: [], range: range, withTemplate: topicsSection)
                return result
            }
        }
        
        return prompt + topicsSection
    }
    
    private func extractTopics(from text: String, sampleMode: String?, sourceType: String, sourceId: String) -> String? {
        // Determine note type and subtype based on sample mode
        let noteType: Int16
        let noteSubType: Int16 = 2 // Always subtype 2 as per requirements
        
        if let mode = sampleMode, !mode.isEmpty {
            noteType = 0 // Sample mode: type = 0, subtype = 2
        } else {
            noteType = 1 // Non-sample mode: type = 1, subtype = 2
        }
        
        // Fetch topic notes from CoreData
        let topicNotes = NoteManager.shared.fetchNotes(type: noteType, subType: noteSubType)
        
        // Format topic notes for the prompt
        let formattedTopics = topicNotes.compactMap { note -> String? in
            guard let content = note.content,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let date = note.createdAt else { return nil }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let dateStr = dateFormatter.string(from: date)
            
            return "[\(dateStr)] \(content)"
        }.joined(separator: "\n")
        
        guard !formattedTopics.isEmpty else {
            return nil
        }
        
        // Enhanced extraction logic based on context
        var enhancedTopics = formattedTopics
        
        return enhancedTopics
    }
}

/// Add contact information to system prompt
class AddContactFunction: PromptUpdateFunction {
    func update(_ prompt: String, userInput: String, sampleMode: String?, sourceType: String, sourceId: String, contact: Contact?) async throws -> String {
        // Extract contact info based on sample mode and type
        let contactInfo = extractContactInfo(contact: contact, sampleMode: sampleMode, sourceType: sourceType, sourceId: sourceId)
        
        // Check if contact section already exists and replace it
        if prompt.contains("==== 熟人信息如下 ====") {
            let pattern = "==== 熟人信息如下 ====.*?(?=\n\n====|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
                let result = regex.stringByReplacingMatches(in: prompt, options: [], range: range, withTemplate: contactInfo)
                return result
            }
        }
        
        return prompt + contactInfo
    }
    
    private func extractContactInfo(contact: Contact?, sampleMode: String?, sourceType: String, sourceId: String) -> String {
        // Determine contact type based on sample mode
        let contactType: Int16
        if let mode = sampleMode, !mode.isEmpty {
            contactType = 0 // Sample mode: type = 0
        } else {
            contactType = 1 // Non-sample mode: type = 1
        }
        
        // Fetch contacts from CoreData based on type
        let contacts = ContactManager.shared.fetchContacts(byType: contactType)
        
        // Format contacts for the prompt
        if contacts.count > 0 {
            let formattedContacts = contacts.compactMap { contact -> String? in
                guard let name = contact.name,
                      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                
                var contactInfo = "姓名: \(name)"
                
                // Add telephone information
                if let tel = contact.tel, !tel.isEmpty {
                    contactInfo += ", 电话: \(tel)"
                } else {
                    contactInfo += ", 电话: (尚未设置)"
                }

                // Add birthday information
                if let birthday = contact.birthday {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    let birthdayStr = dateFormatter.string(from: birthday)
                    contactInfo += ", 生日: \(birthdayStr)"
                } else {
                    contactInfo += ", 生日: (尚未设置)"
                }
                
                // Add memo information
                if let memo = contact.memo, !memo.isEmpty {
                    contactInfo += ", 备注: \(memo)"
                } else {
                    contactInfo += ", 备注: (尚未设置)"
                }
                
                return contactInfo
            }.joined(separator: "\n")
            
            // Check if we have any valid formatted contacts
            if !formattedContacts.isEmpty {
                return """
                
                \n\n==== 熟人信息如下 ====
                \(formattedContacts)
                """
            }
        }
        
        // Return empty state message
        return """
        
        \n\n==== 熟人信息如下 ====
        暂时没有记录
        """
    }
}

/// Add circle/network information to system prompt
class AddCircleFunction: PromptUpdateFunction {
    func update(_ prompt: String, userInput: String, sampleMode: String?, sourceType: String, sourceId: String, contact: Contact?) async throws -> String {
        // Extract circles from user input with context
        let circles = extractCircles(from: userInput, sampleMode: sampleMode, sourceType: sourceType, sourceId: sourceId)
        
        // Prepare the circlesSection
        let circlesSection: String
        if let circles = circles, !circles.isEmpty {
            circlesSection = "\n\n==== 圈子信息如下: ==== \n\(circles)"
        } else {
            circlesSection = "\n\n==== 圈子信息如下: ==== \n暂时没有记录"
        }
        
        // Check if circles section already exists and replace it
        if prompt.contains("==== 圈子信息如下: ====") {
            let pattern = "==== 圈子信息如下: ====.*?(?=\n\n====|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
                let result = regex.stringByReplacingMatches(in: prompt, options: [], range: range, withTemplate: circlesSection)
                return result
            }
        }
        
        return prompt + circlesSection
    }
    
    private func extractCircles(from text: String, sampleMode: String?, sourceType: String, sourceId: String) -> String? {
        // Determine circle type based on sample mode
        let circleType: Int16
        if let mode = sampleMode, !mode.isEmpty {
            circleType = 0 // Sample mode: type = 0
        } else {
            circleType = 1 // Non-sample mode: type = 1
        }
        
        // Fetch circles from CoreData based on type
        let circles = CircleManager.shared.fetchCircles(byType: circleType)
        
        // Format circles for the prompt
        if circles.count > 0 {
            let formattedCircles = circles.compactMap { circle -> String? in
                guard let name = circle.name,
                      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                
                var circleInfo = "圈子名称: \(name)"
                
                // Get contacts for this circle
                if let circleId = circle.circleId {
                    let contacts = CircleManager.shared.getContactsForCircle(circleId: circleId)
                    // Filter out archived contacts
                    let nonArchivedContacts = contacts.filter { !$0.isArchived }
                    if !nonArchivedContacts.isEmpty {
                        let contactNames = nonArchivedContacts.compactMap { contact -> String? in
                            guard let contactName = contact.name,
                                  !contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                            return contactName
                        }.joined(separator: ", ")
                        
                        if !contactNames.isEmpty {
                            circleInfo += "\n  成员: \(contactNames)"
                        }
                    }
                }
                
                return circleInfo
            }.joined(separator: "\n\n")
            
            return formattedCircles
        } else {
            return nil
        }
    }
}

/// Add source information to system prompt
class AddSourceInfoFunction: PromptUpdateFunction {
    func update(_ prompt: String, userInput: String, sampleMode: String?, sourceType: String, sourceId: String, contact: Contact?) async throws -> String {
        var sourceInfo = ""
        
        // Add specific entity information based on sourceType
        if let entityInfo = extractSpecificEntityInfo(sourceType: sourceType, sourceId: sourceId) {
            sourceInfo += entityInfo
        }
        
        return prompt + sourceInfo
    }
    
    private func extractSpecificEntityInfo(sourceType: String, sourceId: String) -> String? {
        guard let sourceUUID = UUID(uuidString: sourceId) else {
            return nil
        }
        
        switch sourceType {
        case "contact":
            return extractContactInfo(contactId: sourceUUID)
        case "note":
            return extractNoteInfo(noteId: sourceUUID)
        default:
            return nil
        }
    }
    
    private func extractContactInfo(contactId: UUID) -> String? {
        guard let contact = ContactManager.shared.fetchContact(withId: contactId) else {
            return nil
        }
        
        var contactInfo = "\n\n====指定熟人如下===="
        
        // Add contact name
        if let name = contact.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contactInfo += "\n姓名: \(name)"
        } else {
            contactInfo += "\n姓名: (尚未设置)"
        }
        
        // Add telephone information
        if let tel = contact.tel, !tel.isEmpty {
            contactInfo += "\n电话: \(tel)"
        } else {
            contactInfo += "\n电话: (尚未设置)"
        }
        
        // Add birthday information
        if let birthday = contact.birthday {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let birthdayStr = dateFormatter.string(from: birthday)
            contactInfo += "\n生日: \(birthdayStr)"
        } else {
            contactInfo += "\n生日: (尚未设置)"
        }
        
        // Add memo information
        if let memo = contact.memo, !memo.isEmpty {
            contactInfo += "\n备注: \(memo)"
        } else {
            contactInfo += "\n备注: (尚未设置)"
        }
        
        // Add creation date
        if let createdAt = contact.createdAt {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let createdStr = dateFormatter.string(from: createdAt)
            contactInfo += "\n创建时间: \(createdStr)"
        }
        
        return contactInfo
    }
    
    private func extractNoteInfo(noteId: UUID) -> String? {
        guard let note = NoteManager.shared.fetchNote(withId: noteId) else {
            return nil
        }
        
        var noteInfo = "\n\n====指定笔记如下===="
        
        // Add note content
        if let content = note.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            noteInfo += "\n内容: \(content)"
        } else {
            noteInfo += "\n内容: (空)"
        }
        
        // Add creation date
        if let createdAt = note.createdAt {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let createdStr = dateFormatter.string(from: createdAt)
            noteInfo += "\n创建时间: \(createdStr)"
        }
        
        return noteInfo
    }
}

// MARK: - Update Configuration Manager

/// Manages prompt update configurations based on flow types
/// 
/// This class ensures that sections are added to the system prompt in the exact order
/// specified by the getUpdateConfiguration method. Each update function will:
/// 1. Check if its section already exists in the prompt
/// 2. Replace the existing section if found, or add a new one if not found
/// 3. Maintain the order specified in the configuration
/// 
/// Function Mapping:
/// - [0] = AddNoteFunction (==== 互动记录如下: ====)
/// - [1] = AddTopicFunction (==== 话题库如下: ====)
/// - [2] = AddContactFunction (==== 熟人信息如下 ====)
/// - [3] = AddCircleFunction (==== 圈子信息如下: ====)
/// - [4] = AddSourceInfoFunction (来源信息:)
/// 
/// Configuration Examples:
/// - QuestionFlow: [0, 1, 2] → Notes → Topics → Contact
/// - ChatFlow: [1, 2, 4] → Topics → Contact → Source
/// - ContactFlow: [0, 1, 2, 3, 4] → Notes → Topics → Contact → Circle → Source
class PromptUpdateManager {
    static let shared = PromptUpdateManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "PromptUpdateManager")
    
    // Function Mapping:
    // [0] = AddNoteFunction
    // [1] = AddTopicFunction
    // [2] = AddContactFunction
    // [3] = AddCircleFunction
    // [4] = AddSourceInfoFunction
    private let updateFunctions: [PromptUpdateFunction] = [
        AddNoteFunction(),
        AddTopicFunction(),
        AddContactFunction(),
        AddCircleFunction(),
        AddSourceInfoFunction()
    ]
    
    private init() {}
    
    /// Configuration for different flow types
    private func getUpdateConfiguration(for flowType: String) -> [Int] {
        switch flowType {
        case "QuestionFlow":
            return [0, 1, 2, 3] // notes, topics, contact
        case "ChatFlow":
            return [0, 1, 2, 3] // topics, contact, source
        case "NoteFlow":
            return [4] // notes, topics, source
        case "ContactFlow":
            return [0, 1, 2, 3, 4] // notes, topics, contact, circle, source
        default:
            return [0, 4] // notes, source (default)
        }
    }
    
    /// Update system prompt based on flow type and context
    func updateSystemPrompt(
        _ prompt: String,
        flowType: String,
        userInput: String,
        sampleMode: String?,
        sourceType: String,
        sourceId: String,
        contact: Contact?
    ) async throws -> String {
        let functionIndices = getUpdateConfiguration(for: flowType)
        
        var updatedPrompt = prompt
        
        // Process functions in the exact order specified by configuration
        for (index, functionIndex) in functionIndices.enumerated() {
            guard functionIndex < updateFunctions.count else { 
                continue 
            }
            
            updatedPrompt = try await updateFunctions[functionIndex].update(
                updatedPrompt,
                userInput: userInput,
                sampleMode: sampleMode,
                sourceType: sourceType,
                sourceId: sourceId,
                contact: contact
            )
        }
        
        // Verify section order
        let orderCorrect = verifySectionOrder(updatedPrompt, flowType: flowType)
        
        return updatedPrompt
    }
    
    /// Verify that sections appear in the correct order based on configuration
    func verifySectionOrder(_ prompt: String, flowType: String) -> Bool {
        let functionIndices = getUpdateConfiguration(for: flowType)
        let sectionMarkers = functionIndices.map { index -> String in
            switch index {
            case 0: return "==== 互动记录如下: ===="
            case 1: return "==== 话题库如下: ===="
            case 2: return "==== 熟人信息如下 ===="
            case 3: return "==== 圈子信息如下: ===="
            case 4: return "来源信息:"
            default: return ""
            }
        }.filter { !$0.isEmpty }
        
        var lastIndex = -1
        for (index, marker) in sectionMarkers.enumerated() {
            if let markerIndex = prompt.range(of: marker)?.lowerBound {
                let markerPosition = prompt.distance(from: prompt.startIndex, to: markerIndex)
                if markerPosition <= lastIndex {
                    return false
                }
                lastIndex = markerPosition
            } else {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Enhanced PromptFlow Classes


/// Flow for handling contact-specific prompts
class ContactFlow: PromptFlowProtocol {
    private let promptManager = PromptConfigurationManager.shared
    private let updateManager = PromptUpdateManager.shared
    
    func generatePrompts(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> PromptPair {
        guard let contact = contact else {
            throw PromptError.contactRequired
        }
        
        let context = try await CoreDataManager.shared.viewContext
        let prompts = promptManager.getPromptsForSourceType(
            sourceType,
            sampleMode: sampleMode,
            context: context,
            contact: contact
        )
        
        // Contact-specific prompts use identifier 5
        if let prompt = prompts.first(where: { $0.identifier == 5 }) {
            let prompts = promptManager.getSystemAndUserPrompts(from: prompt)
            var systemPrompt = prompts.systemPrompt
            
            // Apply system prompt updates if we have context
            if let promptDisplay = promptDisplay {
                systemPrompt = try await updateManager.updateSystemPrompt(
                    systemPrompt,
                    flowType: "ContactFlow",
                    userInput: promptDisplay,
                    sampleMode: sampleMode,
                    sourceType: sourceType,
                    sourceId: sourceId,
                    contact: contact
                )
            }
            
            let promptPair = PromptPair(
                systemPrompt: systemPrompt,
                userPrompt: prompts.userPrompt
            )
            return promptPair
        }
        
        // Fallback to dynamic generation if no configured prompt found
        var systemPrompt = "You are analyzing a specific contact with ID: \(sourceId). "
        systemPrompt += "Focus on providing insights about this contact's relationship with the user, "
        systemPrompt += "suggesting conversation topics, and identifying opportunities for deeper connection."
        
        if let display = promptDisplay {
            systemPrompt += "\n\nUser Question: \(display)"
        }
        
        let promptPair = PromptPair(systemPrompt: systemPrompt, userPrompt: nil)
        return promptPair
    }
}

/// Flow for handling general prompts
class ChatFlow: PromptFlowProtocol {
    private let promptManager = PromptConfigurationManager.shared
    private let updateManager = PromptUpdateManager.shared
    
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
        fetchRequest.predicate = NSPredicate(format: "identifier == %d AND (isArchived == NO OR isArchived == nil)", promptIdentifier)
        fetchRequest.fetchLimit = 1
        
        let prompts = try context.fetch(fetchRequest)
        
        if let prompt = prompts.first {
            guard let content = prompt.content else {
                throw PromptError.promptNotFound
            }
            
            var systemPrompt = content
            
            // Apply system prompt updates if we have context
            if let promptDisplay = promptDisplay {
                systemPrompt = try await updateManager.updateSystemPrompt(
                    systemPrompt,
                    flowType: "ChatFlow",
                    userInput: promptDisplay,
                    sampleMode: sampleMode,
                    sourceType: sourceType,
                    sourceId: sourceId,
                    contact: contact
                )
                systemPrompt += "\n\nUser Question: \(promptDisplay)"
            }
            
            let promptPair = PromptPair(systemPrompt: systemPrompt, userPrompt: nil)
            return promptPair
        }
        
        throw PromptError.promptNotFound
    }
}

/// Flow for handling note-specific prompts
class NoteFlow: PromptFlowProtocol {
    private let promptManager = PromptConfigurationManager.shared
    private let updateManager = PromptUpdateManager.shared
    
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
        fetchRequest.predicate = NSPredicate(format: "identifier == %d AND (isArchived == NO OR isArchived == nil)", promptIdentifier)
        fetchRequest.fetchLimit = 1
        
        let prompts = try context.fetch(fetchRequest)
        
        if let prompt = prompts.first {
            guard let content = prompt.content else {
                throw PromptError.promptNotFound
            }
            
            var systemPrompt = content
            
            // Apply system prompt updates if we have context
            if let promptDisplay = promptDisplay {
                systemPrompt = try await updateManager.updateSystemPrompt(
                    systemPrompt,
                    flowType: "NoteFlow",
                    userInput: promptDisplay,
                    sampleMode: sampleMode,
                    sourceType: sourceType,
                    sourceId: sourceId,
                    contact: contact
                )
            }
            
            let promptPair = PromptPair(
                systemPrompt: systemPrompt,
                userPrompt: promptDisplay
            )
            
            return promptPair
        }
        
        throw PromptError.promptNotFound
    }
}

/// Flow for handling question-specific prompts
class QuestionFlow: PromptFlowProtocol {
    private let promptManager = PromptConfigurationManager.shared
    private let updateManager = PromptUpdateManager.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "QuestionFlow")
    
    func generatePrompts(
        sourceType: String,
        sourceAction: String,
        sourceId: String,
        sampleMode: String?,
        contact: Contact?,
        promptDisplay: String?,
        promptIdentifier: Int
    ) async throws -> PromptPair {
        guard let promptDisplay = promptDisplay else {
            throw PromptError.questionRequired
        }
        
        let context = try await CoreDataManager.shared.viewContext
        
        // Fetch prompt entity directly using identifier
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %d AND (isArchived == NO OR isArchived == nil)", promptIdentifier)
        fetchRequest.fetchLimit = 1
        
        let prompts = try context.fetch(fetchRequest)
        
        if let prompt = prompts.first {
            guard let content = prompt.content else {
                throw PromptError.promptNotFound
            }
            
            // For questions, we'll use the prompt content as system prompt
            // and the promptDisplay as the user prompt
            var systemPrompt = "====default system prompt====\n" + content
            
            // Apply system prompt updates
            systemPrompt = try await updateManager.updateSystemPrompt(
                systemPrompt,
                flowType: "QuestionFlow",
                userInput: promptDisplay,
                sampleMode: sampleMode,
                sourceType: sourceType,
                sourceId: sourceId,
                contact: contact
            )
            
            let promptPair = PromptPair(
                systemPrompt: systemPrompt,
                userPrompt: promptDisplay
            )
            
            return promptPair
        }
        
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