import SwiftUI

struct SocialBrainView: View {
    @State private var inputText = ""
    @State private var messages = [SocialBrainMessage]()
    @State private var suggestedQuestions = SocialBrainMessage.mockMessages.filter { $0.isFromUser }
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var isConversationActive = false
    @State private var scrollToBottomID = UUID()
    @State private var scrollToTopID = "topID"
    @FocusState private var isInputFocused: Bool
    @State private var isLoading = false
    @State private var showLoadingModal = false
    
    var body: some View {
        NavigationView {
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
                                                actionText: message.suggestedAction
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
                                    .clipShape(Circle())
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
            .navigationTitle("social_brain".localized)
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        // Ensure keyboard dismissal when tapping anywhere
                        isInputFocused = false
                    }
            )
        }
        .onChange(of: isLoading) { loading in
            if loading {
                // Show the modal when loading starts
                showLoadingModal = true
                
                // Hide the modal after 2 seconds but keep loading state
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showLoadingModal = false
                }
            }
        }
    }
    
    private func handleSuggestedQuestion(_ question: String) {
        // Start conversation mode
        isConversationActive = true
        
        // Add user question
        let userMessage = SocialBrainMessage(
            content: question,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Show loading state
        isLoading = true
        
        // Generate answer after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            let aiResponse = generateAiResponse(to: question)
            messages.append(aiResponse)
        }
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
        
        // Simulate AI response after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            // Generate mock response based on user input
            let aiResponse = generateAiResponse(to: trimmedText)
            messages.append(aiResponse)
        }
    }
    
    private func startNewConversation() {
        withAnimation {
            isConversationActive = false
            messages.removeAll()
            isLoading = false
        }
    }
    
    private func generateAiResponse(to userInput: String) -> SocialBrainMessage {
        // Mock AI response generator - in a real app, this would call an actual API
        let lowercasedInput = userInput.lowercased()
        
        // Generate different responses based on input content
        if lowercasedInput.contains("manager") || lowercasedInput.contains("李经理") {
            return SocialBrainMessage(
                content: "dialog_manager_daughter".localized,
                isFromUser: false,
                timestamp: Date(),
                suggestedAction: "dialog_ai_research".localized
            )
        } else if lowercasedInput.contains("interact") || lowercasedInput.contains("social") || lowercasedInput.contains("follow") {
            return SocialBrainMessage(
                content: "dialog_manager_project".localized,
                isFromUser: false, 
                timestamp: Date(),
                suggestedAction: "dialog_view_original_note".localized
            )
        } else {
            // Default response
            let responses = [
                "I can help you prepare for social events, remember important details about your contacts, and suggest follow-up actions for your relationships.",
                "Based on your notes, you might want to check in with Sarah Miller. You mentioned her project deadline is approaching.",
                "Would you like me to suggest some conversation topics for your upcoming meeting? I can analyze your past interactions for relevant themes."
            ]
            
            return SocialBrainMessage(
                content: responses.randomElement() ?? responses[0],
                isFromUser: false,
                timestamp: Date(),
                suggestedAction: lowercasedInput.contains("meeting") || lowercasedInput.contains("conversation") ? 
                    "Suggest topics" : nil
            )
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
                    Text("searching_notes".localized)
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
                        Text("social_quote".localized)
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
                            
                            Text("quote_source".localized)
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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Message text
                Text(text)
                    .font(.body)
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
        SocialBrainView()
            .environment(\.colorScheme, .light)
            .environmentObject(LocalizationManager())
        
        SocialBrainView()
            .environment(\.colorScheme, .dark)
            .environmentObject(LocalizationManager())
    }
}
