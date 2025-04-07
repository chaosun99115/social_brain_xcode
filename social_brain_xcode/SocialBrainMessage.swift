import Foundation

struct SocialBrainMessage: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    
    // Mock data for Social Brain
    static let mockMessages = [
        SocialBrainMessage(
            content: "下周要参加大学同学聚会，请帮我准备一些合适的话题，避免尬尴冷场。",
            isFromUser: false,
            timestamp: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        ),
        SocialBrainMessage(
            content: "帮我回顾最近我有什么需要回顾的社交互动吗？",
            isFromUser: false,
            timestamp: Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        ),
        SocialBrainMessage(
            content: "帮我回顾最近我有什么需要特别注意的话题吗？",
            isFromUser: false,
            timestamp: Calendar.current.date(byAdding: .minute, value: -30, to: Date())!
        )
    ]
} 