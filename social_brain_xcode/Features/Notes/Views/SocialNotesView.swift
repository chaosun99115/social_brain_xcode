import SwiftUI
import CoreData

struct SocialNotesView: View {
    @State private var searchText = ""
    @State private var showingNoteModal = false
    @State private var showingSimpleNoteModal = false
    @State private var selectedNote: SocialNote? = nil
    @State private var showingNoteDetail = false
    @State private var refreshTrigger = false
    @State private var showingSampleNoteModal = false
    @State private var showingSampleNoteDialog = false
    @State private var showingConfigurationSheet = false
    @EnvironmentObject var noteManager: NoteManager
    @EnvironmentObject var appModeManager: AppModeManager
    @Environment(\.managedObjectContext) private var viewContext
    
    var filteredNotes: [SocialNote] {
        let allNotes = noteManager.fetchNotes()
            .map { SocialNote(from: $0) }
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Filter notes based on app mode
        let modeFilteredNotes = allNotes.filter { note in
            if appModeManager.isSampleMode {
                return note.type.rawValue == 0 // Only show type 0 in sample mode
            } else {
                return note.type.rawValue == 1 // Only show type 1 in non-sample mode
            }
        }
        
        // Apply search filter if search text exists
        if searchText.isEmpty {
            return modeFilteredNotes
        }
        return modeFilteredNotes.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primaryBackground
                    .ignoresSafeArea()
                
                // Main content area (no custom header for navigation bar)
                VStack(spacing: 0) {
                    if filteredNotes.isEmpty {
                        VStack(spacing: 32) {
                            Spacer()
                            VStack(spacing: 12) {
                                Text("在这里记录您的社交互动")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                Text("\"社交大脑\"将协助您管理人际关系")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            VStack(spacing: 16) {
                                Button(action: {
                                    showingSampleNoteDialog = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: SampleModeConfig.UIConstants.sampleButtonIcon)
                                        Text(SampleModeConfig.UIConstants.sampleButtonTitle)
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(Color.primaryAction)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.primaryAction, lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal, 60)
                            }
                            Spacer()
                        }
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                SocialNotesList(notes: filteredNotes, onNoteSelected: { note in
                                    selectedNote = note
                                    showingNoteDetail = true
                                })
                                .padding(.top, 10)
                                .id(refreshTrigger)

                                Spacer().frame(height: 80)
                            }
                            .refreshable {
                                await refreshNotes()
                                withAnimation {
                                    proxy.scrollTo("top", anchor: .top)
                                }
                            }
                        }
                    }
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
            .navigationTitle("社交笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(Color.primaryBackground, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索笔记")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if appModeManager.isSampleMode {
                        Button(action: {
                            appModeManager.isSampleMode = false
                            appModeManager.sampleModeType = nil
                            refreshTrigger.toggle()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: SampleModeConfig.UIConstants.exitButtonIcon)
                                Text(SampleModeConfig.UIConstants.exitButtonTitle)
                                    .fontWeight(.bold)
                            }
                            .font(.footnote)
                            .foregroundColor(.blue)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingConfigurationSheet = true
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingNoteModal) {
                SocialNoteModalView(initialPrompt: "今天遇到了哪些事，认识了哪些人？") { noteText in
                    // Only refresh the notes list
                    NotificationCenter.default.post(name: Notification.Name("RefreshNotesList"), object: nil)
                }
            }
            .sheet(isPresented: $showingSimpleNoteModal) {
                SimpleNoteModalView(initialText: "") { noteText in
                    refreshTrigger.toggle()
                }
            }
            .confirmationDialog(
                SampleModeConfig.selectionDialogMessage,
                isPresented: $showingSampleNoteDialog,
                titleVisibility: .visible
            ) {
                ForEach(SampleModeConfig.availableModes, id: \.id) { mode in
                    Button(mode.title) {
                        Task {
                            await handleSampleModeSelection(mode)
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .background(
                NavigationLink(
                    destination: Group {
                        if let socialNote = selectedNote,
                           let note = noteManager.fetchNote(withId: socialNote.id) {
                            SocialNoteDetailView(note: note)
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $showingNoteDetail,
                    label: { EmptyView() }
                )
            )
            .sheet(isPresented: $showingConfigurationSheet) {
                ConfigurationSheetView()
            }
        }
        .onChange(of: showingSimpleNoteModal) { newValue in
            if !newValue {
                // Refresh when modal is dismissed
                DispatchQueue.main.async {
                    refreshTrigger.toggle()
                }
            }
        }
        .onAppear {
            setupNotificationObservers()
            // Initial refresh
            refreshTrigger.toggle()
        }
        .onDisappear {
            removeNotificationObservers()
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: Notification.Name("RefreshNotesList"), object: nil, queue: .main) { _ in
            refreshTrigger.toggle()
        }
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("RefreshNotesList"), object: nil)
    }
    
    private func refreshNotes() async {
        // Simulate a small delay to show the refresh animation
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Update on main thread
        await MainActor.run {
            refreshTrigger.toggle()
        }
    }
    
    private func handleSampleModeSelection(_ mode: SampleModeConfig.ModeDefinition) async {
        // Remove debug logs
        do {
            // Clear existing sample data if any
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Note.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "type == %d", 0)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try viewContext.execute(deleteRequest)
            try viewContext.save()
            
            // Import new sample data
            try await SeedDataManager.shared.importSeedData(into: viewContext, scenario: mode.scenario)
            
            // Update UI
            await MainActor.run {
                appModeManager.isSampleMode = true
                appModeManager.sampleModeType = (mode.id == "indie") ? "indieDev" : mode.id
                refreshTrigger.toggle()
            }
        } catch {
            // Keep error logging for debugging purposes
            print("\n[SocialNotesView] ❌ Error during sample mode setup:")
            print("- Error: \(error)")
            print("- Mode: \(mode.title)")
            print("- Scenario: \(mode.scenario.rawValue)")
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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 
