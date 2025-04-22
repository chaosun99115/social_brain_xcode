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
    
    // For keyboard handling
    @State private var keyboardHeight: CGFloat = 0
    @State private var isKeyboardVisible: Bool = false
    @State private var scrollToBottom: Bool = false
    
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
                                        .id("msg\(index)")
                                } else {
                                    DialogAnswerBubble(
                                        text: messages[index].content,
                                        actionText: messages[index].actionText,
                                        onActionTapped: {
                                            handleActionButtonTapped(actionText: messages[index].actionText ?? "123")
                                        }
                                    )
                                    .opacity(animationCompleted ? 1 : 0)
                                    .offset(y: animationCompleted ? 0 : 20)
                                    .id("msg\(index)")
                                }
                            }
                            
                            // Spacer at the bottom when keyboard not showing
                            if !isKeyboardVisible {
                                Spacer().frame(height: 16)
                                    .id("bottomID")
                            } else {
                                // Significantly increase spacing when keyboard is showing to ensure full message visibility
                                Spacer().frame(height: 300)
                                    .id("bottomID")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        // Add extra bottom padding when keyboard is showing to push content up
                        .padding(.bottom, isKeyboardVisible ? 80 : 0)
                    }
                    .onChange(of: messages.count) { _ in
                        // Scroll to the last message with animation
                        // We use a slight delay to ensure layout is complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                if let lastIndex = messages.indices.last {
                                    // When keyboard is visible, use .center to ensure message is visible
                                    let anchor: UnitPoint = isKeyboardVisible ? .center : .bottom
                                    scrollProxy.scrollTo("msg\(lastIndex)", anchor: anchor)
                                } else {
                                    scrollProxy.scrollTo("bottomID", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onChange(of: keyboardHeight) { newHeight in
                        // When keyboard appears, scroll to show the latest messages
                        if newHeight > 0 && !messages.isEmpty {
                            withAnimation {
                                if let lastIndex = messages.indices.last {
                                    scrollProxy.scrollTo("msg\(lastIndex)", anchor: .center)
                                } else {
                                    scrollProxy.scrollTo("bottomID", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ScrollToNewestMessage"))) { _ in
                        // This specifically handles scrolling after a new message is added
                        if !messages.isEmpty {
                            // Add a longer delay to ensure layout is complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    if let lastIndex = messages.indices.last {
                                        // For better visibility, always use .top to show the full message from the top
                                        scrollProxy.scrollTo("msg\(lastIndex)", anchor: .top)
                                        
                                        // For response messages with action buttons, also scroll a bit more up
                                        if !messages[lastIndex].isFromUser && messages[lastIndex].actionText != nil {
                                            // Need to scroll even more to show action buttons
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    // Second scroll to ensure full visibility including buttons
                                                    scrollProxy.scrollTo("msg\(lastIndex)", anchor: .top)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CheckContentVisibility"))) { _ in
                        // This is triggered by the parent view to check if content is visible
                        if !messages.isEmpty, isKeyboardVisible {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    // When parent view requests visibility check, ensure last few messages are visible
                                    if let lastIndex = messages.indices.last {
                                        scrollProxy.scrollTo("msg\(lastIndex)", anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PrepareForResponse"))) { _ in
                        // This is triggered just before an AI response will be added
                        // Pre-position the scroll to ensure space is reserved for the upcoming response
                        if !messages.isEmpty, isKeyboardVisible {
                            withAnimation(.easeOut(duration: 0.2)) {
                                // Scroll to bottom and add some extra space to reserve room for the response
                                scrollProxy.scrollTo("bottomID", anchor: .bottom)
                                
                                // Also notify parent view that we need space for a new response
                                NotificationCenter.default.post(name: Notification.Name("ReserveSpaceForResponse"), object: nil)
                            }
                        }
                    }
                    .onAppear {
                        setupKeyboardObservers()
                        
                        if selectedMessageIndex == nil {
                            // Initial scroll to bottom with a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    scrollProxy.scrollTo("bottomID", anchor: .bottom)
                                }
                            }
                        }
                        
                        // Trigger fade-in animation after a short delay
                        if !animationCompleted {
                            withAnimation(.easeInOut(duration: 0.4).delay(0.2)) {
                                animationCompleted = true
                            }
                        }
                    }
                    .onDisappear {
                        removeKeyboardObservers()
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
                            // Keep focus on the text field
                            keepKeyboardVisible()
                        }
                    
                    Button(action: {
                        sendMessage()
                        // Keep focus on the text field
                        keepKeyboardVisible()
                    }) {
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
                .padding(.vertical, 0)
                .padding(.bottom, 0)
                .background(Color.primaryBackground)
                .opacity(animationCompleted ? 1 : 0)
                .offset(y: animationCompleted ? 0 : 20)
                // Position input field directly above keyboard with minimal gap
                .offset(y: isKeyboardVisible ? -keyboardHeight + 40 : 0)
            }
        }
        .preference(key: NoteContentPreferenceKey.self, value: userMessageContent)
        .onChange(of: messages) { _ in
            // Update the preference when messages change
            let updatedContent = userMessageContent
        }
        .statusBar(hidden: false)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = keyboardFrame.height
                self.isKeyboardVisible = true
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardHeight = 0
            self.isKeyboardVisible = false
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Add user message
        let userMessage = DialogMessage(content: trimmedText, isFromUser: true)
        messages.append(userMessage)
        
        // Clear input
        inputText = ""
        
        // Force immediate scroll to show the user message
        NotificationCenter.default.post(name: Notification.Name("ScrollToNewestMessage"), object: nil)
        
        // Pre-position the view before the response arrives to reserve space
        NotificationCenter.default.post(name: Notification.Name("PrepareForResponse"), object: nil)
        
        // Simulate AI response after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let response = generateAiResponse(to: trimmedText)
            
            // Add the response with animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.messages.append(response)
            }
            
            // Ensure visibility immediately as the message is added
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(name: Notification.Name("ScrollToNewestMessage"), object: nil)
                
                // For responses with action buttons, do an additional scroll after a bit more time
                if response.actionText != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        NotificationCenter.default.post(name: Notification.Name("ScrollToNewestMessage"), object: nil)
                    }
                }
            }
        }
    }
    
    private func handleActionButtonTapped(actionText:String) {
        // Create a new AI response based on the action
        
        var question = ""
        
        if actionText.contains("联系人") {
            question = "联系人已经建立。你有使用过这个App吗，体验怎么样？ "
        }
        
        let actionResponse = DialogMessage(
            content: question,
            isFromUser: false
        )
        
        // Add the new message
        messages.append(actionResponse)
        
        // Trigger manual scroll to make the response visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: Notification.Name("ScrollToNewestMessage"), object: nil)
        }
    }
    
    // Helper method to keep keyboard visible after text submission
    private func keepKeyboardVisible() {
        // This is a placeholder method that represents the intent
        // In practice, we rely on the text field staying in focus
        // The actual implementation would depend on specific iOS behavior testing
        
        // For improved keyboard behavior in a production app,
        // you would typically use a custom TextField wrapper or UIViewRepresentable
    }
}

