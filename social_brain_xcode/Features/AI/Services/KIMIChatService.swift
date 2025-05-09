import Foundation

class KIMIChatService: AIChatServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.moonshot.cn/v1/chat/completions"
    private let model = "moonshot-v1-8k"
    
    init(apiKey: String) {
        self.apiKey = apiKey
        // Debug: Print API key info (do not print full key)
        print("[KIMIChatService] API Key Length: \(apiKey.count)")
        print("[KIMIChatService] API Key (first 8): \(apiKey.prefix(8))")
        print("[KIMIChatService] API Key (last 4): \(apiKey.suffix(4))")
    }
    
    func sendMessage(_ message: String) async throws -> ChatCompletionResponse {
        let messages = [
            AIChatMessage(role: .system, content: "你是 Kimi，由 Moonshot AI 提供的人工智能助手，你更擅长中文和英文的对话。你会为用户提供安全，有帮助，准确的回答。同时，你会拒绝一切涉及恐怖主义，种族歧视，黄色暴力等问题的回答。Moonshot AI 为专有名词，不可翻译成其他语言。"),
            AIChatMessage(role: .user, content: message)
        ]
        return try await sendMessage(message, context: messages)
    }
    
    func sendMessage(_ message: String, context: [AIChatMessage]) async throws -> ChatCompletionResponse {
        guard let url = URL(string: baseURL) else {
            print("[KIMIChatService] Invalid URL: \(baseURL)")
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
                print("[KIMIChatService] Request Body: \(jsonString)")
            }
        } catch {
            print("[KIMIChatService] Failed to encode request body: \(error)")
            throw AIChatServiceError.networkError(error)
        }
        
        do {
            print("[KIMIChatService] Sending request to: \(url)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[KIMIChatService] HTTP Status: \(httpResponse.statusCode)")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("[KIMIChatService] Response Body: \(responseString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[KIMIChatService] Invalid HTTP response")
                throw AIChatServiceError.invalidResponse
            }
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                do {
                    let decoded = try decoder.decode(ChatCompletionResponse.self, from: data)
                    print("[KIMIChatService] Decoded response successfully.")
                    return decoded
                } catch {
                    print("[KIMIChatService] Decoding error: \(error)")
                    throw AIChatServiceError.decodingError(error)
                }
            case 401:
                print("[KIMIChatService] Unauthorized (401)")
                throw AIChatServiceError.unauthorized
            case 429:
                print("[KIMIChatService] Rate limit exceeded (429)")
                throw AIChatServiceError.rateLimitExceeded
            case 500...599:
                print("[KIMIChatService] Server error (\(httpResponse.statusCode))")
                throw AIChatServiceError.serverError(httpResponse.statusCode)
            default:
                if let errorMessage = String(data: data, encoding: .utf8) {
                    print("[KIMIChatService] API error: \(errorMessage)")
                    throw AIChatServiceError.apiError(errorMessage)
                } else {
                    print("[KIMIChatService] Unknown error, status: \(httpResponse.statusCode)")
                    throw AIChatServiceError.invalidResponse
                }
            }
        } catch let error as AIChatServiceError {
            print("[KIMIChatService] AIChatServiceError: \(error)")
            throw error
        } catch {
            print("[KIMIChatService] Network error: \(error)")
            throw AIChatServiceError.networkError(error)
        }
    }
    
    func sendStreamingMessage(_ message: String, context: [AIChatMessage], onChunk: @escaping (String) -> Void) async throws {
        // KIMI doesn't support streaming, so we'll use the regular response
        let response = try await sendMessage(message, context: context)
        if let content = response.choices.first?.message.content {
            onChunk(content)
        }
    }
} 