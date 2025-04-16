import Foundation

struct SocialBrainMessage: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let suggestedAction: String?
    
    init(content: String, isFromUser: Bool, timestamp: Date, suggestedAction: String? = nil) {
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.suggestedAction = suggestedAction
    }
    
    // Mock data for Social Brain - suggested questions and responses
    static let mockMessages = [
        // Suggested questions for the home screen
        SocialBrainMessage(
            content: "最近有什么值得回顾或者需要跟进的社交互动吗？",
            isFromUser: true,
            timestamp: Date()
        ),
        SocialBrainMessage(
            content: "最近的社交互动有提到什么话题是我的盲区吗？",
            isFromUser: true,
            timestamp: Date()
        ),
        SocialBrainMessage(
            content: "我要参加一个社交活动，帮我准备一下能用上的话题。",
            isFromUser: true,
            timestamp: Date()
        )
    ]
} 
