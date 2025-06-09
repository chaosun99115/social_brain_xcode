import SwiftUI
import CoreData
import MarkdownUI

struct SocialBrainSheetView: View {
    // Context parameters
    let sourceType: String
    let sourceAction: String
    let sourceId: String
    let initialContact: Contact?
    @Environment(\.dismiss) private var dismiss
    
    // Add PromptConfigurationManager
    private let promptManager = PromptConfigurationManager.shared
    
    // Add PromptGenerator
    private let promptGenerator = PromptGenerator.shared
    
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
    
    // Add state to track message source
    @State private var isCustomQuestion: Bool = false
    @State private var currentPromptIdentifier: Int = 0
    
    init(sourceType: String, sourceAction: String, sourceId: String, initialContact: Contact? = nil) {
        self.sourceType = sourceType
        self.sourceAction = sourceAction
        self.sourceId = sourceId
        self.initialContact = initialContact
        // Initialize contextContact with initialContact
        _contextContact = State(initialValue: initialContact)
    }
    
    // Add helper method to get provider
    private func getSampleProvider() -> SampleModeProvider? {
        print("[SocialBrainSheetView] getSampleProvider started")
        print("[SocialBrainSheetView] isSampleMode: \(appModeManager.isSampleMode)")
        print("[SocialBrainSheetView] sampleModeType: \(appModeManager.sampleModeType ?? "nil")")
        print("[SocialBrainSheetView] sourceType: \(sourceType)")
        
        // For contact-specific views, use ContactProvider
        if sourceType == "contact" {
            print("[SocialBrainSheetView] Using ContactProvider for contact view")
            return ContactProvider()
        }
        
        // For sample mode, use the configured provider
        guard appModeManager.isSampleMode,
              let modeType = appModeManager.sampleModeType else {
            print("[SocialBrainSheetView] No sample provider available")
            return nil
        }
        
        print("[SocialBrainSheetView] Getting provider for mode: \(modeType)")
        return SampleModeProviderFactory.getProvider(for: modeType)
    }
    
    // Modify initializeSuggestedQuestions to only use SourceTypePromptMapping
    private func initializeSuggestedQuestions() {
        print("[SocialBrainSheetView] initializeSuggestedQuestions started")
        print("[SocialBrainSheetView] Current contextContact: \(contextContact?.name ?? "nil")")
        
        Task {
            do {
                let context = try await CoreDataManager.shared.viewContext
                
                // ARCHITECTURE FLOW:
                // initializeSuggestedQuestions() 
                //     ↓ (gets multiple prompts from database)
                // promptManager.getPromptsForSourceType()
                //     ↓ (creates multiple suggested questions)
                // suggestedQuestions array
                //     ↓ (user selects a question)
                // handleSuggestedQuestion() 
                //     ↓ (uses stored promptIdentifier)
                // promptGenerator.generatePrompts()
                //     ↓ (routes to appropriate flow)
                // PromptFlow.swift (with centralized update logic)
                
                // Get prompts based on source type and sample mode, passing the contact for dynamic text replacement
                let prompts = promptManager.getPromptsForSourceType(
                    sourceType,
                    sampleMode: appModeManager.sampleModeType,
                    context: context,
                    contact: contextContact  // Pass the contact for dynamic text replacement
                )
                
                // Create suggested questions from all prompts, storing the identifier
                let questions = prompts.map { prompt in
                    return SocialBrainMessage(
                        content: prompt.display,
                        isFromUser: false,
                        timestamp: Date(),
                        promptIdentifier: prompt.identifier
                    )
                }
                
                await MainActor.run {
                    suggestedQuestions = questions
                }
            } catch {
                print("[SocialBrainSheetView] Error fetching prompts: \(error)")
                // Set empty questions on error
                await MainActor.run {
                    suggestedQuestions = []
                }
            }
        }
    }
    
    // Add helper function to get prompt identifier
    private func getPromptIdentifier(for sourceType: String, sampleMode: String?) -> Int {
        // Get available identifiers for this source type and sample mode
        let identifiers = SourceTypePromptMapping.getPromptIdentifiers(for: sourceType, sampleMode: sampleMode)
        // Return the first identifier (there should always be at least one for each source type)
        return identifiers.first ?? 0  // Fallback to 0 only if something is misconfigured
    }
    
    // Handle custom question submission
    private func handleCustomQuestion() {
        isCustomQuestion = true
        currentPromptIdentifier = 0  // Set to 0 for ChatFlow
        sendMessage()
    }
    
