import Foundation    

enum AIServiceType {
    case deepSeek
    case kimi
    case doubaoLite
    case doubaoPro
}

enum DoubaoModelType {
    case lite
    case pro
    
    var modelId: String {
        switch self {
        case .lite:
            return "doubao-1.5-lite-32k-250115"
        case .pro:
            return "doubao-1-5-pro-32k-250115"
        }
    }
}

enum AIConfig {
    // MARK: - API Keys
    
    static let deepSeekAPIKey: String = {
        // In a real app, you would load this from a secure storage or environment variable
        // For development, you can temporarily store it here
        // TODO: Replace with your actual API key
        return "sk-39b8379641874744aada3e70b7f6b9af"
    }()
    
    static let kimiAPIKey: String = {
        // TODO: Replace with your actual KIMI API key
        return "sk-HtWtzmDrD2Dk8yzN3wC3pKuoQD1GN46lmfEP9680LOK3PWBQ"
    }()
    
    static let doubaoAPIKey: String = {
        // TODO: Replace with your actual Doubao API key
        return "8222485c-3d2c-4a6a-8a8a-6e3fa9915316"
    }()
    
    // MARK: - Configuration
    
    static var currentServiceType: AIServiceType = .doubaoPro
    
    static func configure() {
        switch currentServiceType {
        case .deepSeek:
            print("[AIConfig] Using DeepSeek API Key: \(deepSeekAPIKey.prefix(8))... (length: \(deepSeekAPIKey.count))")
            AIServiceManager.shared.configure(with: deepSeekAPIKey, serviceType: .deepSeek)
        case .kimi:
            print("[AIConfig] Using KIMI API Key: \(kimiAPIKey.prefix(8))... (length: \(kimiAPIKey.count))")
            AIServiceManager.shared.configure(with: kimiAPIKey, serviceType: .kimi)
        case .doubaoLite, .doubaoPro:
            print("[AIConfig] Using Doubao API Key: \(doubaoAPIKey.prefix(8))... (length: \(doubaoAPIKey.count))")
            AIServiceManager.shared.configure(with: doubaoAPIKey, serviceType: currentServiceType)
        }
    }
    
    static func switchService(to type: AIServiceType) {
        currentServiceType = type
        configure()
    }
    
    // MARK: - Doubao Configuration
    
    static let doubaoBaseURL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    
    static func getDoubaoModelType(for serviceType: AIServiceType) -> DoubaoModelType {
        switch serviceType {
        case .doubaoLite:
            return .lite
        case .doubaoPro:
            return .pro
        default:
            return .pro // Default to pro if somehow called with wrong service type
        }
    }
} 
