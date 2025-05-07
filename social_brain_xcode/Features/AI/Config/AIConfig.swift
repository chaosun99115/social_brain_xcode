import Foundation  

enum AIConfig {
    // MARK: - API Keys
    
    static let deepSeekAPIKey: String = {
        // In a real app, you would load this from a secure storage or environment variable
        // For development, you can temporarily store it here
        // TODO: Replace with your actual API key
        return "sk-39b8379641874744aada3e70b7f6b9af"
    }()
    
    // MARK: - Configuration
    
    static func configure() {
        AIServiceManager.shared.configure(with: deepSeekAPIKey)
    }
} 
