import SwiftUI
import UIKit

// Add this new view before SimpleNoteModalView
struct MentionConfirmationModal: View {
    let unmatchedMentions: [String]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("创建新联系人")
                .font(.headline)
                .padding(.top)
            
            Text("以下提及的联系人尚未创建，是否创建？")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ForEach(unmatchedMentions, id: \.self) { mention in
                Text(mention)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 20) {
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Button("创建") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom)
        }
        .frame(width: 300)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

// Add this class to maintain stable text view reference
class TextEditorState: ObservableObject {
    @Published var text: String = ""
    weak var textView: UITextView?
    
    func insertText(_ text: String, at position: Int) {
        guard let textView = textView else { return }
        
        // Get current text
        let currentText = textView.text ?? ""
        let nsText = currentText as NSString
        
        // Insert new text
        let newText = nsText.replacingCharacters(in: NSRange(location: position, length: 0), with: text)
        
        // Update both the text view and published text
        textView.text = newText
        self.text = newText
        
        // Update cursor position
        if let newPosition = textView.position(from: textView.beginningOfDocument, offset: position + text.count) {
            textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
        }
    }
}

// Add CircleSelectionView before SimpleNoteModalView
struct CircleSelectionView: View {
    let onSelect: (Circle) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appModeManager: AppModeManager
    @StateObject private var circleManager = CircleManager.shared
    @State private var circles: [Circle] = []
    @State private var searchText = ""
    
    var filteredCircles: [Circle] {
        if searchText.isEmpty {
            return circles
        }
        return circles.filter { circle in
            guard let name = circle.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredCircles, id: \.circleId) { circle in
                    Button(action: {
                        onSelect(circle)
                        dismiss()
                    }) {
                        HStack {
                            Text(circle.name ?? "圈子")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    }
                }
            }
            .navigationTitle("选择圈子")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索圈子")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            // Filter circles based on app mode
            if appModeManager.isSampleMode {
                // In sample mode, only show type=0 circles
                circles = circleManager.fetchCircles(byType: 0)
            } else {
                // In regular mode, only show type!=0 circles
                let allCircles = circleManager.fetchCircles()
                circles = allCircles.filter { $0.type != 0 }
            }
        }
        .onChange(of: appModeManager.isSampleMode) { _ in
            // Refresh circles when sample mode changes
            if appModeManager.isSampleMode {
                circles = circleManager.fetchCircles(byType: 0)
            } else {
                let allCircles = circleManager.fetchCircles()
                circles = allCircles.filter { $0.type != 0 }
            }
        }
    }
}

// Add NoteSubType enum before SimpleNoteModalView
enum NoteSubType: Int16 {
    case interactionRecord = 1  // 互动记录
    case topicCollection = 2    // 话题库
    
    var displayName: String {
        switch self {
        case .interactionRecord:
            return "互动记录"
        case .topicCollection:
            return "话题库"
        }
    }
}

