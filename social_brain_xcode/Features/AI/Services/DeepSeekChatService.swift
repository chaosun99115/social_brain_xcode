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
        throw AIChatServiceError.apiError("DeepSeek only supports streaming mode. Use sendStreamingMessage.")
    }
    
    func sendMessage(_ message: String, context: [AIChatMessage]) async throws -> ChatCompletionResponse {
        throw AIChatServiceError.apiError("DeepSeek only supports streaming mode. Use sendStreamingMessage.")
    }
    
    func sendStreamingMessage(_ message: String, context: [AIChatMessage], onChunk: @escaping (String) -> Void) async throws {
        print("[DeepSeekChatService] Starting streaming message request")
        print("[DeepSeekChatService] Message: \(message)")
        print("[DeepSeekChatService] Context messages count: \(context.count)")
        
        guard let url = URL(string: baseURL) else {
            print("[DeepSeekChatService] ❌ Invalid URL: \(baseURL)")
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
        
        print("[DeepSeekChatService] Request configuration:")
        print("- Model: \(model)")
        print("- Stream: true")
        print("- Messages count: \(context.count)")
        
        let encoder = JSONEncoder()
        do {
            let encodedBody = try encoder.encode(requestBody)
            request.httpBody = encodedBody
            if let jsonString = String(data: encodedBody, encoding: .utf8) {
                print("[DeepSeekChatService] Request Body: \(jsonString)")
            }
        } catch {
            print("[DeepSeekChatService] ❌ Failed to encode request body: \(error)")
            throw AIChatServiceError.networkError(error)
        }
        
        do {
            print("[DeepSeekChatService] 🚀 Sending streaming request to: \(url)")
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[DeepSeekChatService] ❌ Invalid HTTP response")
                throw AIChatServiceError.invalidResponse
            }
            
            print("[DeepSeekChatService] Received HTTP response: \(httpResponse.statusCode)")
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                print("[DeepSeekChatService] ✅ Successfully connected to streaming endpoint")
                var buffer = Data()
                var iterator = bytes.makeAsyncIterator()
                var chunkCount = 0
                
                while let byte = try await iterator.next() {
                    buffer.append(byte)
                    
                    // Check if we have a complete line
                    if byte == UInt8(ascii: "\n") {
                        if let line = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !line.isEmpty {
                            print("[DeepSeekChatService] Received chunk: \(line.prefix(100))...")
                            
                            // Remove "data: " prefix if present
                            let jsonString = line.hasPrefix("data: ") ? String(line.dropFirst(6)) : line
                            
                            // Skip [DONE] message
                            if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                                print("[DeepSeekChatService] Received [DONE] signal")
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
                                        print("[DeepSeekChatService] Processing chunk \(chunkCount): \(content.prefix(50))...")
                                        onChunk(content)
                                    } else {
                                        print("[DeepSeekChatService] Empty content in chunk")
                                    }
                                } catch {
                                    print("[DeepSeekChatService] ❌ Failed to decode streaming response: \(error)")
                                    print("[DeepSeekChatService] Raw JSON: \(jsonString)")
                                }
                            }
                        }
                        buffer.removeAll()
                    }
                }
                
                print("[DeepSeekChatService] ✅ Streaming completed. Total chunks processed: \(chunkCount)")
                
            case 401:
                print("[DeepSeekChatService] ❌ Unauthorized (401)")
                throw AIChatServiceError.unauthorized
            case 429:
                print("[DeepSeekChatService] ❌ Rate limit exceeded (429)")
                throw AIChatServiceError.rateLimitExceeded
            case 500...599:
                print("[DeepSeekChatService] ❌ Server error (\(httpResponse.statusCode))")
                throw AIChatServiceError.serverError(httpResponse.statusCode)
            default:
                print("[DeepSeekChatService] ❌ Unexpected status code: \(httpResponse.statusCode)")
                // For non-200 responses, collect the error message
                var errorData = Data()
                var iterator = bytes.makeAsyncIterator()
                while let byte = try await iterator.next() {
                    errorData.append(byte)
                }
                
                if let errorMessage = String(data: errorData, encoding: .utf8) {
                    print("[DeepSeekChatService] API error: \(errorMessage)")
                    throw AIChatServiceError.apiError(errorMessage)
                } else {
                    print("[DeepSeekChatService] Unknown error, status: \(httpResponse.statusCode)")
                    throw AIChatServiceError.invalidResponse
                }
            }
        } catch let error as AIChatServiceError {
            print("[DeepSeekChatService] ❌ AIChatServiceError: \(error)")
            throw error
        } catch {
            print("[DeepSeekChatService] ❌ Network error: \(error)")
            throw AIChatServiceError.networkError(error)
        }
    }
} 