import Foundation
import social_brain_xcode  // Import the main module to access AIConfig

// Updated to use new model types for Doubao 1.5 and non-1.5 series
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
        case .doubaoLite:
            chatService = DoubaoChatService(apiKey: apiKey, modelType: .lite)
        case .doubaoPro:
            chatService = DoubaoChatService(apiKey: apiKey, modelType: .pro)
        case .doubao1_5Pro256k:
            chatService = DoubaoChatService(apiKey: apiKey, modelType: .pro1_5_256k)
        case .doubaoPro256k:
            chatService = DoubaoChatService(apiKey: apiKey, modelType: .pro256k)
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