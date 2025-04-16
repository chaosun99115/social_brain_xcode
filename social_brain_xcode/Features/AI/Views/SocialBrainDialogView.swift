import SwiftUI
import UIKit

struct SocialBrainDialogView: View {
    // For standalone usage
    @State private var inputText = ""
    @State private var messages: [DialogMessage] = []
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) private var colorScheme
    
    // For transition animation
    var namespace: Namespace.ID?
    @Binding var isShowing: Bool
    @Binding var selectedMessageIndex: Int?
    @State private var animationCompleted = false
    
    // Method to dismiss the view
    func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            animationCompleted = false
            isShowing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                selectedMessageIndex = nil
            }
        }
    }
    
    // To access the original messages
    var originalMessages: [SocialBrainMessage]? = nil
    
    // Default initializer for standalone view
    init() {
        self._isShowing = .constant(true)
        self._selectedMessageIndex = .constant(nil)
        self._messages = State(initialValue: DialogMessage.sampleMessages)
    }
    
    // Initializer with initial prompt
    init(initialPrompt: String) {
        self._isShowing = .constant(true)
        self._selectedMessageIndex = .constant(nil)
        
        // Start with AI greeting message
        let initialMessages = [
            DialogMessage(content: initialPrompt, isFromUser: false)
        ]
        self._messages = State(initialValue: initialMessages)
        
        // Simulate first response after a short delay to allow the view to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // This will be executed after the view is loaded
        }
    }
    
    // Initializer for animated transition
    init(namespace: Namespace.ID, isShowing: Binding<Bool>, selectedBubbleIndex: Binding<Int?>) {
        self.namespace = namespace
        self._isShowing = isShowing
        self._selectedMessageIndex = selectedBubbleIndex
        self._messages = State(initialValue: DialogMessage.sampleMessages)
    }
    
    // Initializer with original messages
    init(namespace: Namespace.ID, isShowing: Binding<Bool>, selectedBubbleIndex: Binding<Int?>, originalMessages: [SocialBrainMessage]) {
        self.namespace = namespace
        self._isShowing = isShowing
        self._selectedMessageIndex = selectedBubbleIndex
        self.originalMessages = originalMessages
        
        // Convert messages if needed
        if let selectedIndex = selectedBubbleIndex.wrappedValue, 
           selectedIndex < originalMessages.count {
            // Start with the selected message
            var initialMessages = [DialogMessage(
                content: originalMessages[selectedIndex].content,
                isFromUser: originalMessages[selectedIndex].isFromUser,
                actionText: originalMessages[selectedIndex].suggestedAction
            )]
            
            // Add a response if this is a question and there's a next message that's a response
            if originalMessages[selectedIndex].isFromUser && 
               selectedIndex + 1 < originalMessages.count && 
               !originalMessages[selectedIndex + 1].isFromUser {
                initialMessages.append(DialogMessage(
                    content: originalMessages[selectedIndex + 1].content,
                    isFromUser: false,
                    actionText: originalMessages[selectedIndex + 1].suggestedAction
                ))
            }
            
            _messages = State(initialValue: initialMessages)
        }
    }
    
    // Get safe area insets
    private var safeAreaInsets: UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets ?? .zero
    }
    
    // Computed property to get all user message content
    private var userMessageContent: String {
        return messages
            .filter { $0.isFromUser }
            .map { $0.content }
            .joined(separator: "\n")
    }
    
    var body: some View {
        ZStack {
            // Full-screen background
            Color.primaryBackground
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Navigation bar section has been removed
                
                // Chat area
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            if let selectedIndex = selectedMessageIndex, namespace != nil {
                                // First message with matched geometry effect
                                if let originalMessages = originalMessages, selectedIndex < originalMessages.count {
                                    // Use the original message if available
                                    DialogQuestionBubble(text: originalMessages[selectedIndex].content)
                                        .matchedGeometryEffect(id: "message\(selectedIndex)", in: namespace!)
                                        .padding(.top, 8)
                                } else {
                                    // Fallback to the dialog messages
                                    DialogQuestionBubble(text: messages[0].content)
                                        .matchedGeometryEffect(id: "message\(selectedIndex)", in: namespace!)
                                        .padding(.top, 8)
                                }
                            }
                            
                            // Show all messages if no transition or show all except first if transitioning
                            ForEach(selectedMessageIndex == nil ? messages.indices : messages.indices.dropFirst(), id: \.self) { index in
                                if messages[index].isFromUser {
                                    DialogQuestionBubble(text: messages[index].content)
                                        .opacity(animationCompleted ? 1 : 0)
                                        .offset(y: animationCompleted ? 0 : 20)
                                } else {
                                    DialogAnswerBubble(
                                        text: messages[index].content,
                                        actionText: messages[index].actionText
                                    )
                                    .opacity(animationCompleted ? 1 : 0)
                                    .offset(y: animationCompleted ? 0 : 20)
                                }
                            }
                            
                            // Spacer at the bottom for input field
                            Spacer().frame(height: 60)
                                .id("bottomID")
                        }
                        .padding(.horizontal)
                        .padding(.top, 16) // Added more top padding since navigation is removed
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            scrollProxy.scrollTo("bottomID", anchor: .bottom)
                        }
                    }
                    .onAppear {
                        if selectedMessageIndex == nil {
                            scrollProxy.scrollTo("bottomID", anchor: .bottom)
                        }
                        
                        // Trigger fade-in animation after a short delay
                        if !animationCompleted {
                            withAnimation(.easeInOut(duration: 0.4).delay(0.2)) {
                                animationCompleted = true
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Input bar
                HStack {
                    TextField("hint_text".localized, text: $inputText)
                        .font(.body)
                        .padding(16)
                        .background(Color.inputBackground)
                        .cornerRadius(25)
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
                .padding(.bottom, safeAreaInsets.bottom)
                .background(Color.primaryBackground)
                .opacity(animationCompleted ? 1 : 0)
                .offset(y: animationCompleted ? 0 : 20)
            }
        }
        .preference(key: NoteContentPreferenceKey.self, value: userMessageContent)
        .onChange(of: messages) { _ in
            // Update the preference when messages change
            let updatedContent = userMessageContent
        }
        .statusBar(hidden: false)
    }
    
    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Add user message
        let userMessage = DialogMessage(content: trimmedText, isFromUser: true)
        messages.append(userMessage)
        
        // Clear input
        inputText = ""
        
        // Simulate AI response after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let response = generateAiResponse(to: trimmedText)
            messages.append(response)
        }
    }
}

