import Foundation

// MARK: - Models

struct ChatMessage: Codable {
    let role: MessageRole
    let content: String
}

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
}

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage
    
    struct Choice: Codable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Service Protocol

protocol AIChatServiceProtocol {
    func sendMessage(_ message: String, context: [ChatMessage]) async throws -> ChatCompletionResponse
    func sendMessage(_ message: String) async throws -> ChatCompletionResponse
}

// MARK: - Service Errors

enum AIChatServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case unauthorized
    case rateLimitExceeded
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .unauthorized:
            return "Unauthorized: Please check your API key"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
} 