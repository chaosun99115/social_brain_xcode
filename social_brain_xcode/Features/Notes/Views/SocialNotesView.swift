import SwiftUI

struct SocialNotesView: View {
    @State private var searchText = ""
    @State private var showingNoteModal = false
    @State private var showingSimpleNoteModal = false
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
                
                ScrollView {
                    SocialNotesList(notes: filteredNotes)
                        .padding(.top, 10)
                    
                    // Add space at the bottom for better scrolling and to avoid FAB overlap
                    Spacer().frame(height: 80)
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingSimpleNoteModal = true
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
            .navigationTitle("笔记")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "search_notes".localized)
            .sheet(isPresented: $showingNoteModal) {
                SocialNoteModalView(initialPrompt: "What would you like to take a note about today?")
                    .environmentObject(noteManager)
                    .environmentObject(localizationManager)
            }
            .sheet(isPresented: $showingSimpleNoteModal) {
                SimpleNoteModalView()
                    .environmentObject(noteManager)
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
