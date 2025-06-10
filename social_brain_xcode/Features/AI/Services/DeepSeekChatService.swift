import Foundation

class DeepSeekChatService: AIChatServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1/chat/completions"
    private let model = "deepseek-chat"
    
    init(apiKey: String) {
        self.apiKey = apiKey
        // Debug: Print API key info (do not print full key)
        // print("[DeepSeekChatService] API Key Length: \(apiKey.count)")
        // print("[DeepSeekChatService] API Key (first 8): \(apiKey.prefix(8))")
        // print("[DeepSeekChatService] API Key (last 4): \(apiKey.suffix(4))")
        // print("[DeepSeekChatService] API Key Unicode Scalars: \(apiKey.unicodeScalars.map { $0.value })")
    }
    
    func sendMessage(_ message: String) async throws -> ChatCompletionResponse {
        throw AIChatServiceError.apiError("DeepSeek only supports streaming mode. Use sendStreamingMessage.")
    }
    
    func sendMessage(_ message: String, context: [AIChatMessage]) async throws -> ChatCompletionResponse {
        throw AIChatServiceError.apiError("DeepSeek only supports streaming mode. Use sendStreamingMessage.")
    }
    
    func sendStreamingMessage(_ message: String, context: [AIChatMessage], onChunk: @escaping (String) -> Void) async throws {
        guard let url = URL(string: baseURL) else {
            throw AIChatServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: context,
            stream: true  // Enable streaming
        )
        
        let encoder = JSONEncoder()
        do {
            let encodedBody = try encoder.encode(requestBody)
            request.httpBody = encodedBody
        } catch {
            throw AIChatServiceError.networkError(error)
        }
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIChatServiceError.invalidResponse
            }
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                var buffer = Data()
                var iterator = bytes.makeAsyncIterator()
                var chunkCount = 0
                
                while let byte = try await iterator.next() {
                    buffer.append(byte)
                    
                    // Check if we have a complete line
                    if byte == UInt8(ascii: "\n") {
                        if let line = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !line.isEmpty {
                            // Remove "data: " prefix if present
                            let jsonString = line.hasPrefix("data: ") ? String(line.dropFirst(6)) : line
                            
                            // Skip [DONE] message
                            if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                                buffer.removeAll()
                                continue
                            }
                            
                            // Try to decode the JSON
                            if let jsonData = jsonString.data(using: .utf8) {
                                do {
                                    let decoder = JSONDecoder()
                                    let streamResponse = try decoder.decode(ChatCompletionStreamResponse.self, from: jsonData)
                                    if let content = streamResponse.choices.first?.delta.content {
                                        chunkCount += 1
                                        onChunk(content)
                                    }
                                } catch {
                                    // Silently handle decode errors for individual chunks
                                }
                            }
                        }
                        buffer.removeAll()
                    }
                }
                
            case 401:
                throw AIChatServiceError.unauthorized
            case 429:
                throw AIChatServiceError.rateLimitExceeded
            case 500...599:
                throw AIChatServiceError.serverError(httpResponse.statusCode)
            default:
                // For non-200 responses, collect the error message
                var errorData = Data()
                var iterator = bytes.makeAsyncIterator()
                while let byte = try await iterator.next() {
                    errorData.append(byte)
                }
                
                if let errorMessage = String(data: errorData, encoding: .utf8) {
                    throw AIChatServiceError.apiError(errorMessage)
                } else {
                    throw AIChatServiceError.invalidResponse
                }
            }
        } catch let error as AIChatServiceError {
            throw error
        } catch {
            throw AIChatServiceError.networkError(error)
        }
    }
} 