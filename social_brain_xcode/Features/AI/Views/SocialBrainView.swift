import SwiftUI
import CoreData
import MarkdownUI

struct SocialBrainView: View {
    // Context parameters
    let sourceType: String
    let sourceAction: String
    let sourceId: String
    
    // Context data
    @State private var contextContact: Contact?
    @State private var contextNotes: [Note] = []
    @State private var systemPrompt: String = ""
    
    @State private var inputText = ""
    @State private var messages = [SocialBrainMessage]()
    @State private var suggestedQuestions: [SocialBrainMessage] = []
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var isConversationActive = false
    @State private var scrollToBottomID = UUID()
    @State private var scrollToTopID = "topID"
    @FocusState private var isInputFocused: Bool
    @State private var isLoading = false
    @State private var showLoadingModal = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    @State private var currentStreamingMessage: String = ""
    @State private var isStreaming = false
    
    private let aiServiceManager = AIServiceManager.shared
    
    // System prompt generation
    private func generateSystemPrompt() async throws {
        print("==== Generating system prompt for sourceType: \(sourceType), sourceAction: \(sourceAction) ====")
        var prompt = "system prompt"
        
        switch (sourceType, sourceAction) {
        case ("contact", "general"):
            print("[SocialBrainView] Fetching contact context for ID: \(sourceId)")
            let context = try await CoreDataManager.shared.viewContext
            let contactFetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
            contactFetchRequest.predicate = NSPredicate(format: "contactId == %@", sourceId as CVarArg)
            
            if let contact = try context.fetch(contactFetchRequest).first {
                print("[SocialBrainView] Found contact: \(contact.name ?? "unnamed")")
                contextContact = contact
                
                // Fetch related notes
                let notesFetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
                notesFetchRequest.predicate = NSPredicate(format: "contacts.contacts == %@", contact)
                notesFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
                
                contextNotes = try context.fetch(notesFetchRequest)
                print("[SocialBrainView] Found \(contextNotes.count) related notes")
                
                prompt += "Contact is \(contact.name ?? "failed to load contact name"). "
                
                // Concatenate all notes
                if !contextNotes.isEmpty {
                    print("[SocialBrainView] Concatenating notes content...")
                    let notesContent = contextNotes.compactMap { note -> String? in
                        guard let content = note.content else { return nil }
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        let dateStr = note.createdAt.map { dateFormatter.string(from: $0) } ?? "unknown date"
                        return "[\(dateStr)] \(content)"
                    }.joined(separator: "\n")
                    
                    prompt += "Here are the notes about this contact:\n\(notesContent)\n"
                    print("[SocialBrainView] Successfully concatenated \(contextNotes.count) notes")
                } else {
                    prompt += "No notes found for this contact. "
                }
            } else {
                print("[SocialBrainView] No contact found for ID: \(sourceId)")
                prompt += "contact + general (ID: \(sourceId)). "
                prompt += "Focus on general relationship management, communication strategies, and maintaining healthy connections."
            }

        case ("contact", "insights"):
            prompt += "You are analyzing a specific contact with ID: \(sourceId). "
            prompt += "Focus on providing insights about this contact's relationship with the user, "
            prompt += "suggesting conversation topics, and identifying opportunities for deeper connection."
            
        default:
            prompt += "You are providing general social relationship advice."
        }
        
        print("[SocialBrainView] Generated System Prompt: \(prompt)")
        systemPrompt = prompt
    }
    
    // Initial message based on context
    private func generateInitialMessage() -> String {
        switch (sourceType, sourceAction) {
        case ("contact", "general"):
            if let contact = contextContact {
                return "关于 \(contact.name ?? "这个联系人")，你想问什么"
            }
            return "关于这个联系人，你想问什么"
        case ("contact", "insights"):
            return "Please analyze this contact and provide insights about our relationship."
        default:
            return "How can you help me with my social relationships?"
        }
    }
    
    // Initialize suggested questions based on navigation source
    private func initializeSuggestedQuestions() {
        if sourceType == "contact" && sourceAction == "general" {
            // Single question for contact navigation
            if let contact = contextContact {
                suggestedQuestions = [
                    SocialBrainMessage(
                        content: "关于 \(contact.name ?? "这个联系人")，你想问什么",
                        isFromUser: true,
                        timestamp: Date()
                    )
                ]
            }
        } else {
            // Three questions for direct tab access
            suggestedQuestions = [
                SocialBrainMessage(
                    content: "如何与这个联系人建立更深层次的关系？",
                    isFromUser: true,
                    timestamp: Date()
                ),
                SocialBrainMessage(
                    content: "有什么话题可以增进我们的交流？",
                    isFromUser: true,
                    timestamp: Date()
                ),
                SocialBrainMessage(
                    content: "如何更好地维护这段关系？",
                    isFromUser: true,
                    timestamp: Date()
                )
            ]
        }
    }
    
