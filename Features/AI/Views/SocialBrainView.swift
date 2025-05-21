// Prepare messages with system prompt
print("[SocialBrainView] 🔄 Starting message preparation")
var chatMessages = aiServiceManager.convertToChatMessages(messages)
chatMessages.insert(AIChatMessage(role: .system, content: systemPrompt), at: 0)

print("[SocialBrainView] Sending request to LLM with messages:")
for message in chatMessages {
    print("[SocialBrainView] Role: \(message.role), Content: \(message.content)")
}

guard let chatService = aiServiceManager.getChatService() else {
    print("[SocialBrainView] ❌ No chat service available")
    throw AIChatServiceError.unauthorized
}

print("[SocialBrainView] ✅ Chat service available: \(type(of: chatService))")

// Use streaming for all services
print("[SocialBrainView] 🚀 Enabling streaming mode")
isStreaming = true
currentStreamingMessage = ""

// Create a temporary message for streaming
print("[SocialBrainView] 📝 Creating streaming message placeholder")
let streamingMessage = SocialBrainMessage(
    content: "",
    isFromUser: false,
    timestamp: Date()
)
messages.append(streamingMessage)

var isFirstChunk = true
print("[SocialBrainView] 📡 Starting streaming request")
try await chatService.sendStreamingMessage(trimmedText, context: chatMessages) { chunk in
    Task { @MainActor in
        print("[SocialBrainView] 📥 Received chunk: \(chunk.prefix(50))...")
        currentStreamingMessage += chunk
        // Update the last message with the current streaming content
        if let lastIndex = messages.indices.last {
            messages[lastIndex].content = currentStreamingMessage
            
            // Dismiss loading on first chunk
            if isFirstChunk {
                print("[SocialBrainView] ✅ First chunk received, dismissing loading state")
                isLoading = false
                isFirstChunk = false
            }
        }
    }
}

// Streaming completed
print("[SocialBrainView] ✅ Streaming completed")
isStreaming = false
isLoading = false

// Remove the duplicate task and streaming implementation

private func sendMessage() {
    let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else { return }
    
    // If not in conversation mode, switch to it
    if !isConversationActive {
        isConversationActive = true
    }
    
    // Add user message
    let userMessage = SocialBrainMessage(
        content: trimmedText,
        isFromUser: true,
        timestamp: Date()
    )
    messages.append(userMessage)
    
    // Clear input
    inputText = ""
    
    // Show loading state
    isLoading = true
    
    Task {
        do {
            guard let chatService = aiServiceManager.getChatService() else {
                throw AIChatServiceError.unauthorized
            }
            
            // Regenerate system prompt with the new question
            if let sampleProvider = getSampleProvider() {
                let context = PromptContext(
                    mode: SampleMode(rawValue: appModeManager.sampleModeType ?? "") ?? .none,
                    question: trimmedText,  // Use the actual question
                    contact: contextContact
                )
                systemPrompt = try await sampleProvider.generateSystemPromptWithNotes(for: context)
            }
            
            // Prepare messages with system prompt
            var chatMessages = aiServiceManager.convertToChatMessages(messages)
            chatMessages.insert(AIChatMessage(role: .system, content: systemPrompt), at: 0)
            
            print("[SocialBrainView] Sending request to LLM with messages:")
            for message in chatMessages {
                print("[SocialBrainView] Role: \(message.role), Content: \(message.content)")
            }
            
            // Use streaming for all services
            print("[SocialBrainView] 🚀 Enabling streaming mode")
            isStreaming = true
            currentStreamingMessage = ""
            
            // Create a temporary message for streaming
            print("[SocialBrainView] 📝 Creating streaming message placeholder")
            let streamingMessage = SocialBrainMessage(
                content: "",
                isFromUser: false,
                timestamp: Date()
            )
            messages.append(streamingMessage)
            
            var isFirstChunk = true
            print("[SocialBrainView] 📡 Starting streaming request")
            try await chatService.sendStreamingMessage(trimmedText, context: chatMessages) { chunk in
                Task { @MainActor in
                    print("[SocialBrainView] 📥 Received chunk: \(chunk.prefix(50))...")
                    currentStreamingMessage += chunk
                    // Update the last message with the current streaming content
                    if let lastIndex = messages.indices.last {
                        messages[lastIndex].content = currentStreamingMessage
                        
                        // Dismiss loading on first chunk
                        if isFirstChunk {
                            print("[SocialBrainView] ✅ First chunk received, dismissing loading state")
                            isLoading = false
                            isFirstChunk = false
                        }
                    }
                }
            }
            
            // Streaming completed
            print("[SocialBrainView] ✅ Streaming completed")
            isStreaming = false
            isLoading = false
            
        } catch {
            await MainActor.run {
                isLoading = false
                isStreaming = false
                print("[SocialBrainView] Error caught: \(error) (\(type(of: error)))")
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                showError = true
            }
        }
    }
} 