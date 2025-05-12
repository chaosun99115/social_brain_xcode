import Foundation

struct SuggestedQuestionsProvider {
    static func forContact(_ contact: Contact?) -> [SocialBrainMessage] {
        guard let name = contact?.name, !name.isEmpty else {
            return [
                SocialBrainMessage(content: "关于这个联系人，你想问什么？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "如何与这个联系人建立更深层次的关系？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "有什么话题可以增进我们的交流？", isFromUser: false, timestamp: Date()),
                SocialBrainMessage(content: "如何更好地维护这段关系？", isFromUser: false, timestamp: Date())
            ]
        }
        
        return [
            SocialBrainMessage(content: "与 \(name)聊些什么比较合适？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "与 \(name) 聊天有什么要注意的吗？", isFromUser: false, timestamp: Date())
        ]
    }

    static func general() -> [SocialBrainMessage] {
        return [
            SocialBrainMessage(content: "如何与这个联系人建立更深层次的关系？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "有什么话题可以增进我们的交流？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "如何更好地维护这段关系？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "最近有什么值得关注的变化？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "如何准备下一次的交流话题？", isFromUser: false, timestamp: Date()),
            SocialBrainMessage(content: "有什么共同兴趣可以发展？", isFromUser: false, timestamp: Date())
        ]
    }
} 