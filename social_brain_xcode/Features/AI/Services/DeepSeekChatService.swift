import Foundation

class DeepSeekChatService: AIChatServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1/chat/completions"
    private let model = "deepseek-chat"
    
    init(apiKey: String) {
        self.apiKey = apiKey
        // Debug: Print API key info (do not print full key)
        print("[DeepSeekChatService] API Key Length: \(apiKey.count)")
        print("[DeepSeekChatService] API Key (first 8): \(apiKey.prefix(8))")
        print("[DeepSeekChatService] API Key (last 4): \(apiKey.suffix(4))")
        print("[DeepSeekChatService] API Key Unicode Scalars: \(apiKey.unicodeScalars.map { $0.value })")
    }
    
    func sendMessage(_ message: String) async throws -> ChatCompletionResponse {
        let messages = [
            ChatMessage(role: .system, content: "You are a helpful assistant."),
            ChatMessage(role: .user, content: message)
        ]
        return try await sendMessage(message, context: messages)
    }
    
    func sendMessage(_ message: String, context: [ChatMessage]) async throws -> ChatCompletionResponse {
        guard let url = URL(string: baseURL) else {
            print("[DeepSeekChatService] Invalid URL: \(baseURL)")
            throw AIChatServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: context,
            stream: false
        )
        
        let encoder = JSONEncoder()
        do {
            let encodedBody = try encoder.encode(requestBody)
            request.httpBody = encodedBody
            if let jsonString = String(data: encodedBody, encoding: .utf8) {
                print("[DeepSeekChatService] Request Body: \(jsonString)")
            }
        } catch {
            print("[DeepSeekChatService] Failed to encode request body: \(error)")
            throw AIChatServiceError.networkError(error)
        }
        
        do {
            print("[DeepSeekChatService] Sending request to: \(url)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[DeepSeekChatService] HTTP Status: \(httpResponse.statusCode)")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("[DeepSeekChatService] Response Body: \(responseString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[DeepSeekChatService] Invalid HTTP response")
                throw AIChatServiceError.invalidResponse
            }
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                do {
                    let decoded = try decoder.decode(ChatCompletionResponse.self, from: data)
                    print("[DeepSeekChatService] Decoded response successfully.")
                    return decoded
                } catch {
                    print("[DeepSeekChatService] Decoding error: \(error)")
                    throw AIChatServiceError.decodingError(error)
                }
            case 401:
                print("[DeepSeekChatService] Unauthorized (401)")
                throw AIChatServiceError.unauthorized
            case 429:
                print("[DeepSeekChatService] Rate limit exceeded (429)")
                throw AIChatServiceError.rateLimitExceeded
            case 500...599:
                print("[DeepSeekChatService] Server error (\(httpResponse.statusCode))")
                throw AIChatServiceError.serverError(httpResponse.statusCode)
            default:
                if let errorMessage = String(data: data, encoding: .utf8) {
                    print("[DeepSeekChatService] API error: \(errorMessage)")
                    throw AIChatServiceError.apiError(errorMessage)
                } else {
                    print("[DeepSeekChatService] Unknown error, status: \(httpResponse.statusCode)")
                    throw AIChatServiceError.invalidResponse
                }
            }
        } catch let error as AIChatServiceError {
            print("[DeepSeekChatService] AIChatServiceError: \(error)")
            throw error
        } catch {
            print("[DeepSeekChatService] Network error: \(error)")
            throw AIChatServiceError.networkError(error)
        }
    }
} 