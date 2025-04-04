import SwiftUI

struct SocialNotesView: View {
    @State private var searchText = ""
    
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
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    List(filteredNotes) { note in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(note.formattedDate)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(note.content)
                                .font(.body)
                                .lineSpacing(4)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.white)
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
                            // Add note action
                        }) {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Social Notes")
            .searchable(text: $searchText, prompt: "Search")
        }
    }
}

struct SocialNotesView_Previews: PreviewProvider {
    static var previews: some View {
        SocialNotesView()
    }
} 