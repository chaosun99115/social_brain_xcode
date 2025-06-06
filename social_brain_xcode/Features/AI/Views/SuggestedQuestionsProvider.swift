import Foundation

struct SuggestedQuestionsProvider {
    static func forContext(sourceType: String, sourceAction: String, contact: Contact?) -> [SocialBrainMessage] {
        print("[SuggestedQuestionsProvider] forContext called with:")
        print("- sourceType: \(sourceType)")
        print("- sourceAction: \(sourceAction)")
        print("- contact: \(contact?.name ?? "nil")")
        
        switch (sourceType, sourceAction) {
        case ("contact", "general"):
            print("[SuggestedQuestionsProvider] Routing to forContact")
            return forContact(contact)
        case ("contact", "insights"):
            print("[SuggestedQuestionsProvider] Routing to forContactInsights")
            return forContactInsights(contact)
        default:
            print("[SuggestedQuestionsProvider] Routing to general")
            return general()
        }
    }
    
    static func forContact(_ contact: Contact?) -> [SocialBrainMessage] {
        print("[SuggestedQuestionsProvider] forContact called with contact: \(contact?.name ?? "nil")")
        
        guard let name = contact?.name, !name.isEmpty else {
            print("[SuggestedQuestionsProvider] No contact name found, returning fallback questions")
            return [
                SocialBrainMessage(content: "社交备忘录", isFromUser: false, timestamp: Date(), promptIdentifier: 1)
            ]
        }
        
        print("[SuggestedQuestionsProvider] Returning personalized question for contact: \(name)")
        return [
            SocialBrainMessage(content: "查看 \(name) 的社交备忘录", isFromUser: false, timestamp: Date(), promptIdentifier: 1)
        ]
    }
    
    static func forContactInsights(_ contact: Contact?) -> [SocialBrainMessage] {
        guard let name = contact?.name, !name.isEmpty else {
            return [
                SocialBrainMessage(content: "分析一下我与这个联系人的关系现状", isFromUser: false, timestamp: Date(), promptIdentifier: 5),
                SocialBrainMessage(content: "我们之间有什么共同话题？", isFromUser: false, timestamp: Date(), promptIdentifier: 5),
                SocialBrainMessage(content: "如何改善我们的关系？", isFromUser: false, timestamp: Date(), promptIdentifier: 5)
            ]
        }
        
        return [
            SocialBrainMessage(content: "分析一下我与 \(name) 的关系现状", isFromUser: false, timestamp: Date(), promptIdentifier: 5),
            SocialBrainMessage(content: "我与 \(name) 之间有什么共同话题？", isFromUser: false, timestamp: Date(), promptIdentifier: 5),
            SocialBrainMessage(content: "如何改善我与 \(name) 的关系？", isFromUser: false, timestamp: Date(), promptIdentifier: 5),
            SocialBrainMessage(content: "\(name) 最近有什么变化值得关注？", isFromUser: false, timestamp: Date(), promptIdentifier: 5)
        ]
    }

    static func general() -> [SocialBrainMessage] {
        return [
            SocialBrainMessage(content: "怎样使用 社交大脑", isFromUser: false, timestamp: Date(), promptIdentifier: 1)
        ]
    }
} 