struct SimpleNoteModalView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var noteManager: NoteManager
    @EnvironmentObject var appModeManager: AppModeManager
    
    let initialText: String
    let onSave: (String) -> Void
    let noteId: UUID?
    let subType: NoteSubType
    let modalTitle: String
    
    @StateObject private var textState = TextEditorState()
    @State private var textEditorHeight: CGFloat = 100
    @State private var showingKeyboard: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showingContactSelection = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingCircleSelection = false
    
    private let maxTextEditorHeight: CGFloat = UIScreen.main.bounds.height * 0.4
    private let backgroundOpacity: Double = 0.6
    
    @State private var unmatchedMentions: [String] = []
    @State private var showingMentionConfirmation = false
    @State private var isSaving = false
    
    init(initialText: String, noteId: UUID? = nil, subType: NoteSubType = .interactionRecord, modalTitle: String = "新建想法", onSave: @escaping (String) -> Void) {
        self.initialText = initialText
        self.noteId = noteId
        self.subType = subType
        self.modalTitle = modalTitle
        self.onSave = onSave
        _textState = StateObject(wrappedValue: TextEditorState())
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent overlay
                Color.black.opacity(backgroundOpacity)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        dismiss()
                    }
                
                VStack(spacing: 0) {
                    // Main content area
                    VStack(spacing: 0) {
                        // Navigation bar
                        NavigationView {
                            VStack(spacing: 0) {
                                // Text editor container
                                ZStack(alignment: .topLeading) {
                                    Color(.systemBackground)
                                    
                                    // Text editor
                                    TextViewWrapper(state: textState, isFirstResponder: true, onDone: {})
                                        .frame(maxHeight: .infinity)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .onChange(of: textState.text) { newValue in
                                            let estimatedHeight = newValue.isEmpty ? 100 : min(newValue.height(width: UIScreen.main.bounds.width - 32, font: .systemFont(ofSize: 17)), maxTextEditorHeight)
                                            textEditorHeight = max(100, estimatedHeight)
                                        }
                                    
                                    // Placeholder text with matching font size
                                    if textState.text.isEmpty {
                                        Text(subType == .topicCollection ? "记录话题想法" : "记录社交笔记")
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .frame(maxHeight: .infinity)
                            }
                            .navigationTitle(modalTitle)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("取消") {
                                        dismiss()
                                    }
                                    .foregroundColor(.green)
                                }
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("保存") {
                                        saveNote()
                                    }
                                    .disabled(textState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .foregroundColor(textState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .green)
                                }
                            }
                        }
                        .navigationViewStyle(.stack)
                        
                        // Bottom action bar
                        VStack(spacing: 0) {
                            Divider()
                            
                            HStack(spacing: 0) {
                                Button(action: {
                                    showingContactSelection = true
                                }) {
                                    Text("@熟人")
                                        .font(.system(size: 17))
                                        .foregroundColor(.green)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44) // Standard iOS button height
                                }
                                
                                Divider()
                                    .frame(height: 24)
                                    .padding(.vertical, 10)
                                
                                Button(action: {
                                    showingCircleSelection = true
                                }) {
                                    Text("# 圈子")
                                        .font(.system(size: 17))
                                        .foregroundColor(.green)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44) // Standard iOS button height
                                }
                            }
                            .background(Color(.systemBackground))
                        }
                        .background(Color(.systemBackground))
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                }
                .frame(maxWidth: .infinity, maxHeight: geometry.size.height - (showingKeyboard ? keyboardHeight : 0))
                .position(x: geometry.size.width / 2, y: (geometry.size.height - (showingKeyboard ? keyboardHeight : 0)) / 2)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            textState.text = initialText
            setupKeyboardObservers()
            // Force keyboard to appear with multiple attempts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                forceShowKeyboard()
                // Additional attempt after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    forceShowKeyboard()
                }
            }
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .onChange(of: showingContactSelection) { isShowing in
            // Contact selection sheet state changed
        }
        .sheet(isPresented: $showingContactSelection) {
            ContactSelectionView { contact in
                insertContactMention(contact)
            }
            .environmentObject(appModeManager)
        }
        .sheet(isPresented: $showingCircleSelection) {
            CircleSelectionView { circle in
                insertCircleMention(circle)
            }
            .environmentObject(appModeManager)
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
                                saveNoteWithMentions(mentions: unmatchedMentions, alsoIncludeExisting: true)
                            },
                            onCancel: {
                                showingMentionConfirmation = false
                                saveNoteWithMentions(mentions: [], alsoIncludeExisting: true)
                            }
                        )
                    }
            }
        }
    }
    
    private func forceShowKeyboard() {
        isTextFieldFocused = true
        textState.textView?.becomeFirstResponder()
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self.keyboardHeight = keyboardFrame.height
                self.showingKeyboard = true
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            self.keyboardHeight = 0
            self.showingKeyboard = false
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func dismiss() {
        isTextFieldFocused = false
        textState.textView?.resignFirstResponder()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // Extracts mentions as (type, name) tuples
    private func extractMentionsWithType(from text: String) -> [(type: String, name: String)] {
        var mentions: [(String, String)] = []
        let pattern = "([@#])\\(([^()]+)\\)"
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let results = regex?.matches(in: text, range: NSRange(location: 0, length: nsString.length)) ?? []
        for match in results {
            let symbol = nsString.substring(with: match.range(at: 1))
            let name = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            let type = symbol == "@" ? "contact" : "circle"
            mentions.append((type, name))
        }
        return mentions
    }

    private func extractMentions(from text: String) -> [String] {
        // For compatibility with existing code, but not used for unmatched logic anymore
        return extractMentionsWithType(from: text).map { $0.name }
    }
    
    private func saveNote() {
        if let noteId = noteId {
            // Update existing note
            if !textState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if noteManager.updateNote(noteId: noteId, text: textState.text) {
                    // Post notification to refresh contacts list so note counts are updated
                    NotificationCenter.default.post(name: Notification.Name("RefreshContactsList"), object: nil)
                    onSave(textState.text)
                    dismiss()
                }
            }
        } else {
            // Create new note with mentions
            let mentionsWithType = extractMentionsWithType(from: textState.text)
            var unmatchedContacts: [String] = []
            var unmatchedCircles: [String] = []
            for (type, name) in mentionsWithType {
                if type == "contact" {
                    if ContactManager.shared.fetchContact(withName: name) == nil {
                        unmatchedContacts.append(name)
                    }
                } else if type == "circle" {
                    if CircleManager.shared.fetchCircle(withName: name) == nil {
                        unmatchedCircles.append(name)
                    }
                }
            }
            let unmatched = unmatchedContacts + unmatchedCircles
            if !unmatched.isEmpty {
                unmatchedMentions = unmatched
                showingMentionConfirmation = true
                return
            } else {
                saveNoteWithMentions(mentions: mentionsWithType.map { $0.name })
            }
        }
    }
    
    private func saveNoteWithMentions(mentions: [String], alsoIncludeExisting: Bool = true) {
        let allMentions = alsoIncludeExisting ? mentions : []
        Task {
            // Use sample (type 0) for sample mode, regular (type 1) for non-sample mode
            let noteType: NoteType = appModeManager.isSampleMode ? .sample : .regular
            
            if let _ = await noteManager.createNoteWithMentions(content: textState.text, type: noteType, subType: subType.rawValue, mentions: allMentions) {
                // Post notification to refresh contacts list so note counts are updated
                NotificationCenter.default.post(name: Notification.Name("RefreshContactsList"), object: nil)
                onSave(textState.text)
                dismiss()
            }
        }
    }
    
    private func insertContactMention(_ contact: Contact) {
        guard let name = contact.name else { return }
        
        if let textView = textState.textView,
           let selectedRange = textView.selectedTextRange {
            var currentText = textView.text ?? ""
            var cursorPosition = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)

            // Remove whitespace before cursor
            while cursorPosition > 0 && currentText[currentText.index(currentText.startIndex, offsetBy: cursorPosition - 1)].isWhitespace {
                currentText.remove(at: currentText.index(currentText.startIndex, offsetBy: cursorPosition - 1))
                cursorPosition -= 1
            }
            // Remove whitespace after cursor
            while cursorPosition < currentText.count && currentText[currentText.index(currentText.startIndex, offsetBy: cursorPosition)].isWhitespace {
                currentText.remove(at: currentText.index(currentText.startIndex, offsetBy: cursorPosition))
            }

            // Insert mention with parentheses to support names with spaces
            let mention = " @(\(name)) "
            let nsText = currentText as NSString
            let newText = nsText.replacingCharacters(in: NSRange(location: cursorPosition, length: 0), with: mention)
            textView.text = newText
            textState.text = newText

            // Move cursor to after the mention
            if let newPosition = textView.position(from: textView.beginningOfDocument, offset: cursorPosition + mention.count) {
                textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
            }
        }
    }
    
    // Add new function for circle mentions
    private func insertCircleMention(_ circle: Circle) {
        guard let name = circle.name else { return }
        
        if let textView = textState.textView,
           let selectedRange = textView.selectedTextRange {
            var currentText = textView.text ?? ""
            var cursorPosition = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)

            // Remove whitespace before cursor
            while cursorPosition > 0 && currentText[currentText.index(currentText.startIndex, offsetBy: cursorPosition - 1)].isWhitespace {
                currentText.remove(at: currentText.index(currentText.startIndex, offsetBy: cursorPosition - 1))
                cursorPosition -= 1
            }
            // Remove whitespace after cursor
            while cursorPosition < currentText.count && currentText[currentText.index(currentText.startIndex, offsetBy: cursorPosition)].isWhitespace {
                currentText.remove(at: currentText.index(currentText.startIndex, offsetBy: cursorPosition))
            }

            // Insert mention with parentheses to support names with spaces
            let mention = " #(\(name)) "
            let nsText = currentText as NSString
            let newText = nsText.replacingCharacters(in: NSRange(location: cursorPosition, length: 0), with: mention)
            textView.text = newText
            textState.text = newText

            // Move cursor to after the mention
            if let newPosition = textView.position(from: textView.beginningOfDocument, offset: cursorPosition + mention.count) {
                textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
            }
        }
    }
    
    // Add test function to verify mention detection
    private func testMentionDetection() {
        let testText = "Hello @(John Smith) and #(技术圈) with @张三 and #产品组"
        let mentions = extractMentions(from: testText)
        print("Test mentions: \(mentions)")
        // Should print: ["John Smith", "技术圈", "张三", "产品组"]
    }
}

