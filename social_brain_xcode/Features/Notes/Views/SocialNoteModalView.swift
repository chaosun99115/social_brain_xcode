import SwiftUI

struct SocialNoteModalView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var noteManager: NoteManager
    @EnvironmentObject var appModeManager: AppModeManager
    @State private var dragOffset: CGFloat = 0
    @State private var messageContent: String = "今天遇到了哪些事"
    @State private var initialPrompt: String = "今天遇到了哪些事"
    
    // Add missing state variables for mention handling
    @State private var unmatchedMentions: [String] = []
    @State private var showingMentionConfirmation = false
    @State private var existingMentionedContacts: [String] = []
    
    // Add onSave closure
    var onSave: (String) -> Void = { _ in }
    
    // Reference to the dialog view
    @State private var isShowingDialog: Bool = true
    @State private var selectedMessageIndex: Int? = nil
    
    // Keyboard state
    @State private var keyboardHeight: CGFloat = 0
    @State private var isKeyboardVisible: Bool = false
    @State private var contentSize: CGSize = .zero
    @State private var isPreparingForResponse: Bool = false
    
    // Drag gesture constants
    private let dismissThreshold: CGFloat = 100
    private let dragIndicatorHeight: CGFloat = 5
    private let dragIndicatorWidth: CGFloat = 36
    
    // Input field height estimation for positioning
    private let estimatedInputFieldHeight: CGFloat = 60
    
    let subType: NoteSubType // Update to use NoteSubType enum
    
    // Initial prompt to start the conversation
    init(initialPrompt: String = "今天遇到了哪些事，认识了哪些人？", subType: NoteSubType = .interactionRecord, onSave: @escaping (String) -> Void = { _ in }) {
        self._initialPrompt = State(initialValue: initialPrompt)
        self.subType = subType
        self.onSave = onSave
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Fixed top elements - these stay in place regardless of keyboard
                    VStack(spacing: 0) {
                        // Drag indicator
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: dragIndicatorWidth, height: dragIndicatorHeight)
                            .cornerRadius(dragIndicatorHeight / 2)
                            .padding(.top, 6)
                        
                        // Action buttons without the navigation bar
                        HStack {
                            Button("取消") {
                                dismiss()
                            }
                            .foregroundColor(.green)
                            
                            Spacer()
                            
                            Button("保存笔记") {
                                saveNote()
                            }
                            .foregroundColor(.green)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                    .zIndex(1) // Ensure header stays on top
                    .background(Color.primaryBackground)
                    
                    // Scrollable content area - this is what adjusts for keyboard
                    ZStack {
                        // Custom SocialBrainDialogView with binding to capture content
                        SocialBrainDialogView(initialPrompt: initialPrompt)
                            .environmentObject(noteManager)
                            .onPreferenceChange(NoteContentPreferenceKey.self) { value in
                                messageContent = value
                            }
                            .background(
                                GeometryReader { contentGeometry in
                                    Color.clear.preference(key: ContentSizePreferenceKey.self, value: contentGeometry.size)
                                }
                            )
                    }
                    .frame(maxHeight: .infinity)
                    // Remove the extra spacing between content and keyboard
                    .padding(.bottom, isKeyboardVisible ? keyboardHeight : 0)
                }
                .background(Color.primaryBackground)
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .offset(y: max(0, dragOffset))
                .frame(height: geometry.size.height * 0.93)
                .frame(maxWidth: .infinity)
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.5)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                // Dismiss keyboard first if it's showing
                                if isKeyboardVisible {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                } else {
                                    dragOffset = value.translation.height
                                }
                            }
                        }
                        .onEnded { value in
                            if dragOffset > dismissThreshold {
                                dismiss()
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .onTapGesture {
                    // Dismiss keyboard when tapping outside of text field
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onPreferenceChange(ContentSizePreferenceKey.self) { newSize in
                    contentSize = newSize
                }
                .transition(.move(edge: .bottom))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: keyboardHeight)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            setupKeyboardObservers()
            setupResponseObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
            removeResponseObservers()
        }
        .overlay {
            if showingMentionConfirmation {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        MentionConfirmationModal(
                            unmatchedMentions: unmatchedMentions,
                            onConfirm: {
                                showingMentionConfirmation = false
                                print("[SocialNoteModalView] ✅ User confirmed creation of new contacts: \(unmatchedMentions)")
                                saveNoteWithMentions(mentions: unmatchedMentions, alsoIncludeExisting: true)
                            },
                            onCancel: {
                                showingMentionConfirmation = false
                                print("[SocialNoteModalView] ❌ User cancelled creation of new contacts. Only relating to existing contacts: \(existingMentionedContacts)")
                                saveNoteWithMentions(mentions: [], alsoIncludeExisting: true)
                            }
                        )
                    }
            }
        }
    }
    
    private var safeAreaInsets: UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets ?? .zero
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
               let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
               let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
                
                let animationCurve = UIView.AnimationOptions(rawValue: curve)
                
                withAnimation(.easeOut(duration: duration)) {
                    // Use exact keyboard height without adjustment to eliminate gap
                    self.keyboardHeight = keyboardFrame.height
                    self.isKeyboardVisible = true
                    
                    // Scroll content to ensure visibility of input field
                    NotificationCenter.default.post(name: Notification.Name("KeyboardWillShow"), object: nil)
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
    
    private func setupResponseObservers() {
        NotificationCenter.default.addObserver(forName: Notification.Name("ReserveSpaceForResponse"), object: nil, queue: .main) { _ in
            // Immediate response without animation delay
            self.isPreparingForResponse = true
            
            // Reset after a reasonable time if no response arrives
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.isPreparingForResponse {
                    self.isPreparingForResponse = false
                }
            }
        }
        
        // Listen for extra space request for higher positioning
        NotificationCenter.default.addObserver(forName: Notification.Name("ReserveExtraSpaceForResponse"), object: nil, queue: .main) { _ in
            // Similar to regular space reservation but will position content higher
            self.isPreparingForResponse = true
            
            // Reset after a reasonable time if no response arrives
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.isPreparingForResponse {
                    self.isPreparingForResponse = false
                }
            }
        }
        
        // Listen for message addition to reset the preparation state
        NotificationCenter.default.addObserver(forName: Notification.Name("ScrollToNewestMessage"), object: nil, queue: .main) { _ in
            if self.isPreparingForResponse {
                self.isPreparingForResponse = false
            }
        }
        
        // Immediate response to direct scroll requests
        NotificationCenter.default.addObserver(forName: Notification.Name("ImmediateScrollToLatest"), object: nil, queue: .main) { _ in
            if self.isPreparingForResponse {
                self.isPreparingForResponse = false
            }
        }
        
        // Immediate response to high position scroll requests
        NotificationCenter.default.addObserver(forName: Notification.Name("ImmediateScrollToHighPosition"), object: nil, queue: .main) { _ in
            if self.isPreparingForResponse {
                self.isPreparingForResponse = false
            }
        }
    }
    
    private func removeResponseObservers() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("ReserveSpaceForResponse"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("ReserveExtraSpaceForResponse"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("ScrollToNewestMessage"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("ImmediateScrollToLatest"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("ImmediateScrollToHighPosition"), object: nil)
    }
    
    private func dismiss() {
        // Dismiss keyboard if visible
        if isKeyboardVisible {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func saveNote() {
        // Extract mentions from the content
        let mentions = extractMentions(from: messageContent)
        
        // Check which mentions already exist as contacts
        let existingContacts = mentions.compactMap { name -> String? in
            if let contact = ContactManager.shared.fetchContact(withName: name) {
                return name
            } else {
                return nil
            }
        }
        let unmatched = mentions.filter { !existingContacts.contains($0) }
        
        if !unmatched.isEmpty {
            unmatchedMentions = unmatched
            showingMentionConfirmation = true
            return
        } else {
            // All mentions exist, create note and relationships immediately
            Task {
                if !messageContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Use sample (type 0) for sample mode, regular (type 1) for non-sample mode
                    let noteType: NoteType = appModeManager.isSampleMode ? .sample : .regular
                    if let _ = await noteManager.createNoteWithMentions(content: messageContent, type: noteType, mentions: mentions) {
                        // Post notification to refresh contacts list so note counts are updated
                        NotificationCenter.default.post(name: Notification.Name("RefreshContactsList"), object: nil)
                        onSave(messageContent)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveNoteWithMentions(mentions: [String], alsoIncludeExisting: Bool = true) {
        let allMentions = alsoIncludeExisting ? mentions : []
        Task {
            // Use sample (type 0) for sample mode, regular (type 1) for non-sample mode
            let noteType: NoteType = appModeManager.isSampleMode ? .sample : .regular
            if let _ = await noteManager.createNoteWithMentions(content: messageContent, type: noteType, subType: subType.rawValue, mentions: allMentions) {
                // Post notification to refresh contacts list so note counts are updated
                NotificationCenter.default.post(name: Notification.Name("RefreshContactsList"), object: nil)
                onSave(messageContent)
                dismiss()
            }
        }
    }
    
    // Add extractMentions function
    private func extractMentions(from text: String) -> [String] {
        var mentions: [String] = []
        // Only match @(name) or #(name), where name does not contain parentheses
        let pattern = "[@#]\\(([^()]+)\\)"
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let results = regex?.matches(in: text, range: NSRange(location: 0, length: nsString.length)) ?? []
        for match in results {
            let mention = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            mentions.append(mention)
        }
        return mentions
    }
}

// Preference key to get content from SocialBrainDialogView
struct NoteContentPreferenceKey: PreferenceKey {
    static var defaultValue: String = ""
    
    static func reduce(value: inout String, nextValue: () -> String) {
        value = nextValue()
    }
}

// Preference key to track content size for dynamic layout adjustments
struct ContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// Extension to extract user messages from conversation
extension DialogMessage {
    static func extractUserMessages(from content: String) -> [String] {
        // This is a simple implementation that should be expanded
        // based on how messages are structured in the dialog
        let components = content.components(separatedBy: "\n")
        return components.filter { !$0.isEmpty }
    }
}

struct SocialNoteModalView_Previews: PreviewProvider {
    static var previews: some View {
        SocialNoteModalView()
            .environmentObject(NoteManager.shared)
    }
} 
