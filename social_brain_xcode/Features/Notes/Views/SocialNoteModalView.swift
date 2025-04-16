import SwiftUI

struct SocialNoteModalView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var noteManager: NoteManager
    @State private var dragOffset: CGFloat = 0
    @State private var messageContent: String = "今天遇到了哪些事"
    @State private var initialPrompt: String
    
    // Reference to the dialog view
    @State private var isShowingDialog: Bool = true
    @State private var selectedMessageIndex: Int? = nil
    
    // Drag gesture constants
    private let dismissThreshold: CGFloat = 100
    private let dragIndicatorHeight: CGFloat = 5
    private let dragIndicatorWidth: CGFloat = 36
    
    // Initial prompt to start the conversation
    init(initialPrompt: String = "今天遇到了哪些事") {
        self._initialPrompt = State(initialValue: initialPrompt)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Drag indicator
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: dragIndicatorWidth, height: dragIndicatorHeight)
                    .cornerRadius(dragIndicatorHeight / 2)
                    .padding(.top, 10)
                
                // Action buttons without the navigation bar
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveNote()
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                // Custom SocialBrainDialogView with binding to capture content
                SocialBrainDialogView(initialPrompt: initialPrompt)
                    .environmentObject(noteManager)
                    .onPreferenceChange(NoteContentPreferenceKey.self) { value in
                        messageContent = value
                    }
                
                Spacer()
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
                            dragOffset = value.translation.height
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
            .transition(.move(edge: .bottom))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
        }
        .ignoresSafeArea()
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func saveNote() {
        // Extract note content from the conversation
        let userMessages = DialogMessage.extractUserMessages(from: messageContent)
        let noteContent = userMessages.joined(separator: "\n\n")
        
        // Create a new note using the NoteManager
        if !noteContent.isEmpty {
            noteManager.createNote(content: noteContent, type: .social)
        } else {
            // Fallback if no user messages found
            noteManager.createNote(content: "New note", type: .general)
        }
        
        // Dismiss the modal
        dismiss()
    }
}

// Preference key to get content from SocialBrainDialogView
struct NoteContentPreferenceKey: PreferenceKey {
    static var defaultValue: String = ""
    
    static func reduce(value: inout String, nextValue: () -> String) {
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
            .environmentObject(LocalizationManager())
    }
} 
