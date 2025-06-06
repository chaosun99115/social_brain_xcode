import SwiftUI
import CoreData
import MarkdownUI

struct SocialBrainSheetView: View {
    // Context parameters
    let sourceType: String
    let sourceAction: String
    let sourceId: String
    @Environment(\.dismiss) private var dismiss
    
    // Add PromptConfigurationManager
    private let promptManager = PromptConfigurationManager.shared
    
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
    
    // System prompt generation
    private func generateSystemPrompt() async throws {
        print("[SocialBrainSheetView] generateSystemPrompt started")
        print("[SocialBrainSheetView] Context - sourceType: \(sourceType), sourceAction: \(sourceAction), sourceId: \(sourceId)")
        
        // Always try to load the contact first if we're in contact context
        if sourceType == "contact" {
            print("[SocialBrainSheetView] Attempting to load contact for ID: \(sourceId)")
            let context = try await CoreDataManager.shared.viewContext
            let contactFetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
            contactFetchRequest.predicate = NSPredicate(format: "contactId == %@", sourceId as CVarArg)
            
            if let contact = try context.fetch(contactFetchRequest).first {
                print("[SocialBrainSheetView] Found contact: \(contact.name ?? "unnamed")")
                print("[SocialBrainSheetView] Setting contextContact")
                contextContact = contact
                print("[SocialBrainSheetView] contextContact after setting: \(contextContact?.name ?? "nil")")
            } else {
                print("[SocialBrainSheetView] No contact found for ID: \(sourceId)")
            }
        }
        
        // Then proceed with sample provider or regular prompt generation
        if let sampleProvider = getSampleProvider() {
            print("[SocialBrainSheetView] Using sample provider: \(type(of: sampleProvider))")
            // Use the new prompt generation system with notes
            let context = PromptContext(
                mode: SampleMode(rawValue: appModeManager.sampleModeType ?? "") ?? .none,
                question: "",  // Initial prompt doesn't have a specific question
                contact: contextContact
            )
            print("[SocialBrainSheetView] Generating prompt with context - mode: \(context.mode), contact: \(context.contact?.name ?? "nil")")
            systemPrompt = try await sampleProvider.generateSystemPromptWithNotes(for: context)
            print("[SocialBrainSheetView] Generated sample mode prompt:\n\(systemPrompt)")
            return
        }
        
        // Use existing logic for non-sample mode
        var prompt = "system prompt"
        print("[SocialBrainSheetView] Using non-sample mode prompt generation")
        switch (sourceType, sourceAction) {
        case ("contact", "general"):
            if let contact = contextContact {
                prompt += "Contact is \(contact.name ?? "failed to load contact name"). "
                print("[SocialBrainSheetView] Adding contact context to prompt: \(contact.name ?? "unnamed")")
                
                // Use the new note fetching functionality
                if let sampleProvider = getSampleProvider() {
                    let context = PromptContext(
                        mode: .none,
                        question: "",
                        contact: contact
                    )
                    print("[SocialBrainSheetView] Fetching relevant notes for contact")
                    let notesContext = try await sampleProvider.fetchRelevantNotes(for: context)
                    if !notesContext.isEmpty {
                        prompt += notesContext
                        print("[SocialBrainSheetView] Added notes context to prompt")
                    } else {
                        print("[SocialBrainSheetView] No relevant notes found for contact")
                    }
                }
            } else {
                print("[SocialBrainSheetView] No contact found for ID: \(sourceId)")
                prompt += "contact + general (ID: \(sourceId)). "
                prompt += "Focus on general relationship management, communication strategies, and maintaining healthy connections."
            }
            
            prompt += "You are analyzing a specific contact with ID: \(sourceId). "
            prompt += "Focus on providing insights about this contact's relationship with the user, "
            prompt += "suggesting conversation topics, and identifying opportunities for deeper connection."
            
        default:
            print("[SocialBrainSheetView] Using default prompt for non-contact context")
            prompt += "You are providing general social relationship advice."
        }
        
        print("[SocialBrainSheetView] Final generated prompt:\n\(prompt)")
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
        print("[SocialBrainSheetView] initializeSuggestedQuestions started")
        print("[SocialBrainSheetView] Current contextContact: \(contextContact?.name ?? "nil")")
        
        // Try to get prompt-based questions first
        Task {
            do {
                let context = try await CoreDataManager.shared.viewContext
                
                // Get prompts based on source type and sample mode, passing the contact for dynamic text replacement
                let prompts = promptManager.getPromptsForSourceType(
                    sourceType,
                    sampleMode: appModeManager.sampleModeType,
                    context: context,
                    contact: contextContact  // Pass the contact for dynamic text replacement
                )
                
                if !prompts.isEmpty {
                    // Create suggested questions from all prompts
                    let questions = prompts.map { prompt in
                        return SocialBrainMessage(
                            content: prompt.display,
                            isFromUser: false,
                            timestamp: Date()
                        )
                    }
                    await MainActor.run {
                        suggestedQuestions = questions
                    }
                    return
                }
            } catch {
                print("[SocialBrainSheetView] Error fetching prompts: \(error)")
            }
            
            // Fallback to existing logic if no prompts found
            if let sampleProvider = getSampleProvider() {
                print("[SocialBrainSheetView] Sample provider found: \(type(of: sampleProvider))")
                let context = PromptContext(
                    mode: SampleMode(rawValue: appModeManager.sampleModeType ?? "") ?? .none,
                    question: "",
                    contact: contextContact
                )
                suggestedQuestions = sampleProvider.getSuggestedQuestions(for: context)
                print("[SocialBrainSheetView] Questions for context: \(suggestedQuestions.map { $0.content })")
            } else {
                print("[SocialBrainSheetView] Using context-aware questions")
                print("[SocialBrainSheetView] Calling forContext with:")
                print("- sourceType: \(sourceType)")
                print("- sourceAction: \(sourceAction)")
                print("- contact: \(contextContact?.name ?? "nil")")
                
                let questions = SuggestedQuestionsProvider.forContext(
                    sourceType: sourceType,
                    sourceAction: sourceAction,
                    contact: contextContact
                )
                print("[SocialBrainSheetView] Received questions: \(questions.map { $0.content })")
                suggestedQuestions = questions
            }
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
            
            // Generate system prompt first to load the contact
            Task {
                do {
                    try await generateSystemPrompt()
                    // Initialize suggested questions after contact is loaded
                    await MainActor.run {
                        initializeSuggestedQuestions()
                    }
                } catch {
                    print("[SocialBrainSheetView] Error generating system prompt: \(error)")
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
                print("[SocialBrainSheetView] New note created: \(newNoteText)")
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
                
                print("[SocialBrainSheetView] Sending request to LLM with messages:")
                for message in chatMessages {
                    print("[SocialBrainSheetView] Role: \(message.role), Content: \(message.content)")
                }
                
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
                    print("[SocialBrainSheetView] Error caught: \(error) (\(type(of: error)))")
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
    
    // Helper function to update system prompt with notes for non-sample mode
    private func updateSystemPromptWithNotes(_ notes: String) async throws {
        print("[SocialBrainSheetView] updateSystemPromptWithNotes started")
        print("[SocialBrainSheetView] Current system prompt:\n\(systemPrompt)")
        print("[SocialBrainSheetView] Notes to add:\n\(notes)")
        
        // First check if the system prompt already contains these notes
        if !systemPrompt.contains(notes) {
            print("[SocialBrainSheetView] Notes not found in current prompt, adding them")
            // If not, append them or update accordingly
            if !systemPrompt.contains("相关笔记如下:") {
                systemPrompt += "\n\n相关笔记如下:\n" + notes
                print("[SocialBrainSheetView] Added new notes section to prompt")
            } else {
                // If it already has notes section but different notes, replace it
                print("[SocialBrainSheetView] Replacing existing notes section")
                let components = systemPrompt.components(separatedBy: "相关笔记如下:")
                if components.count > 1 {
                    systemPrompt = components[0] + "相关笔记如下:\n" + notes
                }
            }
        } else {
            print("[SocialBrainSheetView] Notes already present in prompt, no update needed")
        }
        
        print("[SocialBrainSheetView] Updated system prompt:\n\(systemPrompt)")
    }
}

struct SocialBrainSheetView_Previews: PreviewProvider {
    static var previews: some View {
        SocialBrainSheetView(
            sourceType: "contact",
            sourceAction: "insights",
            sourceId: "preview-id"
        )
        .environment(\.colorScheme, .light)
        
        SocialBrainSheetView(
            sourceType: "contact",
            sourceAction: "insights",
            sourceId: "preview-id"
        )
        .environment(\.colorScheme, .dark)
    }
} 