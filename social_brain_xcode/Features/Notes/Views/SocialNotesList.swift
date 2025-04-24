import SwiftUI

struct SocialNotesList: View {
    let notes: [SocialNote]
    var showFullContent: Bool = false
    var onNoteSelected: ((SocialNote) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            if notes.isEmpty {
                Text("没有可用的笔记")
                    .font(.subheadline)
                    .foregroundColor(.tertiaryText)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
            } else {
                ForEach(notes) { note in
                    noteCard(for: note)
                        .padding(.bottom, 12)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func noteCard(for note: SocialNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(formattedDate(for: note.date))
                .font(.headline)
                .foregroundColor(.secondaryText)
            
            MentionTextView(text: note.content)
                .font(.body)
                .foregroundColor(.primaryText)
                .lineSpacing(4)
                .lineLimit(showFullContent ? nil : 4)
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
        .onTapGesture {
            if let onNoteSelected = onNoteSelected {
                onNoteSelected(note)
            }
        }
    }
    
    // iOS standard date formatting
    private func formattedDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
}

struct SocialNotesList_Previews: PreviewProvider {
    static var previews: some View {
        SocialNotesList(notes: SocialNote.mockNotes)
            .environment(\.colorScheme, .light)
        
        SocialNotesList(notes: SocialNote.mockNotes)
            .environment(\.colorScheme, .dark)
    }
} 