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
    
    // Add timer for continuous tab bar hiding
    @State private var tabBarHideTimer: Timer?
    
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
        .overlay(
            // Add a hidden view that directly manipulates the tab bar
            TabBarHiderView()
                .allowsHitTesting(false)
        )
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
            // Multiple approaches to ensure tab bar is hidden
            hideTabBarImmediately()
            hideTabBarWithDelay()
            
            // Start timer to continuously hide tab bar
            startTabBarHideTimer()
            
            loadContactInsights()
            // Ensure proper layout when appearing
            DispatchQueue.main.async {
                UIApplication.shared.windows.first?.layoutIfNeeded()
            }
        }
        .onDisappear {
            // Stop timer and show tab bar again when leaving this view
            stopTabBarHideTimer()
            DispatchQueue.main.async {
                showTabBar()
            }
            // Ensure proper layout when disappearing
            DispatchQueue.main.async {
                UIApplication.shared.windows.first?.layoutIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Re-hide tab bar when app becomes active
            DispatchQueue.main.async {
                hideTabBarImmediately()
                hideTabBarWithDelay()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Re-hide tab bar when app enters foreground
            DispatchQueue.main.async {
                hideTabBarImmediately()
                hideTabBarWithDelay()
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
    
    // UIViewRepresentable to directly hide tab bar
    struct TabBarHiderView: UIViewRepresentable {
        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.backgroundColor = .clear
            
            // Hide tab bar immediately when view is created
            DispatchQueue.main.async {
                hideTabBarInView(view)
            }
            
            return view
        }
        
        func updateUIView(_ uiView: UIView, context: Context) {
            // Hide tab bar on every update
            DispatchQueue.main.async {
                hideTabBarInView(uiView)
            }
        }
        
        private func hideTabBarInView(_ view: UIView) {
            // Find the tab bar controller by traversing up the view hierarchy
            var currentView: UIView? = view
            while currentView != nil {
                if let viewController = currentView?.next as? UIViewController {
                    if let tabBarController = viewController as? UITabBarController {
                        tabBarController.tabBar.isHidden = true
                        tabBarController.tabBar.alpha = 0
                        tabBarController.view.layoutIfNeeded()
                        break
                    }
                    // Check parent view controller
                    if let parent = viewController.parent {
                        if let tabBarController = parent as? UITabBarController {
                            tabBarController.tabBar.isHidden = true
                            tabBarController.tabBar.alpha = 0
                            tabBarController.view.layoutIfNeeded()
                            break
                        }
                    }
                }
                currentView = currentView?.superview
            }
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
    
    // New function to hide tab bar immediately
    private func hideTabBarImmediately() {
        hideTabBar(true)
    }
    
    // New function to hide tab bar with a delay
    private func hideTabBarWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            hideTabBar(true)
        }
    }
    
    // New function to show tab bar
    private func showTabBar() {
        hideTabBar(false)
    }
    
    // Update hideTabBar function to handle layout updates
    private func hideTabBar(_ hidden: Bool) {
        // Multiple approaches to find and hide the tab bar
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
        
        if let keyWindow = keyWindow {
            // Approach 1: Direct tab bar controller access
            keyWindow.rootViewController?.children.forEach { child in
                if let tabBarController = child as? UITabBarController {
                    tabBarController.tabBar.isHidden = hidden
                    tabBarController.tabBar.alpha = hidden ? 0 : 1
                    // Force layout update
                    tabBarController.view.layoutIfNeeded()
                }
            }
            
            // Approach 2: Search through all view controllers recursively
            hideTabBarInViewController(keyWindow.rootViewController, hidden: hidden)
            
            // Approach 3: Force layout update on the entire window
            keyWindow.layoutIfNeeded()
        }
    }
    
    // Recursive function to find and hide tab bar in any view controller
    private func hideTabBarInViewController(_ viewController: UIViewController?, hidden: Bool) {
        guard let viewController = viewController else { return }
        
        // Check if this is a tab bar controller
        if let tabBarController = viewController as? UITabBarController {
            tabBarController.tabBar.isHidden = hidden
            tabBarController.tabBar.alpha = hidden ? 0 : 1
            tabBarController.view.layoutIfNeeded()
        }
        
        // Check child view controllers
        viewController.children.forEach { child in
            hideTabBarInViewController(child, hidden: hidden)
        }
        
        // Check presented view controller
        if let presented = viewController.presentedViewController {
            hideTabBarInViewController(presented, hidden: hidden)
        }
    }
    
    // Add timer for continuous tab bar hiding
    private func startTabBarHideTimer() {
        tabBarHideTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            hideTabBar(true)
        }
    }
    
    // Stop timer for continuous tab bar hiding
    private func stopTabBarHideTimer() {
        tabBarHideTimer?.invalidate()
        tabBarHideTimer = nil
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