    var body: some View {
        ZStack {
            Color.primaryBackground
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss keyboard when tapping empty areas
                    isInputFocused = false
                }
            
            VStack(spacing: 0) {
                // Chat area
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Top anchor for scrolling to top
                            Color.clear.frame(height: 1)
                                .id(scrollToTopID)
                            
                            if isConversationActive {
                                // Show conversation
                                ForEach(messages) { message in
                                    if message.isFromUser {
                                        // User message
                                        MessageBubble(
                                            text: message.content,
                                            isFromUser: true
                                        )
                                    } else {
                                        // AI response
                                        AiBubble(
                                            text: message.content,
                                            actionText: message.suggestedAction,
                                            onActionTapped: {
                                                handleActionButtonTapped(actionText: message.suggestedAction ?? "")
                                            }
                                        )
                                    }
                                }
                            } else {
                                // Show suggested questions
                                ForEach(suggestedQuestions) { question in
                                    SuggestedQuestionBubble(text: question.content)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            handleSuggestedQuestion(question.content)
                                        }
                                }
                            }
                            
                            // Spacer at the bottom for input field
                            Spacer().frame(height: 60)
                                .id(scrollToBottomID)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            // Dismiss keyboard when scrolling
                            isInputFocused = false
                        }
                    )
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            scrollProxy.scrollTo(scrollToBottomID, anchor: .bottom)
                        }
                    }
                    .onChange(of: isLoading) { _ in
                        withAnimation {
                            scrollProxy.scrollTo(scrollToBottomID, anchor: .bottom)
                        }
                    }
                    .onChange(of: isConversationActive) { active in
                        if !active {
                            // When returning to default view, scroll to top
                            withAnimation {
                                scrollProxy.scrollTo(scrollToTopID, anchor: .top)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Input area
                VStack(spacing: 0) {
                    if isConversationActive {
                        // New chat button
                        Button(action: startNewConversation) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 18))
                                
                                Text("new_chat".localized)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .foregroundColor(.primary)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                    
                    // Input bar
                    HStack {
                        TextField("hint_text".localized, text: $inputText)
                            .font(.body)
                            .padding(16)
                            .background(Color.inputBackground)
                            .cornerRadius(25)
                            .focused($isInputFocused)
                            .onSubmit {
                                sendMessage()
                            }
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.primaryAction)
                                .clipShape(SwiftUI.Circle())
                                .shadow(color: Color.primaryText.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color.primaryBackground)
            }
            .contentShape(Rectangle()) // Make entire content area tappable
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere in the content
                isInputFocused = false
            }
            
            // Loading modal overlay
            if showLoadingModal {
                LoadingModal()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            print("- sourceType: \(sourceType)")
            print("- sourceAction: \(sourceAction)")
            print("- sourceId: \(sourceId)")
            
            // Initialize suggested questions
            initializeSuggestedQuestions()
            
            // Generate system prompt
            Task {
                do {
                    try await generateSystemPrompt()
                } catch {
                    print("[SocialBrainView] Error generating system prompt: \(error)")
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
        .onChange(of: isLoading) { loading in
            if loading {
                // Show the modal when loading starts
                showLoadingModal = true
            } else {
                // Hide the modal when loading ends
                showLoadingModal = false
            }
        }
    }
    
    private func handleSuggestedQuestion(_ question: String) {
        inputText = question
        sendMessage()
    }
    
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
                
                // Prepare messages with system prompt
                var chatMessages = aiServiceManager.convertToChatMessages(messages)
                chatMessages.insert(AIChatMessage(role: .system, content: systemPrompt), at: 0)
                
                print("[SocialBrainView] Sending request to LLM with messages:")
                for message in chatMessages {
                    print("[SocialBrainView] Role: \(message.role), Content: \(message.content)")
                }
                
                // Check if we should use streaming (only for Doubao)
                if let doubaoService = chatService as? DoubaoChatService {
                    isStreaming = true
                    currentStreamingMessage = ""
                    
                    // Create a temporary message for streaming
                    let streamingMessage = SocialBrainMessage(
                        content: "",
                        isFromUser: false,
                        timestamp: Date()
                    )
                    messages.append(streamingMessage)
                    
                    var isFirstChunk = true
                    try await doubaoService.sendStreamingMessage(trimmedText, context: chatMessages) { chunk in
                        Task { @MainActor in
                            currentStreamingMessage += chunk
                            // Update the last message with the current streaming content
                            if let lastIndex = messages.indices.last {
                                messages[lastIndex].content = currentStreamingMessage
                                
                                // Dismiss loading on first chunk
                                if isFirstChunk {
                                    isLoading = false
                                    isFirstChunk = false
                                }
                            }
                        }
                    }
                    
                    // Streaming completed
                    isStreaming = false
                } else {
                    // Non-streaming response
                    let response = try await chatService.sendMessage(trimmedText, context: chatMessages)
                    
                    print("[SocialBrainView] Received response from LLM:")
                    if let firstChoice = response.choices.first {
                        print("[SocialBrainView] \(firstChoice.message.content)")
                    } else {
                        print("[SocialBrainView] No content in response")
                    }
                    
                    await MainActor.run {
                        let aiMessage = aiServiceManager.convertToSocialBrainMessage(response)
                        messages.append(aiMessage)
                        isLoading = false
                    }
                }
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
    
    private func startNewConversation() {
        withAnimation {
            isConversationActive = false
            messages.removeAll()
            isLoading = false
            inputText = ""
            initializeSuggestedQuestions()
        }
    }
    
    private func handleActionButtonTapped(actionText: String) {
        // Create a new AI response based on the action
        var question = "1234"
        let text = "是的"
        
        if actionText.contains("搜索相关信息") {
            question = "DeFi是 Decentralized Finance 的缩写，指不依赖传统中心化金融机构(如银行)而运行的金融系统。根据你与李明的对话记录，他可能是提到了币安 binance这家公司。你想进一步了解一这个领域吗？"
        } else if actionText.contains("是的") {
            question = "根据你们的互动记录分析，林彤的性格可能是非常关注逻辑理性的类型，你在与她的互动里经常讲述你自己的个人感受，可能让林彤因为不同的沟通风格而产生了抗拒情绪。你希望我把这个观察添加入到针对林彤的关系备忘录里去吗？"
        }
        
        let actionResponse = SocialBrainMessage(
            content: question,
            isFromUser: false,
            timestamp: Date(),
            suggestedAction: text
        )
        
        messages.append(actionResponse)
    }
}

struct LoadingModal: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Semi-transparent background mask
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            // Modal card
            VStack(spacing: 0) {
                // Header with loading message
                VStack(spacing: 0) {
                    Text("正在检索你的笔记。。。")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 20)
                }
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemBackground))
                .cornerRadius(12, corners: [.topLeft, .topRight])
                
                // Quote area with arrows
                ZStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("好的沟通不在于你是否能达成眼前的目标，而在于你能否不断地自我塑造。")
                            .font(.system(size: 16))
                            .foregroundColor(.primaryText)
                            .lineSpacing(5)
                            .padding(.horizontal, 40) // Increased horizontal padding for arrows
                            .padding(.top, 24)
                            .padding(.bottom, 20)
                            .multilineTextAlignment(.leading)
                        
                        // Source attribution with line
                        VStack(spacing: 8) {
                            Divider()
                                .padding(.horizontal, 40)
                            
                            Text("————《沟通的方法》")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.bottom, 20)
                        }
                    }
                    
                    // Side arrows
                    HStack {
                        // Left arrow button
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        
                        Spacer()
                        
                        // Right arrow button
                        Button(action: {}) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemBackground))
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            }
            .frame(width: UIScreen.main.bounds.width * 0.85)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .transition(.opacity)
    }
}

