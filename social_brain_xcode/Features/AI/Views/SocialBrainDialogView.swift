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
    @State private var inputBarBottomPadding: CGFloat = 0
    
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
                            
                            // Spacer at the bottom for content scrolling
                            Spacer().frame(height: 16)
                                .id("bottomID")
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        // Add bottom padding for the input bar plus keyboard height
                        .padding(.bottom, isKeyboardVisible ? keyboardHeight + 80 : 80)
                    }
                    .onChange(of: messages.count) { _ in
                        // Immediate scroll to the last message with no delay
                        if let lastIndex = messages.indices.last {
                            // For AI responses, position higher in the visible area
                            if !messages[lastIndex].isFromUser {
                                // For AI responses, position them higher in the visible area
                                scrollProxy.scrollTo("msg\(lastIndex)", anchor: UnitPoint(x: 0.5, y: 0.25))
                            } else {
                                // For user messages, standard bottom anchor is fine
                                scrollProxy.scrollTo("msg\(lastIndex)", anchor: .bottom)
                            }
                        } else {
                            scrollProxy.scrollTo("bottomID", anchor: .bottom)
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
                            // No delay, scroll immediately
                            if let lastIndex = messages.indices.last {
                                // Use anchor based on message type for best visibility
                                let anchor: UnitPoint = messages[lastIndex].isFromUser ? .bottom : .top
                                scrollProxy.scrollTo("msg\(lastIndex)", anchor: anchor)
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CheckContentVisibility"))) { _ in
                        // This is triggered by the parent view to check if content is visible
                        if !messages.isEmpty, isKeyboardVisible {
                            // Immediate scroll without delay
                            if let lastIndex = messages.indices.last {
                                scrollProxy.scrollTo("msg\(lastIndex)", anchor: .center)
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PrepareForResponse"))) { _ in
                        // This is triggered just before an AI response will be added
                        // Pre-position the scroll to ensure space is reserved for the upcoming response
                        if !messages.isEmpty, isKeyboardVisible {
                            // Immediate pre-positioning with no animation delay
                            // Scroll to bottom and reserve space for the response
                            scrollProxy.scrollTo("bottomID", anchor: .bottom)
                            
                            // Also notify parent view that we need space for a new response
                            NotificationCenter.default.post(name: Notification.Name("ReserveSpaceForResponse"), object: nil)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ImmediateScrollToLatest"))) { _ in
                        // Immediate scroll with no delay for second responses
                        if !messages.isEmpty {
                            // Get the latest message index
                            if let lastIndex = messages.indices.last {
                                // For AI responses, use custom coordinate-based scroll position to ensure visibility
                                // This ensures the message is positioned higher up in the visible area
                                let proxy = scrollProxy
                                
                                // First scroll to position with .top anchor to ensure message is in view
                                proxy.scrollTo("msg\(lastIndex)", anchor: .top)
                                
                                // Then do a secondary scroll to position the message higher up in the viewport
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                    // Using a very slight delay to ensure the first scroll completes
                                    // This ensures the message is positioned approximately in the upper third of the screen
                                    proxy.scrollTo("msg\(lastIndex)", anchor: UnitPoint(x: 0.5, y: 0.25))
                                }
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ImmediateScrollToHighPosition"))) { _ in
                        // Specifically for positioning responses much higher on screen
                        if !messages.isEmpty {
                            if let lastIndex = messages.indices.last {
                                // First get it in view with .top anchor
                                scrollProxy.scrollTo("msg\(lastIndex)", anchor: .top)
                                
                                // Then immediately reposition to upper quarter of screen
                                // This positions the message very high in the visible area
                                scrollProxy.scrollTo("msg\(lastIndex)", anchor: UnitPoint(x: 0.5, y: 0.1))
                            }
                        }
                    }
                    
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PrepareForResponseHighPosition"))) { _ in
                        // This is triggered just before an AI response will be added, with high positioning
                        if !messages.isEmpty, isKeyboardVisible {
                            // Reserve more space at top of screen for incoming response
                            scrollProxy.scrollTo("bottomID", anchor: .bottom)
                            
                            // Notify parent view that we need extra space at top for the response
                            NotificationCenter.default.post(name: Notification.Name("ReserveExtraSpaceForResponse"), object: nil)
                        }
                    }
                    
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("KeyboardWillShow"))) { _ in
                        // Adjust scroll content when keyboard will show
                        if !messages.isEmpty {
                            if let lastIndex = messages.indices.last {
                                scrollProxy.scrollTo("msg\(lastIndex)", anchor: .bottom)
                            } else {
                                scrollProxy.scrollTo("bottomID", anchor: .bottom)
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
                
                // Input bar - fixed at the bottom, positioned above keyboard
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        TextField("hint_text".localized, text: $inputText)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(height: 44) // Standard iOS touch target height
                            .background(Color.inputBackground)
                            .cornerRadius(22) // Half of height for consistent circular ends
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
                                .frame(width: 44, height: 44) // Standard iOS touch target size
                                .background(Color.primaryAction)
                                .clipShape(Circle())
                                .shadow(color: Color.primaryText.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8) // Standard 8pt spacing per HIG
                    .padding(.bottom, 0)
                    .background(Color.primaryBackground)
                    .opacity(animationCompleted ? 1 : 0)
                    .offset(y: animationCompleted ? 0 : 20)
                }
                // Remove extra padding, only use safe area inset when keyboard is not visible
                .padding(.bottom, isKeyboardVisible ? 0 : safeAreaInsets.bottom)
                .background(Color.primaryBackground)
                .zIndex(1) // Ensure input bar stays above the scroll content
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
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
               let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
               let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
                
                let animationCurve = UIView.AnimationOptions(rawValue: curve)
                
                withAnimation(.easeOut(duration: duration)) {
                    // Remove any adjustments to keyboard height to ensure it sits flush with input field
                    self.keyboardHeight = keyboardFrame.height
                    self.isKeyboardVisible = true
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { notification in
            if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
               let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
                
                let animationCurve = UIView.AnimationOptions(rawValue: curve)
                
                withAnimation(.easeOut(duration: duration)) {
                    self.keyboardHeight = 0
                    self.isKeyboardVisible = false
                }
            }
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
        
        // Immediately reserve space for the response and scroll to user message
        NotificationCenter.default.post(name: Notification.Name("PrepareForResponseHighPosition"), object: nil)
        
        // Shorter delay before AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let response = generateAiResponse(to: trimmedText)
            
            // Add the response with animation and immediately scroll to it
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.messages.append(response)
                
                // Immediately scroll to the new message as part of the same animation
                // This ensures the scroll happens in sync with the message appearance
                // The special notification indicates we want high positioning
                NotificationCenter.default.post(name: Notification.Name("ImmediateScrollToHighPosition"), object: nil)
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
