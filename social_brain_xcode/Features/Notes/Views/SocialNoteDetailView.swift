import SwiftUI
import CoreData

struct SocialNoteDetailView: View {
    let note: Note
    @State private var showingEditModal: Bool = false
    @State private var showingArchiveConfirmation: Bool = false
    @State private var scrollResetID = UUID()
    @State private var shouldScrollToTop = false
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var noteManager: NoteManager
    @StateObject private var insightManager = ContactInsightManager.shared
    @State private var contactInsights: [ContactInsight] = []
    @State private var isLoadingInsights = true
    @State private var showingSocialBrain = false
    @State private var editingNoteText: String = ""
    
    // Add namespace for scroll position control
    private let topID = "top"
    
    // Keep state for tracking scroll position but remove debug logging
    @State private var scrollOffset: CGFloat = 0
    @State private var isScrolling = false
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    private let dragThreshold: CGFloat = 100
    
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
                        GeometryReader { geometry in
                            Color.clear.preference(key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scrollView")).minY)
                        }
                        .frame(height: 0)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            // Note details section (content only)
                            VStack(alignment: .leading, spacing: 16) {
                                MentionTextView(text: note.content ?? "")
                                    .textSelection(.enabled)
                                    .font(.body)
                                    .foregroundColor(.primaryText)
                                    .lineSpacing(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            // Extra bottom padding to ensure content isn't covered by the bottom toolbar
                            Spacer(minLength: 80)
                        }
                    }
                    .coordinateSpace(name: "scrollView")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                        isScrolling = true
                        // Reset scrolling state after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isScrolling = false
                        }
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
                    // Add gesture for slide back
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                // Only allow horizontal drag from the left edge
                                if gesture.startLocation.x < 50 && gesture.translation.width > 0 {
                                    isDragging = true
                                    dragOffset = gesture.translation.width
                                }
                            }
                            .onEnded { gesture in
                                isDragging = false
                                if gesture.translation.width > dragThreshold {
                                    withAnimation(.interactiveSpring()) {
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                } else {
                                    withAnimation(.interactiveSpring()) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                }
                .scrollIndicators(.hidden)
                .offset(x: dragOffset)
                .animation(.interactiveSpring(), value: dragOffset)
                
                // Fixed bottom toolbar that respects safe areas
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 0) {
                        // Archive button
                        Button(action: {
                            showingArchiveConfirmation = true
                        }) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 22))
                                .foregroundColor(.primaryText)
                                .frame(maxWidth: .infinity)
                        }
                        // Edit Note button
                        Button(action: {
                            // Set the text before showing the modal
                            editingNoteText = note.content ?? ""
                            // Use async to ensure state is updated before showing modal
                            DispatchQueue.main.async {
                                showingEditModal = true
                            }
                        }) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 22))
                                .foregroundColor(.primaryText)
                                .frame(maxWidth: .infinity)
                        }
                        // AI button
                        Button(action: {
                            showingSocialBrain = true
                        }) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 22))
                                .foregroundColor(.primaryText)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 44)
                    .padding(.vertical, 8)
                    .padding(.bottom, safeAreaPadding)
                }
                .background(
                    Color.primaryBackground
                        .edgesIgnoringSafeArea(.bottom)
                )
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.separator))
                        .opacity(0.5),
                    alignment: .top
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(formattedTimestamp(date: note.createdAt ?? Date()))
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
        .navigationBarBackButtonHidden(true)
        // Add these modifiers to ensure proper navigation bar behavior
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.primaryBackground, for: .navigationBar)
        // Add visual feedback during drag
        .overlay(
            Group {
                if isDragging {
                    Color.black.opacity(0.1 * min(dragOffset / dragThreshold, 1))
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
        )
        .onAppear {
            loadContactInsights()
            hideTabBar(true)
        }
        .onDisappear {
            // Show the tab bar again when leaving this view
            hideTabBar(false)
        }
        .sheet(isPresented: $showingEditModal) {
            SimpleNoteModalView(
                initialText: note.content ?? "",  // Use note.content directly instead of editingNoteText
                noteId: note.noteId
            ) { updatedText in
                print("Debug - Received updated text: \(updatedText)")
                if !updatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    guard let noteId = note.noteId else { return }
                    if noteManager.updateNote(noteId: noteId, text: updatedText) {
                        // Post notification to refresh the notes list
                        NotificationCenter.default.post(name: Notification.Name("RefreshNotesList"), object: nil)
                    }
                }
            }
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
        .onChange(of: scrollResetID) { _ in
            shouldScrollToTop = false
        }
        .sheet(isPresented: $showingSocialBrain) {
            SocialBrainView(
                sourceType: "note",
                sourceAction: "insights",
                sourceId: note.noteId?.uuidString ?? ""
            )
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
        DispatchQueue.main.async {
            let keyWindow = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .map { $0 as? UIWindowScene }
                .compactMap { $0 }
                .first?.windows
                .filter { $0.isKeyWindow }
                .first
                
            if let keyWindow = keyWindow {
                keyWindow.rootViewController?.children.forEach { child in
                    if let tabBarController = child as? UITabBarController {
                        // Ensure the tab bar is properly hidden
                        tabBarController.tabBar.isHidden = hidden
                        // Also adjust the tab bar's alpha to ensure it's completely hidden
                        tabBarController.tabBar.alpha = hidden ? 0 : 1
                    }
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
    
    private func formattedTimestamp(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func loadContactInsights() {
        isLoadingInsights = true
        
        // Get all insights and filter by category
        let allInsights = insightManager.fetchInsights()
        
        // Sort insights by order
        contactInsights = allInsights.sorted { insight1, insight2 in
            insight1.order < insight2.order
        }
        
        isLoadingInsights = false
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
    
    @StateObject private var textState = TextEditorState()
    @State private var textEditorHeight: CGFloat = 100
    @State private var showingKeyboard: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    
    private let maxTextEditorHeight: CGFloat = UIScreen.main.bounds.height * 0.4
    private let backgroundOpacity: Double = 0.6
    
    // Initialize with the existing note content
    init(initialText: String, noteId: UUID) {
        self.initialText = initialText
        self.noteId = noteId
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
                    
                    // Text editor - using a minimalist style
                    ZStack(alignment: .topLeading) {
                        // Use ZStack to place custom background behind TextEditor
                        Color(.systemBackground)
                            .frame(height: min(textEditorHeight, maxTextEditorHeight))
                        
                        // Custom UITextView for immediate focus
                        TextViewWrapper(state: textState, isFirstResponder: true, onDone: {})
                            .frame(height: min(textEditorHeight, maxTextEditorHeight))
                            .onChange(of: textState.text) { newValue in
                                // Calculate new height based on text content
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
            textState.text = initialText
            setupKeyboardObservers()
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
        if !textState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Update the existing note and handle the result
            let success = noteManager.updateNote(noteId: noteId, text: textState.text)
            if !success {
                // Handle the error case if needed
                print("Failed to update note")
            }
        }
        dismiss()
    }
}

// MARK: - Supporting Views
struct ContactInsightRow: View {
    let insight: ContactInsight
    let isLast: Bool
    
    init(insight: ContactInsight, isLast: Bool = false) {
        self.insight = insight
        self.isLast = isLast
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Bullet point
                SwiftUI.Circle()
                    .foregroundColor(Color.tertiaryText)
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(insight.content ?? "")
                        .font(.system(size: 16))
                        .foregroundColor(.primaryText)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Show associated contacts if any
                    if let contacts = insight.contacts as? Set<InsightContactRelationship>,
                       !contacts.isEmpty {
                        HStack {
                            ForEach(Array(contacts), id: \.relationshipId) { relationship in
                                if let contact = relationship.contacts {
                                    Text(contact.name ?? "Unknown")
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
                    }
                }
            }
            
            if !isLast {
                Divider()
                    .padding(.leading, 22)
                    .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// Keep the preference key for scroll position tracking
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
} 
