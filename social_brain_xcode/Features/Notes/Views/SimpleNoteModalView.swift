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

struct SimpleNoteModalView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var noteManager: NoteManager
    
    let initialText: String
    let onSave: (String) -> Void
    
    @StateObject private var textState = TextEditorState()
    @State private var textEditorHeight: CGFloat = 100
    @State private var showingKeyboard: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showingContactSelection = false
    @FocusState private var isTextFieldFocused: Bool
    
    private let maxTextEditorHeight: CGFloat = UIScreen.main.bounds.height * 0.4
    private let backgroundOpacity: Double = 0.6
    
    @State private var unmatchedMentions: [String] = []
    @State private var showingMentionConfirmation = false
    @State private var isSaving = false
    
    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.initialText = initialText
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
                
                // Modal content
                VStack(spacing: 0) {
                    // Drag indicator
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    
                    // Text editor
                    ZStack(alignment: .topLeading) {
                        Color(.systemBackground)
                            .frame(height: min(textEditorHeight, maxTextEditorHeight))
                        
                        TextViewWrapper(state: textState, isFirstResponder: true, onDone: {})
                            .frame(height: min(textEditorHeight, maxTextEditorHeight))
                            .onChange(of: textState.text) { newValue in
                                let estimatedHeight = newValue.isEmpty ? 100 : min(newValue.height(width: UIScreen.main.bounds.width * 0.9, font: .systemFont(ofSize: 17)), maxTextEditorHeight)
                                textEditorHeight = max(100, estimatedHeight)
                            }
                        
                        if textState.text.isEmpty {
                            Text("现在的想法是...")
                                .font(.system(size: 17))
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    Divider()
                        .padding(.horizontal, 0)
                    
                    // Action buttons
                    HStack(spacing: 0) {
                        Button(action: {
                            showingContactSelection = true
                        }) {
                            Text("@熟人")
                                .font(.system(size: 17))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                        }
                        
                        Text("添加标签")
                            .font(.system(size: 17))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                // Add tag action
                            }
                        
                        Button(action: {
                            saveNote()
                        }) {
                            Text("保存")
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 40)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: geometry.size.height - (showingKeyboard ? keyboardHeight : 0))
                .background(Color(.systemBackground))
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .edgesIgnoringSafeArea(.bottom)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height > 20 {
                                dismiss()
                            }
                        }
                )
                .position(x: geometry.size.width / 2, y: (geometry.size.height - (showingKeyboard ? keyboardHeight : 0)) / 2)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            textState.text = initialText
            setupKeyboardObservers()
            forceShowKeyboard()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .onChange(of: showingContactSelection) { isShowing in
            if isShowing {
                print("\n[SimpleNoteModalView] 📱 Showing contact selection sheet")
            }
        }
        .sheet(isPresented: $showingContactSelection) {
            ContactSelectionView { contact in
                insertContactMention(contact)
            }
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
                                saveNoteWithMentions(mentions: unmatchedMentions)
                            },
                            onCancel: {
                                showingMentionConfirmation = false
                                saveNoteWithMentions(mentions: [])
                            }
                        )
                    }
            }
        }
    }
    
    private func forceShowKeyboard() {
        // Multiple approaches to ensure keyboard appears
        isTextFieldFocused = true
        
        // Force UIKit keyboard to appear
        DispatchQueue.main.async {
            self.textState.textView?.becomeFirstResponder()
        }
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
    
    private func saveNote() {
        guard !textState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSaving = true
        onSave(textState.text)
        isSaving = false
        dismiss()
    }
    
    private func extractMentions(from text: String) -> [String] {
        // Match @ followed by one or more of: Chinese, English, numbers, underscore, hyphen, full-width parenthesis
        // Stop at whitespace or common punctuation
        let pattern = "@([\\u4e00-\\u9fa5A-Za-z0-9_\\-（）()]+)"
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let results = regex?.matches(in: text, range: NSRange(location: 0, length: nsString.length)) ?? []
        
        return results.map { match in
            return nsString.substring(with: match.range(at: 1))
        }
    }
    
    private func saveNoteWithMentions(mentions: [String]) {
        isSaving = true
        
        Task {
            // Create note with mentions directly
            if let _ = await noteManager.createNoteWithMentions(content: textState.text, type: .social, mentions: mentions) {
                isSaving = false
                dismiss()
            } else {
                isSaving = false
                // TODO: Show error alert
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

            // Insert mention with exactly one space on both sides
            let mention = " @\(name) "
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
}

struct TextViewWrapper: UIViewRepresentable {
    @ObservedObject var state: TextEditorState
    var isFirstResponder: Bool = false
    var onDone: () -> Void
    
    func makeUIView(context: Context) -> UITextView {
        print("\n[TextViewWrapper] 📝 Creating UITextView")
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = true
        textView.autocorrectionType = .yes
        textView.returnKeyType = .default
        textView.text = state.text
        
        // Store reference
        state.textView = textView
        
        if isFirstResponder {
            textView.becomeFirstResponder()
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if text is different
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
        SimpleNoteModalView(initialText: "Test note") { _ in }
            .environmentObject(NoteManager.shared)
    }
} 

