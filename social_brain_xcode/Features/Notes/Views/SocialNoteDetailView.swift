import SwiftUI

struct SocialNoteDetailView: View {
    let note: SocialNote
    @State private var aiSuggestions: [AISuggestion] = []
    @State private var isLoadingSuggestions: Bool = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background color for the entire screen
            Color.primaryBackground
                .ignoresSafeArea()
            
            // Content area
            VStack(spacing: 0) {
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
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
                
                // Fixed bottom toolbar that respects safe areas
                VStack(spacing: 0) {
                    Divider()
                    
                    // Bottom toolbar content
                    ZStack {
                        // Full width background
                        Color.clear
                        
                        // Right-aligned button
                        HStack {
                            Spacer()
                            Button(action: {
                                // Handle edit note action
                            }) {
                                Text("编辑笔记")
                                    .font(.system(size: 21, weight: .regular))
                                    .foregroundColor(.accentColor)
                                    .padding(.top, 10)
                            }
                            .padding(.trailing, 16)
                        }
                    }
                    .frame(height: 44) // Fixed height for consistent touch target
                }
                .padding(.bottom, safeAreaPadding) // Dynamic padding based on device
                .background(
                    VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                        .ignoresSafeArea()
                )
            }
        }
        .navigationBarTitle(formattedTimestamp(date: note.date), displayMode: .inline)
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
        .refreshable {
            await refreshSuggestions()
        }
        .edgesIgnoringSafeArea(.bottom)
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
            MentionTextView(text: note.content)
                .font(.body)
                .foregroundColor(.primaryText)
                .lineSpacing(4)
            
            // "Edit Note" button has been moved to the bottom toolbar
        }
        .padding(.bottom, 8)
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

struct SocialNoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SocialNoteDetailView(note: SocialNote.mockNotes[0])
        }
        .environment(\.colorScheme, .light)
        .environmentObject(NoteManager.shared)
        
        NavigationView {
            SocialNoteDetailView(note: SocialNote.mockNotes[0])
        }
        .environment(\.colorScheme, .dark)
        .environmentObject(NoteManager.shared)
    }
} 
