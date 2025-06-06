import Foundation

struct SocialBrainMessage: Identifiable {
    let id = UUID()
    var content: String
    let isFromUser: Bool
    let timestamp: Date
    let suggestedAction: String?
    let promptIdentifier: Int?
    
    init(content: String, isFromUser: Bool, timestamp: Date, suggestedAction: String? = nil, promptIdentifier: Int? = nil) {
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.suggestedAction = suggestedAction
        self.promptIdentifier = promptIdentifier
    }
    
    // Mock data for Social Brain - suggested questions and responses
    static let mockMessages = [
        // Suggested questions for the home screen
        SocialBrainMessage(
            content: "帮我回顾一下最近的社交互动",
            isFromUser: true,
            timestamp: Date()
        ),
        SocialBrainMessage(
            content: "最近有什么需要我跟进的社交互动？",
            isFromUser: true,
            timestamp: Date()
        ),
        SocialBrainMessage(
            content: "帮我为参加的社交活动准备一下话题",
            isFromUser: true,
            timestamp: Date()
        )
    ]
} 
