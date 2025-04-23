import SwiftUI
import UIKit

struct SimpleNoteModalView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var noteManager: NoteManager
    
    @State private var noteText: String = ""
    @State private var textEditorHeight: CGFloat = 100
    @State private var showingKeyboard: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    
    private let maxTextEditorHeight: CGFloat = UIScreen.main.bounds.height * 0.4
    private let backgroundOpacity: Double = 0.6
    
    // Reference to text editor for direct keyboard focus
    @State private var textEditorRef: UITextView?
    
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
                    
                    // Text editor - using a minimalist style
                    ZStack(alignment: .topLeading) {
                        // Use ZStack to place custom background behind TextEditor
                        Color(.systemBackground)
                            .frame(height: min(textEditorHeight, maxTextEditorHeight))
                        
                        // Custom UITextView for immediate focus
                        TextViewWrapper(text: $noteText, isFirstResponder: true, onDone: {
                            // This is now only used for custom completion, not for return key
                        }, textEditorRef: $textEditorRef)
                            .frame(height: min(textEditorHeight, maxTextEditorHeight))
                            .onChange(of: noteText) { newValue in
                                // Calculate new height based on text content
                                let estimatedHeight = newValue.isEmpty ? 100 : min(newValue.height(width: UIScreen.main.bounds.width * 0.9, font: .systemFont(ofSize: 17)), maxTextEditorHeight)
                                textEditorHeight = max(100, estimatedHeight)
                            }
                        
                        if noteText.isEmpty {
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
                    
                    // Action buttons - matched to screenshot
                    HStack(spacing: 0) {
                        Button(action: {
                            // Add contact action
                        }) {
                            Text("添加联系人")
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
            setupKeyboardObservers()
            // Force keyboard to show immediately
            forceShowKeyboard()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }
    
    private func forceShowKeyboard() {
        // Multiple approaches to ensure keyboard appears
        isTextFieldFocused = true
        
        // Force UIKit keyboard to appear
        DispatchQueue.main.async {
            self.textEditorRef?.becomeFirstResponder()
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
        textEditorRef?.resignFirstResponder()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func saveNote() {
        if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            noteManager.createNote(content: noteText, type: .social)
        }
        dismiss()
    }
}

// UITextView wrapper to ensure immediate keyboard focus
struct TextViewWrapper: UIViewRepresentable {
    @Binding var text: String
    var isFirstResponder: Bool = false
    var onDone: () -> Void
    @Binding var textEditorRef: UITextView?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = true
        textView.autocorrectionType = .yes
        textView.returnKeyType = .default
        
        // Store reference to directly access later
        self.textEditorRef = textView
        
        // Force focus immediately
        if isFirstResponder {
            textView.becomeFirstResponder()
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        
        // Ensure focus is maintained
        if isFirstResponder && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onDone: onDone)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var onDone: () -> Void
        
        init(text: Binding<String>, onDone: @escaping () -> Void) {
            self._text = text
            self.onDone = onDone
        }
        
        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Remove the special handling for return key to allow line breaks
            return true
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
        SimpleNoteModalView()
            .environmentObject(NoteManager.shared)
    }
} 