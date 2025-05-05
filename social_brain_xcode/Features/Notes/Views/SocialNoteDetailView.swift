import SwiftUI
import CoreData

struct SocialNoteDetailView: View {
    let note: Note
    @State private var aiSuggestions: [AISuggestion] = []
    @State private var isLoadingSuggestions: Bool = true
    @State private var showingEditModal: Bool = false
    @State private var showingArchiveConfirmation: Bool = false
    @State private var scrollResetID = UUID()
    @State private var shouldScrollToTop = false
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var noteManager: NoteManager
    
    // Add namespace for scroll position control
    private let topID = "top"
    
    var body: some View {
        ZStack {
            // Background color for the entire screen
            Color.primaryBackground
                .ignoresSafeArea()
            
            // Content area
            VStack(spacing: 0) {
                // Scrollable content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Add an anchor view at the top
                            Color.clear
                                .frame(height: 0)
                                .id(topID)
                            
                            // Note content section with padding
                            VStack(alignment: .leading) {
                                noteDetailSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            
                            // Full-width divider (12pt height, edge-to-edge)
                            Color(.systemGray5)
                                .frame(height: 12)
                                .padding(.vertical, 8)
                            
                            // AI Suggestions section with padding
                            VStack(alignment: .leading) {
                                aiSuggestionsSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            
                            // Extra bottom padding to ensure content isn't covered by the bottom toolbar
                            Spacer(minLength: 80)
                        }
                        .padding(.top, 16)
                    }
                    .id(scrollResetID)
                    .onChange(of: shouldScrollToTop) { newValue in
                        guard newValue else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation {
                                proxy.scrollTo(topID, anchor: .top)
                            }
                        }
                    }
                }
                
                // Fixed bottom toolbar that respects safe areas
                VStack(spacing: 0) {
                    Divider()
                    
                    // Bottom toolbar content
                    HStack(spacing: 0) {
                        // Archive button
                        Button(action: {
                            showingArchiveConfirmation = true
                        }) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // AI button
                        Button(action: {
                            // AI action
                        }) {
                            Image(systemName: "brain")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Edit button
                        Button(action: {
                            showingEditModal = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 44)
                    .padding(.bottom, safeAreaPadding)
                }
                .background(
                    VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                        .ignoresSafeArea()
                )
            }
        }
        .navigationBarTitle(formattedTimestamp(date: note.createdAt ?? Date()), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .onAppear {
            loadAISuggestions()
            // Hide the tab bar
            hideTabBar(true)
        }
        .onDisappear {
            // Show the tab bar again when leaving this view
            hideTabBar(false)
        }
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $showingEditModal) {
            // Present the EditNoteModalView with existing note content
            EditNoteModalView(initialText: note.content ?? "", noteId: note.noteId ?? UUID())
        }
        .alert(isPresented: $showingArchiveConfirmation) {
            Alert(
                title: Text("归档笔记"),
                message: Text("确定要归档这条笔记吗？归档后可以在归档列表中查看。"),
                primaryButton: .destructive(Text("归档")) {
                    guard let noteId = note.noteId else { return }
                    if noteManager.archiveNote(noteId: noteId) {
                        // Post notification to refresh the notes list
                        NotificationCenter.default.post(name: Notification.Name("RefreshNotesList"), object: nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .refreshable {
            await refreshSuggestions()
            scrollResetID = UUID()
            shouldScrollToTop = true
        }
        .onChange(of: scrollResetID) { _ in
            shouldScrollToTop = false
        }
    }
    
    // Dynamic safe area padding for different devices
    private var safeAreaPadding: CGFloat {
        // Get the bottom safe area inset
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
            
        let bottomInset = keyWindow?.safeAreaInsets.bottom ?? 0
        
        // Add padding based on whether device has home indicator
        return bottomInset > 0 ? bottomInset + 8 : 8
    }
    
    // UIViewRepresentable wrapper for UIVisualEffectView to use blur effects
    struct VisualEffectView: UIViewRepresentable {
        var effect: UIVisualEffect?
        
        func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
            UIVisualEffectView()
        }
        
        func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
            uiView.effect = effect
        }
    }
    
    // Function to hide/show the tab bar
    private func hideTabBar(_ hidden: Bool) {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
            
        if let keyWindow = keyWindow {
            keyWindow.rootViewController?.children.forEach { child in
                // Find the UITabBarController and hide its tabBar
                if let tabBarController = child as? UITabBarController {
                    tabBarController.tabBar.isHidden = hidden
                }
            }
        }
    }
    
    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left")
                .foregroundColor(.accentColor)
                .imageScale(.large)
                .accessibilityLabel("返回")
        }
    }
    
    private var noteDetailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MentionTextView(text: note.content ?? "")
                .font(.body)
                .foregroundColor(.primaryText)
                .lineSpacing(4)
            
            // Show contacts if available
            mentionsView
        }
        .padding(.bottom, 8)
    }
    