private func generateAiResponse(to userInput: String) -> DialogMessage {
    // Generate different responses based on input content
    let lowercasedInput = userInput.lowercased()
    
    // Check for specific keywords and return appropriate responses
    if lowercasedInput.contains("今天") {
        return DialogMessage(
            content: "成功",
            isFromUser: false,
            actionText: "dialog_ai_research".localized
        )
    } else if lowercasedInput.contains("meeting") || lowercasedInput.contains("appointment") {
        return DialogMessage(
            content: "I see you're preparing for a meeting. Based on your notes, here are some topics that might be relevant.",
            isFromUser: false,
            actionText: "Generate meeting topics"
        )
    } else if lowercasedInput.contains("contact") || lowercasedInput.contains("person") {
        return DialogMessage(
            content: "I found this person in your contacts. Would you like to review your past interactions?",
            isFromUser: false,
            actionText: "View contact details"
        )
    } else if lowercasedInput.contains("follow") || lowercasedInput.contains("update") {
        return DialogMessage(
            content: "Here are some contacts you might want to follow up with based on your recent interactions.",
            isFromUser: false,
            actionText: "Show follow-up suggestions"
        )
    } else {
        // Default response
        return DialogMessage(
            content: "dialog_manager_project".localized,
            isFromUser: false,
            actionText: "dialog_view_original_note".localized
        )
    }
}


struct DialogMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let actionText: String?
    
    init(content: String, isFromUser: Bool, actionText: String? = nil) {
        self.content = content
        self.isFromUser = isFromUser
        self.actionText = actionText
    }
    
    // Sample conversations
    static let sampleMessages: [DialogMessage] = [
        DialogMessage(
            content: "dialog_recent_interactions".localized,
            isFromUser: true
        ),
        DialogMessage(
            content: "dialog_manager_project".localized,
            isFromUser: false,
            actionText: "dialog_view_original_note".localized
        ),
        DialogMessage(
            content: "dialog_manager_status".localized,
            isFromUser: true
        ),
        DialogMessage(
            content: "dialog_manager_daughter".localized,
            isFromUser: false,
            actionText: "dialog_ai_research".localized
        )
    ]
    
    static func == (lhs: DialogMessage, rhs: DialogMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isFromUser == rhs.isFromUser &&
        lhs.actionText == rhs.actionText
    }
}

struct DialogQuestionBubble: View {
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
        }
        .padding(.horizontal, 0)
    }
}

struct DialogAnswerBubble: View {
    let text: String
    let actionText: String?
    @Environment(\.colorScheme) private var colorScheme
    
    // Different button style options
    enum ButtonStyle {
        case accent     // Default accent color
        case tinted     // Tinted style with less intense color
        case secondary  // Secondary style with system colors
    }
    
    // Select which style to use
    private let buttonStyle: ButtonStyle = .tinted
    
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
                                .applyButtonStyle(buttonStyle, colorScheme: colorScheme)
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

// Extension to apply different button styles
extension View {
    @ViewBuilder
    func applyButtonStyle(_ style: DialogAnswerBubble.ButtonStyle, colorScheme: ColorScheme) -> some View {
        switch style {
        case .accent:
            self
                .foregroundColor(.white)
                .background(Color.accentColor)
        case .tinted:
            self
                .foregroundColor(.white)
                .background(Color(.systemBlue).opacity(0.8))
        case .secondary:
            self
                .foregroundColor(colorScheme == .light ? .white : Color(.systemBlue))
                .background(colorScheme == .light ? Color(.systemBlue).opacity(0.7) : Color(.systemBlue).opacity(0.3))
        }
    }
}

struct SocialBrainDialogView_Previews: PreviewProvider {
    @Namespace static var previewNamespace
    
    static var previews: some View {
        Group {
            // Preview the standalone view
            SocialBrainDialogView()
                .environment(\.colorScheme, .light)
                .environmentObject(LocalizationManager())
                .previewDisplayName("Light Mode")
            
            SocialBrainDialogView()
                .environment(\.colorScheme, .dark)
                .environmentObject(LocalizationManager())
                .previewDisplayName("Dark Mode")
        }
    }
} 
