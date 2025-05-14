import Foundation

class AIServiceManager {
    static let shared = AIServiceManager()
    
    private var chatService: AIChatServiceProtocol?
    
    private init() {}
    
    func configure(with apiKey: String, serviceType: AIServiceType) {
        switch serviceType {
        case .deepSeek:
            chatService = DeepSeekChatService(apiKey: apiKey)
        case .kimi:
            chatService = KIMIChatService(apiKey: apiKey)
        case .doubao_1_5_lite:
            chatService = DoubaoChatService(apiKey: apiKey, modelType: .lite)
        case .doubao_1_5_pro:
            chatService = DoubaoChatService(apiKey: apiKey, modelType: .pro)
        case .doubao_1_5_pro_256k:
            chatService = DoubaoChatService(apiKey: apiKey, modelType: .pro256k)
        case .doubao_pro_256k:
            chatService = DoubaoChatService(apiKey: apiKey, modelType: .pro256k_241115)
        }
    }
    
    func getChatService() -> AIChatServiceProtocol? {
        return chatService
    }
    
    // Helper method to convert SocialBrainMessage to ChatMessage
    func convertToChatMessages(_ messages: [SocialBrainMessage]) -> [AIChatMessage] {
        return messages.map { message in
            AIChatMessage(
                role: message.isFromUser ? .user : .assistant,
                content: message.content
            )
        }
    }
    
    // Helper method to convert ChatCompletionResponse to SocialBrainMessage
    func convertToSocialBrainMessage(_ response: ChatCompletionResponse) -> SocialBrainMessage {
        let content = response.choices.first?.message.content ?? ""
        return SocialBrainMessage(
            content: content,
            isFromUser: false,
            timestamp: Date(),
            suggestedAction: nil // You can implement logic to extract suggested actions from the response
        )
    }
} 