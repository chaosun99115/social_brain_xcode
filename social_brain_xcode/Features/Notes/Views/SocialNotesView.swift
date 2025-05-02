import SwiftUI

struct SocialNotesView: View {
    @State private var searchText = ""
    @State private var showingNoteModal = false
    @State private var showingSimpleNoteModal = false
    @State private var selectedNote: SocialNote? = nil
    @State private var showingNoteDetail = false
    @State private var refreshTrigger = false
    @State private var showingDebugMenu = false
    @EnvironmentObject var noteManager: NoteManager
    
    var filteredNotes: [SocialNote] {
        let notes = noteManager.fetchNotes().map { SocialNote(from: $0) }
        if searchText.isEmpty {
            return notes
        }
        return notes.filter { note in
            note.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    SocialNotesList(notes: filteredNotes, onNoteSelected: { note in
                        selectedNote = note
                        showingNoteDetail = true
                    })
                    .padding(.top, 10)
                    .id(refreshTrigger)
                    
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
                                .clipShape(SwiftUI.Circle())
                                .shadow(color: Color.primaryText.opacity(0.2), radius: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("笔记")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索笔记")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDebugMenu = true
                    }) {
                        Image(systemName: "ladybug")
                            .foregroundColor(.primaryAction)
                    }
                }
            }
            .sheet(isPresented: $showingNoteModal) {
                SocialNoteModalView(initialPrompt: "今天你想记录什么？")
                    .environmentObject(noteManager)
                    .onDisappear {
                        refreshTrigger.toggle()
                    }
            }
            .sheet(isPresented: $showingSimpleNoteModal) {
                SimpleNoteModalView()
                    .environmentObject(noteManager)
                    .onDisappear {
                        refreshTrigger.toggle()
                    }
            }
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenuView()
            }
            .background(
                NavigationLink(
                    destination: selectedNote.map { note in
                        SocialNoteDetailView(note: note)
                    },
                    isActive: $showingNoteDetail,
                    label: { EmptyView() }
                )
            )
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
            .environmentObject(NoteManager.shared)
        
        SocialNotesView()
            .environment(\.colorScheme, .dark)
            .environmentObject(NoteManager.shared)
    }
} 
