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
        print("[AddNoteFunction] Starting update")
        print("[AddNoteFunction] Sample mode: \(sampleMode ?? "nil")")
        print("[AddNoteFunction] Source type: \(sourceType)")
        print("[AddNoteFunction] Source ID: \(sourceId)")
        
        // Extract notes from CoreData based on sample mode
        let notes = extractNotes(sampleMode: sampleMode, sourceType: sourceType, sourceId: sourceId)
        
        // Prepare the notes section
        let notesSection: String
        if let notes = notes, !notes.isEmpty {
            print("[AddNoteFunction] Adding notes section with actual notes")
            notesSection = "\n\n==== 互动记录如下: ==== \n\(notes)"
        } else {
            print("[AddNoteFunction] Adding notes section with '暂时没有记录'")
            notesSection = "\n\n==== 互动记录如下: ==== \n暂时没有记录"
        }
        
        // Check if notes section already exists and replace it
        if prompt.contains("==== 互动记录如下: ====") {
            print("[AddNoteFunction] Replacing existing notes section")
            let pattern = "==== 互动记录如下: ====.*?(?=\n\n====|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
                let result = regex.stringByReplacingMatches(in: prompt, options: [], range: range, withTemplate: notesSection)
                print("[AddNoteFunction] Notes section replaced")
                return result
            }
        }
        
        print("[AddNoteFunction] Adding new notes section")
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
        
        print("[AddNoteFunction] 获取笔记: \(noteType), subtype: \(noteSubType)")
        print("[AddNoteFunction] 示例模式: \(sampleMode ?? "nil")")
        
        // Fetch notes from CoreData
        let notes = NoteManager.shared.fetchNotes(type: noteType, subType: noteSubType)
        print("[AddNoteFunction] Found \(notes.count) notes")
        
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
            print("[AddNoteFunction] No valid notes found")
            return nil
        }
        
        print("[AddNoteFunction] Formatted notes length: \(formattedNotes.count)")
        
        // Add context information if available
        var enhancedNotes = formattedNotes
    
        
        return enhancedNotes
    }
}

/// Add topics to system prompt
class AddTopicFunction: PromptUpdateFunction {
    func update(_ prompt: String, userInput: String, sampleMode: String?, sourceType: String, sourceId: String, contact: Contact?) async throws -> String {
        print("[AddTopicFunction] Starting update")
        print("[AddTopicFunction] Input length: \(userInput.count)")
        print("[AddTopicFunction] Sample mode: \(sampleMode ?? "nil")")
        print("[AddTopicFunction] Source type: \(sourceType)")
        print("[AddTopicFunction] Source ID: \(sourceId)")
        
        // Extract topics from user input with context
        let topics = extractTopics(from: userInput, sampleMode: sampleMode, sourceType: sourceType, sourceId: sourceId)
        
        print("[AddTopicFunction] Extracted topics length: \(topics?.count ?? 0)")
        
        // Prepare the topics section
        let topicsSection: String
        if let topics = topics, !topics.isEmpty {
            print("[AddTopicFunction] Adding topics section with actual topics")
            topicsSection = "\n\n==== 话题库如下: ==== \n\(topics)"
        } else {
            print("[AddTopicFunction] Adding topics section with '暂时没有记录'")
            topicsSection = "\n\n==== 话题库如下: ==== \n暂时没有记录"
        }
        
        // Check if topics section already exists and replace it
        if prompt.contains("==== 话题库如下: ====") {
            print("[AddTopicFunction] Replacing existing topics section")
            let pattern = "==== 话题库如下: ====.*?(?=\n\n====|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
                let result = regex.stringByReplacingMatches(in: prompt, options: [], range: range, withTemplate: topicsSection)
                print("[AddTopicFunction] Topics section replaced")
                return result
            }
        }
        
