import SwiftUI
import CoreData

struct NoteDetailNav: View {
    let note: Note
    @State private var showingEditModal: Bool = false
    @State private var showingArchiveConfirmation: Bool = false
    @State private var scrollResetID = UUID()
    @State private var shouldScrollToTop = false
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var noteManager: NoteManager
    @EnvironmentObject var appModeManager: AppModeManager
    @EnvironmentObject var tabBarManager: TabBarManager
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
                                    .lineSpacing(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            // Add extra padding to ensure content doesn't get covered by bottom toolbar
                            .padding(.bottom, 120)
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
                }
                .scrollIndicators(.hidden)
                
                // Fixed bottom toolbar with proper spacing
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 0) {
                        // Delete button
                        Button(action: {
                            showingArchiveConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 22))
                                .foregroundColor(.red)
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
                    .frame(height: 49) // Match standard tab bar height
                    .padding(.top, 0) // Position buttons at the top
                    .padding(.bottom, getBottomSafeAreaInset()) // Add safe area padding at bottom
                }
                .background(
                    VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .hideTabBar() // Always hide tab bar for detail views
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(formattedTimestamp(date: note.createdAt ?? Date()))
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        // Add these modifiers to ensure proper navigation bar behavior
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.primaryBackground, for: .navigationBar)
        .onAppear {
            loadContactInsights()
            // Ensure proper layout when appearing
            DispatchQueue.main.async {
                UIApplication.shared.windows.first?.layoutIfNeeded()
            }
        }
        .onDisappear {
            // Ensure proper layout when disappearing
            DispatchQueue.main.async {
                UIApplication.shared.windows.first?.layoutIfNeeded()
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $showingEditModal) {
            SimpleNoteModalView(
                initialText: note.content ?? "",  // Use note.content directly instead of editingNoteText
                noteId: note.noteId
            ) { updatedText in
                if !updatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    guard let noteId = note.noteId else { return }
                    if noteManager.updateNote(noteId: noteId, text: updatedText) {
                        // Post notification to refresh the notes list
                        NotificationCenter.default.post(name: Notification.Name("RefreshNotesList"), object: nil)
                        // Post notification to refresh contacts list so note counts are updated
                        NotificationCenter.default.post(name: Notification.Name("RefreshContactsList"), object: nil)
                    }
                }
            }
        }
        .alert(isPresented: $showingArchiveConfirmation) {
            Alert(
                title: Text("删除笔记"),
                message: Text("确认删除笔记？"),
                primaryButton: .destructive(Text("删除")) {
                    guard let noteId = note.noteId else { return }
                    if noteManager.deleteNote(noteId: noteId) {
                        // Post notification to refresh the notes list
                        NotificationCenter.default.post(name: Notification.Name("RefreshNotesList"), object: nil)
                        // Post notification to refresh contacts list so note counts are updated
                        NotificationCenter.default.post(name: Notification.Name("RefreshContactsList"), object: nil)
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
            SocialBrainSheetView(
                sourceType: "note",
                sourceAction: "insights",
                sourceId: note.noteId?.uuidString ?? ""
            )
            .environmentObject(appModeManager)
        }
    }
    
    // Get bottom safe area inset
    private func getBottomSafeAreaInset() -> CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
            
        return keyWindow?.safeAreaInsets.bottom ?? 0
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
    
    private func formattedTimestamp(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
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
struct NoteDetailNav_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataManager.shared.viewContext
        let note = Note(context: context)
        note.noteId = UUID()
        note.content = "Sample note content with @Contact mention"
        note.createdAt = Date()
        
        return NavigationView {
            NoteDetailNav(note: note)
        }
        .environment(\.colorScheme, .light)
        .environmentObject(NoteManager.shared)
    }
} 