    // Helper to display contact mentions
    private var mentionsView: some View {
        Group {
            if let contacts = getContactsForNote(), !contacts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("提及的联系人")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    HStack {
                        ForEach(contacts, id: \.contactId) { contact in
                            Text(contact.name ?? "Unnamed")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.primaryAction.opacity(0.15))
                                )
                                .foregroundColor(.primaryAction)
                        }
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // Helper function to get contacts for the note
    private func getContactsForNote() -> [Contact]? {
        guard let relationships = note.contacts as? Set<NoteContactRelationship> else {
            return nil
        }
        
        return relationships.compactMap { $0.contacts }
    }
    
    private var aiSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 建议")
                .font(.headline)
                .foregroundColor(.primaryText)
                .padding(.bottom, 4)
            
            if isLoadingSuggestions {
                loadingCard
            } else if aiSuggestions.isEmpty {
                noSuggestionsCard
            } else {
                ForEach(aiSuggestions) { suggestion in
                    suggestionCard(suggestion: suggestion)
                }
            }
        }
    }
    
    private var loadingCard: some View {
        HStack {
            ProgressView()
                .padding(.trailing, 8)
            Text("正在加载建议...")
                .font(.body)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.divider, lineWidth: 0.5)
        )
        .shadow(color: Color.primaryText.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var noSuggestionsCard: some View {
        Text("暂无此笔记的建议，请稍后再试。")
            .font(.body)
            .foregroundColor(.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.divider, lineWidth: 0.5)
            )
            .shadow(color: Color.primaryText.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func suggestionCard(suggestion: AISuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(suggestion.content)
                .font(.body)
                .foregroundColor(.primaryText)
                .lineSpacing(4)
            
            // Custom divider with same specifications as the main one
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 2)
                .padding(.vertical, 8)
            
            // Centered button container
            HStack {
                Spacer()
                Button("查看笔记") {
                    // Handle view note action
                }
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.accentColor)
                Spacer()
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.divider, lineWidth: 0.5)
        )
        .shadow(color: Color.primaryText.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formattedTimestamp(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func loadAISuggestions() {
        isLoadingSuggestions = true
        
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.aiSuggestions = AISuggestion.mockSuggestions
            self.isLoadingSuggestions = false
        }
    }
    
    private func refreshSuggestions() async {
        isLoadingSuggestions = true
        
        // Simulate network request with async/await
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Update on main thread
        await MainActor.run {
            aiSuggestions = AISuggestion.mockSuggestions
            isLoadingSuggestions = false
        }
    }
}

// Model for AI Suggestions
struct AISuggestion: Identifiable {
    let id = UUID()
    let content: String
    let type: SuggestionType
    
    enum SuggestionType {
        case followUp
        case topicIdea
        case insightful
    }
    
    static var mockSuggestions: [AISuggestion] {
        [
            AISuggestion(content: "基于你们之前的对话，你可能想要跟进他们下周的新项目发布会。", type: .followUp),
            AISuggestion(content: "这个人提到喜欢徒步旅行。考虑讨论户外活动作为潜在的对话话题。", type: .topicIdea),
            AISuggestion(content: "你本月已经在三个不同的活动中遇到了这个人。考虑通过一对一会面来加强这种关系。", type: .insightful)
        ]
    }
}

// Updated preview to use CoreData
struct SocialNoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.viewContext
        let note = Note(context: context)
        note.noteId = UUID()
        note.content = "Sample note content with @Contact mention"
        note.createdAt = Date()
        
        return NavigationView {
            SocialNoteDetailView(note: note)
        }
        .environment(\.colorScheme, .light)
        .environmentObject(NoteManager.shared)
    }
}

// Add this new view for editing existing notes
struct EditNoteModalView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var noteManager: NoteManager
    
    let initialText: String
    let noteId: UUID
    
    @State private var noteText: String
    @State private var textEditorHeight: CGFloat = 100
    @State private var showingKeyboard: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    
    private let maxTextEditorHeight: CGFloat = UIScreen.main.bounds.height * 0.4
    private let backgroundOpacity: Double = 0.6
    
    // Reference to text editor for direct keyboard focus
    @State private var textEditorRef: UITextView?
    
    // Initialize with the existing note content
    init(initialText: String, noteId: UUID) {
        self.initialText = initialText
        self.noteId = noteId
        self._noteText = State(initialValue: initialText)
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
            // Update the existing note instead of creating a new one
            noteManager.updateNote(noteId: noteId, text: noteText)
        }
        dismiss()
    }
} 
