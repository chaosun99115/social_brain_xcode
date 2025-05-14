import Foundation

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
    case changedJob = "换了一份新工作"
    case changedSchool = "孩子进了新学校"
    case careerPivot = "打算职业转型"
    case none = "none"
}

// MARK: - Sample Mode Provider Protocol
protocol SampleModeProvider {
    var baseSystemPrompt: String { get }
    var suggestedQuestions: [SocialBrainMessage] { get }
    var contactSpecificQuestions: (Contact) -> [SocialBrainMessage] { get }
    
    // New method to generate contextual prompt
    func generateSystemPrompt(for context: PromptContext) -> String
}

// MARK: - Changed Job Provider
struct ChangedJobProvider: SampleModeProvider {
    var baseSystemPrompt: String {
        """
        sample mode - 换了一份新工作
        """
    }
    
    func generateSystemPrompt(for context: PromptContext) -> String {
        var prompt = baseSystemPrompt
        
        // Add debug logging
        print("[ChangedJobProvider] Received question: '\(context.question)'")
        print("[ChangedJobProvider] Question length: \(context.question.count)")
        print("[ChangedJobProvider] Question contains target string: \(context.question.contains("明天要跟张总一对一对聊"))")
        
        // Add context-specific guidance
        if context.isContactSpecific {
            prompt += "\n\nFor this specific interaction with \(context.contact?.name ?? "the contact"):"
            prompt += "\n- Focus on building a professional relationship"
            prompt += "\n- Consider their role and influence in the organization"
            prompt += "\n- Identify potential collaboration opportunities"
        }
        
        // Add question-specific guidance
        if context.question.contains("明天要跟张总一对一对聊") {
            print("[ChangedJobProvider] Matched one-on-one meeting question")
            prompt += "test1"
        } else if context.question.contains("最近的社交") {
            print("[ChangedJobProvider] Matched recent social interactions question")
            prompt += "test2"
        } else {
            print("[ChangedJobProvider] No specific question pattern matched")
        }
        
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
        """
        You are an AI assistant helping a user whose child just started at a new school.
        Focus on:
        1. Building relationships with teachers and staff
        2. Understanding school culture and policies
        3. Supporting child's academic and social development
        4. Engaging with other parents
        5. Managing school-home communication
        """
    }
    
    func generateSystemPrompt(for context: PromptContext) -> String {
        var prompt = baseSystemPrompt
        
        if context.isContactSpecific {
            prompt += "\n\nFor this specific interaction with \(context.contact?.name ?? "the teacher"):"
            prompt += "\n- Focus on understanding their teaching approach"
            prompt += "\n- Consider how to best support your child's learning"
            prompt += "\n- Build a collaborative parent-teacher relationship"
        }
        
        if context.question.contains("一对一聊聊") {
            prompt += "\n\nFor this one-on-one meeting preparation:"
            prompt += "\n- Prepare specific questions about your child's progress"
            prompt += "\n- Identify areas where you can support the teacher"
            prompt += "\n- Consider how to maintain open communication"
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
        """
        You are an AI assistant helping a user who is planning a career transition.
        Focus on:
        1. Identifying transferable skills
        2. Building new professional networks
        3. Managing the transition period
        4. Exploring new opportunities
        5. Balancing current job with transition
        """
    }
    
    func generateSystemPrompt(for context: PromptContext) -> String {
        var prompt = baseSystemPrompt
        
        if context.isContactSpecific {
            prompt += "\n\nFor this specific interaction with \(context.contact?.name ?? "the mentor"):"
            prompt += "\n- Focus on learning from their career transition experience"
            prompt += "\n- Identify specific advice for your situation"
            prompt += "\n- Build a meaningful mentor-mentee relationship"
        }
        
        if context.question.contains("技能") {
            prompt += "\n\nFor skill assessment:"
            prompt += "\n- Analyze transferable skills from current role"
            prompt += "\n- Identify skill gaps for target industry"
            prompt += "\n- Suggest skill development opportunities"
        } else if context.question.contains("人脉") {
            prompt += "\n\nFor network building:"
            prompt += "\n- Identify key people in target industry"
            prompt += "\n- Develop networking strategy"
            prompt += "\n- Create meaningful connection opportunities"
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
        default:
            return nil
        }
    }
    
    static func generatePrompt(for mode: String, question: String, contact: Contact? = nil) -> String? {
        guard let provider = getProvider(for: mode) else { return nil }
        let context = PromptContext(
            mode: SampleMode(rawValue: mode) ?? .none,
            question: question,
            contact: contact
        )
        return provider.generateSystemPrompt(for: context)
    }
} 