        print("[AddTopicFunction] Adding new topics section")
        return prompt + topicsSection
    }
    
    private func extractTopics(from text: String, sampleMode: String?, sourceType: String, sourceId: String) -> String? {
        print("[AddTopicFunction] Extracting topics from text")
        print("[AddTopicFunction] Sample mode: \(sampleMode ?? "nil")")
        
        // Determine note type and subtype based on sample mode
        let noteType: Int16
        let noteSubType: Int16 = 2 // Always subtype 2 as per requirements
        
        if let mode = sampleMode, !mode.isEmpty {
            noteType = 0 // Sample mode: type = 0, subtype = 2
        } else {
            noteType = 1 // Non-sample mode: type = 1, subtype = 2
        }
        
        print("[AddTopicFunction] 获取话题笔记: \(noteType), subtype: \(noteSubType)")
        
        // Fetch topic notes from CoreData
        let topicNotes = NoteManager.shared.fetchNotes(type: noteType, subType: noteSubType)
        print("[AddTopicFunction] Found \(topicNotes.count) topic notes")
        
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
            print("[AddTopicFunction] No valid topic notes found")
            return nil
        }
        
        print("[AddTopicFunction] Formatted topics length: \(formattedTopics.count)")
        
        // Enhanced extraction logic based on context
        var enhancedTopics = formattedTopics
        
        return enhancedTopics
    }
}

/// Add contact information to system prompt
class AddContactFunction: PromptUpdateFunction {
    func update(_ prompt: String, userInput: String, sampleMode: String?, sourceType: String, sourceId: String, contact: Contact?) async throws -> String {
        print("[AddContactFunction] Starting update")
        print("[AddContactFunction] Input length: \(userInput.count)")
        print("[AddContactFunction] Sample mode: \(sampleMode ?? "nil")")
        print("[AddContactFunction] Source type: \(sourceType)")
        print("[AddContactFunction] Source ID: \(sourceId)")
        print("[AddContactFunction] Contact: \(contact?.name ?? "nil")")
        
        // Extract contact info based on sample mode and type
        let contactInfo = extractContactInfo(contact: contact ?? Contact(), sampleMode: sampleMode, sourceType: sourceType, sourceId: sourceId)
        print("[AddContactFunction] Extracted contact info length: \(contactInfo.count)")
        
        // Check if contact section already exists and replace it
        if prompt.contains("==== 熟人信息如下 ====") {
            print("[AddContactFunction] Replacing existing contact section")
            let pattern = "==== 熟人信息如下 ====.*?(?=\n\n====|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
                let result = regex.stringByReplacingMatches(in: prompt, options: [], range: range, withTemplate: contactInfo)
                print("[AddContactFunction] Contact section replaced")
                return result
            }
        }
        
        print("[AddContactFunction] Adding new contact section")
        return prompt + contactInfo
    }
    
    private func extractContactInfo(contact: Contact, sampleMode: String?, sourceType: String, sourceId: String) -> String {
        print("[AddContactFunction] Extracting contact info")
        print("[AddContactFunction] Sample mode: \(sampleMode ?? "nil")")
        
        // Determine contact type based on sample mode
        let contactType: Int16
        if let mode = sampleMode, !mode.isEmpty {
            contactType = 0 // Sample mode: type = 0
        } else {
            contactType = 1 // Non-sample mode: type = 1
        }
        
        print("[AddContactFunction] Fetching contacts with type: \(contactType)")
        
        // Fetch contacts from CoreData based on type
        let contacts = ContactManager.shared.fetchContacts(byType: contactType)
        print("[AddContactFunction] Found \(contacts.count) contacts with type \(contactType)")
        
        // Format contacts for the prompt
        if contacts.count > 1 {
            print("[AddContactFunction] Adding contacts section with actual contacts")
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
            
            return """
            
            \n\n==== 熟人信息如下 ====
            \(formattedContacts)
            """
        } else {
            print("[AddContactFunction] Adding contacts section with '暂时没有记录'")
            return """
            
            \n\n==== 熟人信息如下 ====
            暂时没有记录
            """
        }
    }
}