    // Handle suggested question tap
    private func handleSuggestedQuestion(_ question: String, promptIdentifier: Int? = nil) {
        isCustomQuestion = false
        guard let identifier = promptIdentifier else {
            print("[SocialBrainSheetView] Error: No prompt identifier provided for suggested question")
            return
        }
        currentPromptIdentifier = identifier
        inputText = question
        sendMessage()
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
                                                handleSuggestedQuestion(question.content, promptIdentifier: question.promptIdentifier)
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
                                .background(Color(.systemGray6))
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
                        Button(action: handleCustomQuestion) {
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
                    .padding(.bottom, isKeyboardVisible ? keyboardHeight + 12 : 12)
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
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
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
            print("[SocialBrainSheetView] View appeared with context:")
            print("[SocialBrainSheetView] - sourceType: \(sourceType)")
            print("[SocialBrainSheetView] - sourceAction: \(sourceAction)")
            print("[SocialBrainSheetView] - sourceId: \(sourceId)")
            print("[SocialBrainSheetView] - initialContact: \(initialContact?.name ?? "nil")")
            
            // If we have an initialContact, use it directly
            if let contact = initialContact {
                contextContact = contact
            }
            
            // Initialize suggested questions after contact is loaded
            Task {
                await MainActor.run {
                    initializeSuggestedQuestions()
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
                print("[SocialBrainSheetView] New note created: \(newNoteText)")
            }
            .environmentObject(NoteManager.shared)
            .environmentObject(appModeManager)
        }
    }
    
    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        let limitedText = String(trimmedText.prefix(1000))
        
        // Use the full input text as user question - extraction is handled by the flows
        let userQuestion = limitedText
        
        if !isConversationActive {
            isConversationActive = true
        }
        
        // Add user message
        let userMessage = SocialBrainMessage(
            content: userQuestion,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        inputText = ""
        isLoading = true
        
        Task {
            do {
                guard let chatService = aiServiceManager.getChatService() else {
                    throw AIChatServiceError.unauthorized
                }
                
                // Use appropriate prompt identifier based on message source
                let promptPair = try await promptGenerator.generatePrompts(
                    sourceType: sourceType,
                    sourceAction: isCustomQuestion ? "chat" : "question",
                    sourceId: sourceId,
                    sampleMode: appModeManager.sampleModeType,
                    contact: contextContact,
                    promptDisplay: userQuestion,
                    promptIdentifier: isCustomQuestion ? 0 : currentPromptIdentifier
                )
                
                // Prepare messages with both prompts
                var chatMessages = aiServiceManager.convertToChatMessages(messages)
                
                // Add system prompt
                chatMessages.insert(AIChatMessage(role: .system, content: promptPair.systemPrompt), at: 0)
                
                // If we have a user prompt, use it to modify the user's message
                if let userPrompt = promptPair.userPrompt {
                    let enhancedUserMessage = AIChatMessage(
                        role: .user,
                        content: "\(userPrompt)\n\nUser Question: \(userQuestion)"
                    )
                    // Replace the last user message with the enhanced version
                    if let lastIndex = chatMessages.lastIndex(where: { $0.role == .user }) {
                        chatMessages[lastIndex] = enhancedUserMessage
                    }
                }
                
                // System prompt updates are now handled automatically by the flows
                // No additional processing needed here
                
                // Check if we should use streaming (Doubao or DeepSeek)
                if let doubaoService = chatService as? DoubaoChatService {
                    print("[SocialBrainSheetView] Using Doubao streaming mode")
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
                    print("[SocialBrainSheetView] Using DeepSeek streaming mode")
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
                    print("[SocialBrainSheetView] Using non-streaming mode")
                    let response = try await chatService.sendMessage(limitedText, context: chatMessages)
                    print("[SocialBrainSheetView] Received response from LLM:")
                    if let firstChoice = response.choices.first {
                        print("[SocialBrainSheetView] \(firstChoice.message.content)")
                    } else {
                        print("[SocialBrainSheetView] No content in response")
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
                    print("[SocialBrainSheetView] Error caught: \(error)")
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
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
                isKeyboardVisible = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
            isKeyboardVisible = false
        }
    }
    
    private func cleanupKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
}

struct SocialBrainSheetView_Previews: PreviewProvider {
    static var previews: some View {
        SocialBrainSheetView(
            sourceType: "contact",
            sourceAction: "insights",
            sourceId: "preview-id",
            initialContact: nil
        )
        .environment(\.colorScheme, .light)
        
        SocialBrainSheetView(
            sourceType: "contact",
            sourceAction: "insights",
            sourceId: "preview-id",
            initialContact: nil
        )
        .environment(\.colorScheme, .dark)
    }
} 