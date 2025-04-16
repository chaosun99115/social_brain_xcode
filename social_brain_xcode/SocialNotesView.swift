import SwiftUI

struct SocialNotesView: View {
    @State private var searchText = ""
    @State private var showingNoteModal = false
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var noteManager: NoteManager
    
    var filteredNotes: [SocialNote] {
        if searchText.isEmpty {
            return SocialNote.mockNotes
        }
        return SocialNote.mockNotes.filter { note in
            note.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    List(filteredNotes) { note in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(formattedDate(for: note.date))
                                .font(.headline)
                                .foregroundColor(.secondaryText)
                            
                            MentionTextView(text: note.content)
                                .font(.body)
                                .foregroundColor(.primaryText)
                                .lineSpacing(4)
                                .lineLimit(4) 
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.primaryText.opacity(0.05), radius: 2, x: 0, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.divider, lineWidth: 0.5)
                        )
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.primaryBackground)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingNoteModal = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.primaryAction)
                                .clipShape(Circle())
                                .shadow(color: Color.primaryText.opacity(0.2), radius: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("social_notes".localized)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "search_notes".localized)
            .sheet(isPresented: $showingNoteModal) {
                SocialNoteModalView(initialPrompt: "What would you like to take a note about today?")
                    .environmentObject(noteManager)
                    .environmentObject(localizationManager)
            }
        }
    }
    
    // iOS standard date formatting
    func formattedDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
}

struct MentionTextView: View {
    let text: String
    
    var body: some View {
        Text(attributedString)
    }
    
    var attributedString: AttributedString {
        let words = text.split(separator: " ")
        var result = AttributedString("")
        
        for (index, word) in words.enumerated() {
            if word.hasPrefix("@") {
                var mentionText = AttributedString(String(word))
                mentionText.foregroundColor = Color.mentionHighlight
                mentionText.font = .subheadline.bold()
                result.append(mentionText)
            } else {
                result.append(AttributedString(String(word)))
            }
            
            if index < words.count - 1 {
                result.append(AttributedString(" "))
            }
        }
        
        return result
    }
}

struct SocialNotesView_Previews: PreviewProvider {
    static var previews: some View {
        SocialNotesView()
            .environment(\.colorScheme, .light)
            .environmentObject(LocalizationManager())
        
        SocialNotesView()
            .environment(\.colorScheme, .dark)
            .environmentObject(LocalizationManager())
    }
} 