/// Add circle/network information to system prompt
class AddCircleFunction: PromptUpdateFunction {
    func update(_ prompt: String, userInput: String, sampleMode: String?, sourceType: String, sourceId: String, contact: Contact?) async throws -> String {
        print("[AddCircleFunction] Starting update")
        print("[AddCircleFunction] Input length: \(userInput.count)")
        print("[AddCircleFunction] Sample mode: \(sampleMode ?? "nil")")
        print("[AddCircleFunction] Source type: \(sourceType)")
        print("[AddCircleFunction] Source ID: \(sourceId)")
        
        // Extract circles from user input with context
        let circles = extractCircles(from: userInput, sampleMode: sampleMode, sourceType: sourceType, sourceId: sourceId)
        
        print("[AddCircleFunction] Extracted circles length: \(circles?.count ?? 0)")
        
        // Prepare the circlesSection
        let circlesSection: String
        if let circles = circles, !circles.isEmpty {
            print("[AddCircleFunction] Adding circles section with actual circles")
            circlesSection = "\n\n==== 圈子信息如下: ==== \n\(circles)"
        } else {
            print("[AddCircleFunction] Adding circles section with '暂时没有记录'")
            circlesSection = "\n\n==== 圈子信息如下: ==== \n暂时没有记录"
        }
        
        // Check if circles section already exists and replace it
        if prompt.contains("==== 圈子信息如下: ====") {
            print("[AddCircleFunction] Replacing existing circles section")
            let pattern = "==== 圈子信息如下: ====.*?(?=\n\n====|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
                let result = regex.stringByReplacingMatches(in: prompt, options: [], range: range, withTemplate: circlesSection)
                print("[AddCircleFunction] Circles section replaced")
                return result
            }
        }
        