// Helper for rounded corners on specific sides
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct MessageBubble: View {
    let text: String
    let isFromUser: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Markdown(text)
                .font(.system(size: 17))
                .foregroundColor(.primaryText)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.inputBackground, Color.secondaryBackground]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color.primaryText.opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .padding(.horizontal, 0)
        .opacity(0.95)
    }
}

struct SuggestedQuestionBubble: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.body)
                .foregroundColor(.primaryText)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.inputBackground, Color.secondaryBackground]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color.primaryText.opacity(0.05), radius: 1, x: 0, y: 1)
                .overlay(
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondaryText)
                            .padding(.trailing, 12)
                    }
                )
        }
        .padding(.horizontal, 0)
    }
}

struct AiBubble: View {
    let text: String
    let actionText: String?
    var onActionTapped: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Message text
                Markdown(text)
                    .font(.system(size: 17))
                    .foregroundColor(.primaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Action button
                if let actionText = actionText {
                    // Divider with proper padding
                    Divider()
                        .padding(.horizontal, 16)
                    
                    HStack {
                        Button(action: {
                            // Action button tap
                            onActionTapped?()
                        }) {
                            Text(actionText)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .foregroundColor(.white)
                                .background(Color(.systemBlue).opacity(0.8))
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 16)
                        
                        Spacer()
                    }
                    .padding(.leading, 16)
                }
            }
            .background(Color.primaryBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        colorScheme == .light ? Color(.systemGray4) : Color(.systemGray3),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.15),
                radius: 2,
                x: 0,
                y: 1
            )
        }
        .padding(.horizontal, 0)
    }
}

struct SocialBrainView_Previews: PreviewProvider {
    static var previews: some View {
        SocialBrainView(
            sourceType: "contact",
            sourceAction: "insights",
            sourceId: "preview-id"
        )
        .environment(\.colorScheme, .light)
        .environmentObject(LocalizationManager())
        
        SocialBrainView(
            sourceType: "contact",
            sourceAction: "insights",
            sourceId: "preview-id"
        )
        .environment(\.colorScheme, .dark)
        .environmentObject(LocalizationManager())
    }
}