struct TextViewWrapper: UIViewRepresentable {
    @ObservedObject var state: TextEditorState
    var isFirstResponder: Bool = false
    var onDone: () -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        // Match text size with SocialNoteDetailView
        textView.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = true
        textView.autocorrectionType = .yes
        textView.returnKeyType = .default
        textView.text = state.text
        
        // Configure input accessory view to prevent constraint conflicts
        let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0))
        accessoryView.backgroundColor = .clear
        accessoryView.isUserInteractionEnabled = false
        accessoryView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        textView.inputAccessoryView = accessoryView
        
        // Disable the system input assistant view completely to prevent constraint conflicts
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []
        
        // Keep all smart text features enabled for better Chinese input support
        // Don't disable any features that might interfere with input methods
        textView.smartDashesType = .yes
        textView.smartQuotesType = .yes
        textView.smartInsertDeleteType = .yes
        
        // Set proper content insets to avoid overlap with keyboard
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
        
        // Store reference
        state.textView = textView
        
        // Ensure keyboard appears immediately
        DispatchQueue.main.async {
            textView.becomeFirstResponder()
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if text is different and avoid constant attributed text updates
        if uiView.text != state.text {
            let selectedRange = uiView.selectedTextRange
            uiView.text = state.text
            if let selectedRange = selectedRange {
                uiView.selectedTextRange = selectedRange
            }
        }
        // Update reference if needed
        if state.textView !== uiView {
            state.textView = uiView
        }
        // Maintain focus
        if isFirstResponder && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(state: state, onDone: onDone)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @ObservedObject var state: TextEditorState
        var onDone: () -> Void
        
        init(state: TextEditorState, onDone: @escaping () -> Void) {
            self.state = state
            self.onDone = onDone
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // Simply update the state text without manipulating attributed text
            // This prevents interference with Chinese input methods
            state.text = textView.text
        }
    }
}

// Helper struct for UIBlurEffect
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// String extension to calculate height
extension String {
    func height(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, 
                                         options: .usesLineFragmentOrigin, 
                                         attributes: [.font: font], 
                                         context: nil)
        return boundingBox.height + 40 // Add padding
    }
}

struct SimpleNoteModalView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleNoteModalView(initialText: "Test note", subType: .interactionRecord, modalTitle: "记录互动") { _ in }
            .environmentObject(NoteManager.shared)
    }
} 