        print("[AddCircleFunction] Adding new circles section")
        return prompt + circlesSection
    }
    
    private func extractCircles(from text: String, sampleMode: String?, sourceType: String, sourceId: String) -> String? {
        print("[AddCircleFunction] Extracting circles from text")
        print("[AddCircleFunction] Sample mode: \(sampleMode ?? "nil")")
        
        // Determine circle type based on sample mode
        let circleType: Int16
        if let mode = sampleMode, !mode.isEmpty {
            circleType = 0 // Sample mode: type = 0
        } else {
            circleType = 1 // Non-sample mode: type = 1
        }
        
        print("[AddCircleFunction] 获取圈子: type = \(circleType)")
        
        // Fetch circles from CoreData based on type
        let circles = CircleManager.shared.fetchCircles(byType: circleType)
        print("[AddCircleFunction] Found \(circles.count) circles with type \(circleType)")
        
        // Format circles for the prompt
        if circles.count > 0 {
            print("[AddCircleFunction] Adding circles section with actual circles")
            let formattedCircles = circles.compactMap { circle -> String? in
                guard let name = circle.name,
                      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                
                var circleInfo = "圈子名称: \(name)"
                
                // Get contacts for this circle
                if let circleId = circle.circleId {
                    let contacts = CircleManager.shared.getContactsForCircle(circleId: circleId)
                    if !contacts.isEmpty {
                        let contactNames = contacts.compactMap { contact -> String? in
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
            print("[AddCircleFunction] No valid circles found")
            return nil
        }
    }
}

/// Add source information to system prompt
class AddSourceInfoFunction: PromptUpdateFunction {
    func update(_ prompt: String, userInput: String, sampleMode: String?, sourceType: String, sourceId: String, contact: Contact?) async throws -> String {
        print("[AddSourceInfoFunction] Starting update")
        print("[AddSourceInfoFunction] Input length: \(userInput.count)")
        print("[AddSourceInfoFunction] Sample mode: \(sampleMode ?? "nil")")
        print("[AddSourceInfoFunction] Source type: \(sourceType)")
        print("[AddSourceInfoFunction] Source ID: \(sourceId)")
        
        let sourceInfo = extractSourceInfo(userInput: userInput, sampleMode: sampleMode, sourceType: sourceType, sourceId: sourceId)
        print("[AddSourceInfoFunction] Extracted source info length: \(sourceInfo.count)")
        
        // Check if source info already exists and replace it
        if prompt.contains("来源信息:") {
            print("[AddSourceInfoFunction] Replacing existing source section")
            let pattern = "来源信息:.*?(?=\n\n====|$)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
                let result = regex.stringByReplacingMatches(in: prompt, options: [], range: range, withTemplate: sourceInfo)
                print("[AddSourceInfoFunction] Source section replaced")
                return result
            }
        }
        
        print("[AddSourceInfoFunction] Adding new source section")
        return prompt + sourceInfo
    }
    
    private func extractSourceInfo(userInput: String, sampleMode: String?, sourceType: String, sourceId: String) -> String {
        var sourceInfo = """
        
        来源信息:
        类型: \(sourceType)
        ID: \(sourceId)
        样本模式: \(sampleMode ?? "无")
        """
        
        // Enhanced source info based on context
        if let mode = sampleMode {
            switch mode {
            case "changedJob":
                sourceInfo += "\n场景: 职业转换相关咨询"
            case "indieDev":
                sourceInfo += "\n场景: 独立开发者相关咨询"
            default:
                sourceInfo += "\n场景: 通用社交咨询"
            }
        }
        
        // Add source type specific information
        switch sourceType {
        case "contact":
            sourceInfo += "\n上下文: 联系人特定分析"
        case "note":
            sourceInfo += "\n上下文: 笔记内容分析"
        case "general":
            sourceInfo += "\n上下文: 通用社交建议"
        default:
            sourceInfo += "\n上下文: 未知来源类型"
        }
        
        return sourceInfo
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
            return [1, 2, 4] // topics, contact, source
        case "NoteFlow":
            return [0, 1, 4] // notes, topics, source
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
        print("[PromptUpdateManager] ========================================")
        print("[PromptUpdateManager] Starting prompt update for flow: \(flowType)")
        print("[PromptUpdateManager] Function indices: \(functionIndices)")
        print("[PromptUpdateManager] Function names: \(functionIndices.map { getFunctionName(for: $0) })")
        print("[PromptUpdateManager] ========================================")
        
        var updatedPrompt = prompt
        
        // Process functions in the exact order specified by configuration
        for (index, functionIndex) in functionIndices.enumerated() {
            guard functionIndex < updateFunctions.count else { 
                print("[PromptUpdateManager] Warning: Index \(functionIndex) out of bounds, skipping")
                continue 
            }
            
            let functionName = getFunctionName(for: functionIndex)
            print("[PromptUpdateManager] Step \(index + 1)/\(functionIndices.count): Calling \(functionName) (index: \(functionIndex))")
            
            updatedPrompt = try await updateFunctions[functionIndex].update(
                updatedPrompt,
                userInput: userInput,
                sampleMode: sampleMode,
                sourceType: sourceType,
                sourceId: sourceId,
                contact: contact
            )
            
            print("[PromptUpdateManager] Step \(index + 1)/\(functionIndices.count): \(functionName) completed")
        }
        
        print("[PromptUpdateManager] ========================================")
        print("[PromptUpdateManager] All functions completed for flow: \(flowType)")
        print("[PromptUpdateManager] Final prompt length: \(updatedPrompt.count)")
        
        // Verify section order
        let orderCorrect = verifySectionOrder(updatedPrompt, flowType: flowType)
        if orderCorrect {
            print("[PromptUpdateManager] ✅ Section order verification passed")
        } else {
            print("[PromptUpdateManager] ❌ Section order verification failed")
        }
        
        print("[PromptUpdateManager] ========================================")
        return updatedPrompt
    }
    
    /// Get function name for debugging
    private func getFunctionName(for index: Int) -> String {
        switch index {
        case 0: return "AddNoteFunction"
        case 1: return "AddTopicFunction"
        case 2: return "AddContactFunction"
        case 3: return "AddCircleFunction"
        case 4: return "AddSourceInfoFunction"
        default: return "UnknownFunction(\(index))"
        }
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
        
        print("[PromptUpdateManager] Verifying section order for flow: \(flowType)")
        print("[PromptUpdateManager] Expected order: \(sectionMarkers)")
        
        var lastIndex = -1
        for (index, marker) in sectionMarkers.enumerated() {
            if let markerIndex = prompt.range(of: marker)?.lowerBound {
                let markerPosition = prompt.distance(from: prompt.startIndex, to: markerIndex)
                if markerPosition <= lastIndex {
                    print("[PromptUpdateManager] ❌ Section order violation: \(marker) appears before expected position")
                    return false
                }
                lastIndex = markerPosition
                print("[PromptUpdateManager] ✅ Section \(index + 1): \(marker) at position \(markerPosition)")
            } else {
                print("[PromptUpdateManager] ⚠️ Section not found: \(marker)")
            }
        }
        
        print("[PromptUpdateManager] ✅ All sections in correct order")
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
        fetchRequest.predicate = NSPredicate(format: "identifier == %d", promptIdentifier)
        fetchRequest.fetchLimit = 1
        
        let prompts = try context.fetch(fetchRequest)
        
        if let prompt = prompts.first {
            guard let content = prompt.content else {
                print("[NoteFlow] Error - Prompt found but content is nil")
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