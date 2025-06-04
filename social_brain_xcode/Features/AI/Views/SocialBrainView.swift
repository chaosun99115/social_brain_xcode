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
    @State private var showingConfigurationSheet = false
    
    @State private var inputText = ""
    @State private var messages = [SocialBrainMessage]()
    @State private var suggestedQuestions: [SocialBrainMessage] = []
    @State private var isConversationActive = false
    @State private var scrollToBottomID = UUID()
    @State private var scrollToTopID = "topID"
    @FocusState private var isInputFocused: Bool
    @State private var isLoading = false
    @State private var showLoadingModal = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showingNoteModal = false
    
    // Add keyboard handling state
    @State private var keyboardHeight: CGFloat = 0
    @State private var isKeyboardVisible = false
    
    @State private var currentStreamingMessage: String = ""
    @State private var isStreaming = false
    
    private let aiServiceManager = AIServiceManager.shared
    @EnvironmentObject var appModeManager: AppModeManager
    
    @State private var textEditorHeight: CGFloat = 56
    let maxTextEditorHeight: CGFloat = 120
    
    // Add this computed property to get the safe area bottom inset
    private var safeAreaBottomInset: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
    
    // Add new state for input accessory view
    @State private var inputAccessoryHeight: CGFloat = 0
    
    // Add helper method to get provider
    private func getSampleProvider() -> SampleModeProvider? {
        guard appModeManager.isSampleMode,
              let modeType = appModeManager.sampleModeType else { return nil }
        return SampleModeProviderFactory.getProvider(for: modeType)
    }
    
    // System prompt generation
    private func generateSystemPrompt() async throws {
        // First check if we're in sample mode
        if let sampleProvider = getSampleProvider() {
            // Use the new prompt generation system with notes
            let context = PromptContext(
                mode: SampleMode(rawValue: appModeManager.sampleModeType ?? "") ?? .none,
                question: "",  // Initial prompt doesn't have a specific question
                contact: contextContact
            )
            systemPrompt = try await sampleProvider.generateSystemPromptWithNotes(for: context)
            return
        }
        
        // Use existing logic for non-sample mode
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
                
                // Update suggested questions using the provider
                await MainActor.run {
                    initializeSuggestedQuestions()
                }
                
                prompt += "Contact is \(contact.name ?? "failed to load contact name"). "
                
                // Use the new note fetching functionality
                if let sampleProvider = getSampleProvider() {
                    let context = PromptContext(
                        mode: .none,
                        question: "",
                        contact: contact
                    )
                    let notesContext = try await sampleProvider.fetchRelevantNotes(for: context)
                    if !notesContext.isEmpty {
                        prompt += notesContext
                    }
                }
            } else {
                print("[SocialBrainView] No contact found for ID: \(sourceId)")
                prompt += "contact + general (ID: \(sourceId)). "
                prompt += "Focus on general relationship management, communication strategies, and maintaining healthy connections."
            }
            
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
    
    // Modify initializeSuggestedQuestions
    private func initializeSuggestedQuestions() {
        print("[SocialBrainView] Initializing suggested questions...")
        if let sampleProvider = getSampleProvider() {
            print("[SocialBrainView] Sample provider found: \(type(of: sampleProvider))")
            print("[SocialBrainView] Using general sample mode questions for mode: \(appModeManager.sampleModeType ?? "nil")")
            let questions = sampleProvider.suggestedQuestions
            print("[SocialBrainView] General sample mode questions: \(questions.map { $0.content })")
            suggestedQuestions = questions
        } else {
            print("[SocialBrainView] Using context-aware questions")
            print("[SocialBrainView] Calling forContext with:")
            print("- sourceType: \(sourceType)")
            print("- sourceAction: \(sourceAction)")
            print("- contact: \(contextContact?.name ?? "nil")")
            
            let questions = SuggestedQuestionsProvider.forContext(
                sourceType: sourceType,
                sourceAction: sourceAction,
                contact: contextContact
            )
            print("[SocialBrainView] Received questions: \(questions.map { $0.content })")
            suggestedQuestions = questions
        }
    }
    
    // Improve the extraction function to be more robust
    private func extractUserQuestion(from text: String) -> String {
        // Check if the text contains any of the possible note markers
        let noteMarkers = ["相关笔记如下:", "笔记如下", "Notes:"]
        
        for marker in noteMarkers {
            if let range = text.range(of: marker) {
                // Return only the part before the marker
                let questionPart = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                // If the extracted part is empty, return a default message
                return questionPart.isEmpty ? "请分析这些笔记" : questionPart
            }
        }
        return text
    }
    
    // Extract notes from text
    private func extractNotes(from text: String) -> String? {
        let noteMarkers = ["相关笔记如下:", "笔记如下", "Notes:"]
        
        for marker in noteMarkers {
            if let range = text.range(of: marker) {
                // Return the part after the marker
                return String(text[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Chat area
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                // Top anchor for scrolling to top
                                Color.clear.frame(height: 1).id(scrollToTopID)
                                
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
                                
                                // Add extra padding at the bottom to ensure last message is visible
                                Spacer()
                                    .frame(height: 120) // Fixed height spacer to ensure content is visible above input
                                    .id(scrollToBottomID)
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 16) // Add bottom padding to the content
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
                            if (!active) {
                                // When returning to default view, scroll to top
                                withAnimation {
                                    scrollProxy.scrollTo(scrollToTopID, anchor: .top)
                                }
                            }
                            // Always reset input field height for consistency
                            textEditorHeight = 56
                        }
                    }
                }
                // Tap-capturing layer above chat area but below input bar
                if isKeyboardVisible {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isInputFocused = false
                        }
                        .ignoresSafeArea(edges: .all)
                }
                // Input area (always at the bottom)
                VStack(spacing: 0) {
                    if isConversationActive {
                        // New chat button and New note button in HStack
                        HStack(spacing: 12) {
                            Button(action: startNewConversation) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 18))
                                    
                                    Text("新对话")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .foregroundColor(.primary)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            Button(action: { showingNoteModal = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.pencil")
                                        .font(.system(size: 18))
                                    
                                    Text("新建笔记")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .foregroundColor(.primary)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
                    // Input bar
                    HStack {
                        ZStack(alignment: .topLeading) {
                            GrowingTextView(text: $inputText, height: $textEditorHeight, maxHeight: maxTextEditorHeight)
                                .frame(height: textEditorHeight)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .focused($isInputFocused)
                            if inputText.isEmpty {
                                Text("输入您的问题...")
                                    .foregroundColor(.gray)
                                    .padding(.top, 12)
                                    .padding(.leading, 16)
                            }
                        }
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.primaryAction)
                                .clipShape(SwiftUI.Circle())
                                .shadow(color: Color.primaryText.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .padding(.bottom, isKeyboardVisible ? inputAccessoryHeight + 12 : 12)
                    .animation(.easeInOut(duration: 0.25), value: isKeyboardVisible)
                }
                .background(Color.primaryBackground)
                // Loading modal overlay
                if showLoadingModal {
                    LoadingModal()
                }
            }
            .navigationTitle("社交大脑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if appModeManager.isSampleMode {
                        Button(action: {
                            appModeManager.isSampleMode = false
                            appModeManager.sampleModeType = nil
                            // Reset conversation state
                            isConversationActive = false
                            messages.removeAll()
                            inputText = ""
                            initializeSuggestedQuestions()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: SampleModeConfig.UIConstants.exitButtonIcon)
                                Text(SampleModeConfig.UIConstants.exitButtonTitle)
                                    .fontWeight(.bold)
                            }
                            .font(.footnote)
                            .foregroundColor(.blue)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingConfigurationSheet = true
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
            
            // Setup keyboard observers for keyboard dismissal
            setupKeyboardObservers()
        }
        .onDisappear {
            // Cleanup keyboard observers
            cleanupKeyboardObservers()
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
        .sheet(isPresented: $showingConfigurationSheet) {
            ConfigurationSheetView()
        }
        .sheet(isPresented: $showingNoteModal) {
            SimpleNoteModalView(initialText: "") { newNoteText in
                // Handle the new note creation
                print("[SocialBrainView] New note created: \(newNoteText)")
            }
            .environmentObject(NoteManager.shared)
            .environmentObject(appModeManager)
        }
    }
    
    private func handleSuggestedQuestion(_ question: String) {
        inputText = question
        sendMessage()
    }
    
    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        let limitedText = String(trimmedText.prefix(1000)) // Limit length here
        
        // Extract just the question part without notes
        let userQuestion = extractUserQuestion(from: limitedText)
        // Extract notes if present
        let extractedNotes = extractNotes(from: limitedText)
        
        // If not in conversation mode, switch to it
        if !isConversationActive {
            isConversationActive = true
        }
        
        // Add user message with only the question part
        let userMessage = SocialBrainMessage(
            content: userQuestion, // Use the extracted question only
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
                
                // Regenerate system prompt with the new question and notes
                if let sampleProvider = getSampleProvider() {
                    // For sample mode - modify the question to include notes if present
                    var contextQuestion = userQuestion
                    if let notes = extractedNotes {
                        // If the question is empty or a default, just use the notes
                        if userQuestion == "请分析这些笔记" {
                            contextQuestion = notes
                        } else {
                            // Otherwise append the notes to the question
                            contextQuestion = userQuestion + "\n\n相关笔记如下:\n" + notes
                        }
                    }
                    
                    let context = PromptContext(
                        mode: SampleMode(rawValue: appModeManager.sampleModeType ?? "") ?? .none,
                        question: contextQuestion,  // Include the notes in the question
                        contact: contextContact
                    )
                    systemPrompt = try await sampleProvider.generateSystemPromptWithNotes(for: context)
                } else {
                    // For non-sample mode, update system prompt if notes are present
                    if let notes = extractedNotes {
                        // Update systemPrompt to include notes but not duplicate them
                        try await updateSystemPromptWithNotes(notes)
                    }
                }
                
                // Prepare messages with system prompt
                var chatMessages = aiServiceManager.convertToChatMessages(messages)
                chatMessages.insert(AIChatMessage(role: .system, content: systemPrompt), at: 0)
                
                print("[SocialBrainView] Sending request to LLM with messages:")
                for message in chatMessages {
                    print("[SocialBrainView] Role: \(message.role), Content: \(message.content)")
                }
                
                // Check if we should use streaming (Doubao or DeepSeek)
                if let doubaoService = chatService as? DoubaoChatService {
                    print("[SocialBrainView] Using Doubao streaming mode")
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
                    try await doubaoService.sendStreamingMessage(limitedText, context: chatMessages) { chunk in
                        Task { @MainActor in
                            // No logging chunks
                            currentStreamingMessage += chunk
                            if let lastIndex = messages.indices.last {
                                messages[lastIndex].content = currentStreamingMessage
                                if isFirstChunk {
                                    isLoading = false
                                    isFirstChunk = false
                                }
                            }
                        }
                    }
                    isStreaming = false
                    isLoading = false
                } else if let deepSeekService = chatService as? DeepSeekChatService {
                    print("[SocialBrainView] Using DeepSeek streaming mode")
                    isStreaming = true
                    currentStreamingMessage = ""
                    let streamingMessage = SocialBrainMessage(
                        content: "",
                        isFromUser: false,
                        timestamp: Date()
                    )
                    messages.append(streamingMessage)
                    var isFirstChunk = true
                    try await deepSeekService.sendStreamingMessage(limitedText, context: chatMessages) { chunk in
                        Task { @MainActor in
                            // No logging chunks
                            currentStreamingMessage += chunk
                            if let lastIndex = messages.indices.last {
                                messages[lastIndex].content = currentStreamingMessage
                                if isFirstChunk {
                                    isLoading = false
                                    isFirstChunk = false
                                }
                            }
                        }
                    }
                    isStreaming = false
                    isLoading = false
                } else {
                    print("[SocialBrainView] Using non-streaming mode")
                    let response = try await chatService.sendMessage(limitedText, context: chatMessages)
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
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
               let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
                
                // Get the keyboard height without input accessory
                let keyboardHeight = keyboardFrame.height
                
                // Calculate input accessory height if present
                if let window = UIApplication.shared.windows.first,
                   let inputAccessoryView = window.inputAccessoryView {
                    self.inputAccessoryHeight = inputAccessoryView.frame.height
                } else {
                    self.inputAccessoryHeight = 0
                }
                
                withAnimation(.easeInOut(duration: duration)) {
                    // Use the raw keyboard height without input accessory adjustment
                    self.keyboardHeight = keyboardHeight
                    self.isKeyboardVisible = true
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
                withAnimation(.easeInOut(duration: duration)) {
                    self.keyboardHeight = 0
                    self.isKeyboardVisible = false
                    self.inputAccessoryHeight = 0
                }
            }
        }
    }
    
    private func cleanupKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Helper function to update system prompt with notes for non-sample mode
    private func updateSystemPromptWithNotes(_ notes: String) async throws {
        // First check if the system prompt already contains these notes
        if !systemPrompt.contains(notes) {
            // If not, append them or update accordingly
            if !systemPrompt.contains("相关笔记如下:") {
                systemPrompt += "\n\n相关笔记如下:\n" + notes
            } else {
                // If it already has notes section but different notes, replace it
                let components = systemPrompt.components(separatedBy: "相关笔记如下:")
                if components.count > 1 {
                    systemPrompt = components[0] + "相关笔记如下:\n" + notes
                }
            }
        }
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
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = text
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                .markdownTheme(.compactMessage)
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
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = text
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                    .markdownTheme(.compactMessage)
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
        
        SocialBrainView(
            sourceType: "contact",
            sourceAction: "insights",
            sourceId: "preview-id"
        )
        .environment(\.colorScheme, .dark)
    }
}

private extension Theme {
    static let compactMessage = Theme()
        .heading1 { label in
            label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.15)) // smaller than default
                }
                .markdownMargin(top: .em(0.8), bottom: .em(0.5))
        }
        .heading2 { label in
            label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.05))
                }
                .markdownMargin(top: .em(0.7), bottom: .em(0.4))
        }
        .heading3 { label in
            label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(.em(1.0))
                }
                .markdownMargin(top: .em(0.6), bottom: .em(0.3))
        }
        .paragraph { label in
            label
                .relativeLineSpacing(.em(0.18))
                .markdownMargin(top: .zero, bottom: .em(0.5))
        }
}

struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let maxHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = .white
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Configure input accessory view with proper height and clear background
        let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        accessoryView.backgroundColor = .clear
        textView.inputAccessoryView = accessoryView
        
        // Disable the system input assistant view and other smart features
        textView.autocorrectionType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        
        // Disable the input assistant bar
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []
        
        // Set proper content insets to avoid overlap with keyboard
        textView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.scrollIndicatorInsets = textView.contentInset
        
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        // Update height
        let size = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: .greatestFiniteMagnitude))
        height = min(size.height, maxHeight)
        uiView.isScrollEnabled = height >= maxHeight
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView

        init(_ parent: GrowingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude))
            parent.height = min(size.height, parent.maxHeight)
            textView.isScrollEnabled = parent.height >= parent.maxHeight
        }
    }
}
