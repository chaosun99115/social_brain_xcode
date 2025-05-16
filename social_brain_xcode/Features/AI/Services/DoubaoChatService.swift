import Foundation

class DoubaoChatService: AIChatServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    private let modelType: DoubaoModelType
    
    init(apiKey: String, modelType: DoubaoModelType) {
        self.apiKey = apiKey
        self.modelType = modelType
        // Debug: Print API key info (do not print full key)
        print("[DoubaoChatService] API Key Length: \(apiKey.count)")
        print("[DoubaoChatService] API Key (first 8): \(apiKey.prefix(8))")
        print("[DoubaoChatService] API Key (last 4): \(apiKey.suffix(4))")
        print("[DoubaoChatService] Model Type: \(modelType.modelId)")
    }
    
    func sendMessage(_ message: String) async throws -> ChatCompletionResponse {
        let messages = [
            AIChatMessage(role: .system, content: "You are a helpful assistant."),
            AIChatMessage(role: .user, content: message)
        ]
        return try await sendMessage(message, context: messages)
    }
    
    func sendMessage(_ message: String, context: [AIChatMessage]) async throws -> ChatCompletionResponse {
        guard let url = URL(string: baseURL) else {
            print("[DoubaoChatService] Invalid URL: \(baseURL)")
            throw AIChatServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ChatCompletionRequest(
            model: modelType.modelId,
            messages: context,
            stream: false
        )
        
        let encoder = JSONEncoder()
        do {
            let encodedBody = try encoder.encode(requestBody)
            request.httpBody = encodedBody
            if let jsonString = String(data: encodedBody, encoding: .utf8) {
                print("[DoubaoChatService] Request Body: \(jsonString)")
            }
        } catch {
            print("[DoubaoChatService] Failed to encode request body: \(error)")
            throw AIChatServiceError.networkError(error)
        }
        
        do {
            print("[DoubaoChatService] Sending request to: \(url)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[DoubaoChatService] HTTP Status: \(httpResponse.statusCode)")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("[DoubaoChatService] Response Body: \(responseString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[DoubaoChatService] Invalid HTTP response")
                throw AIChatServiceError.invalidResponse
            }
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                do {
                    let decoded = try decoder.decode(ChatCompletionResponse.self, from: data)
                    print("[DoubaoChatService] Decoded response successfully.")
                    return decoded
                } catch {
                    print("[DoubaoChatService] Decoding error: \(error)")
                    throw AIChatServiceError.decodingError(error)
                }
            case 401:
                print("[DoubaoChatService] Unauthorized (401)")
                throw AIChatServiceError.unauthorized
            case 429:
                print("[DoubaoChatService] Rate limit exceeded (429)")
                throw AIChatServiceError.rateLimitExceeded
            case 500...599:
                print("[DoubaoChatService] Server error (\(httpResponse.statusCode))")
                if let errorMessage = String(data: data, encoding: .utf8) {
                    print("[DoubaoChatService] API error: \(errorMessage)")
                    throw AIChatServiceError.apiError(errorMessage)
                } else {
                    print("[DoubaoChatService] Unknown error, status: \(httpResponse.statusCode)")
                    throw AIChatServiceError.serverError(httpResponse.statusCode)
                }
            default:
                print("[DoubaoChatService] Unexpected status code: \(httpResponse.statusCode)")
                if let errorMessage = String(data: data, encoding: .utf8) {
                    print("[DoubaoChatService] API error: \(errorMessage)")
                    throw AIChatServiceError.apiError(errorMessage)
                } else {
                    throw AIChatServiceError.invalidResponse
                }
            }
        } catch let error as AIChatServiceError {
            print("[DoubaoChatService] AIChatServiceError: \(error)")
            throw error
        } catch {
            print("[DoubaoChatService] Network error: \(error)")
            throw AIChatServiceError.networkError(error)
        }
    }
    
    func sendStreamingMessage(_ message: String, context: [AIChatMessage], onChunk: @escaping (String) -> Void) async throws {
        guard let url = URL(string: baseURL) else {
            print("[DoubaoChatService] Invalid URL: \(baseURL)")
            throw AIChatServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ChatCompletionRequest(
            model: modelType.modelId,
            messages: context,
            stream: true
        )
        
        let encoder = JSONEncoder()
        do {
            let encodedBody = try encoder.encode(requestBody)
            request.httpBody = encodedBody
            if let jsonString = String(data: encodedBody, encoding: .utf8) {
                print("[DoubaoChatService] Request Body: \(jsonString)")
            }
        } catch {
            print("[DoubaoChatService] Failed to encode request body: \(error)")
            throw AIChatServiceError.networkError(error)
        }
        
        do {
            print("[DoubaoChatService] Sending streaming request to: \(url)")
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[DoubaoChatService] Invalid HTTP response")
                throw AIChatServiceError.invalidResponse
            }
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                var buffer = Data()
                var iterator = bytes.makeAsyncIterator()
                
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
                                        onChunk(content)
                                    }
                                } catch {
                                    print("[DoubaoChatService] Failed to decode streaming response: \(error)")
                                }
                            }
                        }
                        buffer.removeAll()
                    }
                }
                
                // Process any remaining data
                if !buffer.isEmpty,
                   let line = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !line.isEmpty {
                    let jsonString = line.hasPrefix("data: ") ? String(line.dropFirst(6)) : line
                    if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) != "[DONE]",
                       let jsonData = jsonString.data(using: .utf8) {
                        do {
                            let decoder = JSONDecoder()
                            let streamResponse = try decoder.decode(ChatCompletionStreamResponse.self, from: jsonData)
                            if let content = streamResponse.choices.first?.delta.content {
                                onChunk(content)
                            }
                        } catch {
                            print("[DoubaoChatService] Failed to decode final streaming response: \(error)")
                        }
                    }
                }
                
            case 401:
                print("[DoubaoChatService] Unauthorized (401)")
                throw AIChatServiceError.unauthorized
            case 429:
                print("[DoubaoChatService] Rate limit exceeded (429)")
                throw AIChatServiceError.rateLimitExceeded
            case 500...599:
                print("[DoubaoChatService] Server error (\(httpResponse.statusCode))")
                throw AIChatServiceError.serverError(httpResponse.statusCode)
            default:
                // For non-200 responses, collect the error message
                var errorData = Data()
                var iterator = bytes.makeAsyncIterator()
                while let byte = try await iterator.next() {
                    errorData.append(byte)
                }
                
                if let errorMessage = String(data: errorData, encoding: .utf8) {
                    print("[DoubaoChatService] API error: \(errorMessage)")
                    throw AIChatServiceError.apiError(errorMessage)
                } else {
                    print("[DoubaoChatService] Unknown error, status: \(httpResponse.statusCode)")
                    throw AIChatServiceError.invalidResponse
                }
            }
        } catch let error as AIChatServiceError {
            print("[DoubaoChatService] AIChatServiceError: \(error)")
            throw error
        } catch {
            print("[DoubaoChatService] Network error: \(error)")
            throw AIChatServiceError.networkError(error)
        }
    }
} 