private func generateAiResponse(to userInput: String) -> DialogMessage {
    // Generate different responses based on input content
    let lowercasedInput = userInput.lowercased()
    
    // Check for specific keywords and return appropriate responses
    if lowercasedInput.contains("123") {
        return DialogMessage(
            content: "成功",
            isFromUser: false,
            actionText: nil
        )
    } else if lowercasedInput.contains("灵买的用户") {
        return DialogMessage(
            content: "你还没有一个叫做Chao的联系人，是否帮你建立？",
            isFromUser: false,
            actionText: "建立新联系人"
        )
    } else if lowercasedInput.contains("你觉得") {
        return DialogMessage(
            content: "我还没用过这个App，提醒我去下载试用一下",
            isFromUser: false,
            actionText: nil
        )
    } else if lowercasedInput.contains("下载") {
        return DialogMessage(
            content: "好的。除了这个应用，你还聊到关于Chao的其他事情吗？",
            isFromUser: false,
            actionText: nil
        )
    } else if lowercasedInput.contains("阅读") {
        return DialogMessage(
            content: "还有其他的吗？",
            isFromUser: false,
            actionText:nil
        )
    } else if lowercasedInput.contains("暂时") {
            return DialogMessage(
                content: "好的。你可以点击右上角的保存按钮，保存后你可以在联系人的页面查看关于Chao的汇总信息。",
                isFromUser: false,
                actionText:nil
            )
    }else {
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
        VStack(alignment: .trailing, spacing: 0) {
            Text(text)
                .font(.body)
                .foregroundColor(.primaryText)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .trailing)
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
    var onActionTapped: (() -> Void)?
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
                            onActionTapped?()
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
