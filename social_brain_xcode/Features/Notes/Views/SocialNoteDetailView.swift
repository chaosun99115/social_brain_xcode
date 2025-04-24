import SwiftUI

struct SocialNoteDetailView: View {
    let note: SocialNote
    @State private var aiSuggestions: [AISuggestion] = []
    @State private var isLoadingSuggestions: Bool = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Note content
                noteDetailSection
                
                Divider()
                    .padding(.vertical, 8)
                
                // AI Suggestions
                aiSuggestionsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .navigationBarTitle(formattedTimestamp(date: note.date), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .onAppear {
            loadAISuggestions()
        }
        .refreshable {
            await refreshSuggestions()
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
            
            HStack {
                Spacer()
                Button("编辑笔记") {
                    // Handle edit note action
                }
                .font(.headline)
                .foregroundColor(.accentColor)
            }
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
            
            Divider()
            
            HStack {
                Spacer()
                Button("查看笔记") {
                    // Handle view note action
                }
                .font(.headline)
                .foregroundColor(.accentColor)
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