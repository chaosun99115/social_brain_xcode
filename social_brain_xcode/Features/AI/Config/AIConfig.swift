import Foundation  

enum AIServiceType {
    case deepSeek
    case kimi
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
    
    // MARK: - Configuration
    
    static var currentServiceType: AIServiceType = .kimi
    
    static func configure() {
        switch currentServiceType {
        case .deepSeek:
            AIServiceManager.shared.configure(with: deepSeekAPIKey, serviceType: .deepSeek)
        case .kimi:
            AIServiceManager.shared.configure(with: kimiAPIKey, serviceType: .kimi)
        }
    }
    
    static func switchService(to type: AIServiceType) {
        currentServiceType = type
        configure()
    }
} 
