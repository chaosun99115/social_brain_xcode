import SwiftUI
import CoreData

struct SocialNotesView: View {
    @State private var searchText = ""
    @State private var selectedTab = 0 // 0 for 互动记录, 1 for 话题库
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
    
    // MARK: - Note Filtering and Processing
    
    // Separate function to convert Core Data notes to SocialNote model
    private func convertToSocialNotes(_ coreDataNotes: [Note]) -> [SocialNote] {
        coreDataNotes.compactMap { note in
            guard let content = note.content,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return SocialNote(from: note)
        }
    }
    
    // Separate function to get all valid notes
    private func getAllValidNotes() -> [SocialNote] {
        let coreDataNotes = noteManager.fetchNotes()
        return convertToSocialNotes(coreDataNotes)
    }
    
    // Separate function to determine expected type and subType
    private func getExpectedTypes() -> (type: Int16, subType: Int16) {
        let isSampleMode = appModeManager.isSampleMode
        let isInteractionRecordTab = selectedTab == 0
        
        let expectedType: Int16 = isSampleMode ? 0 : 1
        let expectedSubType: Int16 = isInteractionRecordTab ? 1 : 2
        
        return (expectedType, expectedSubType)
    }
    
    // Helper function to filter notes based on app mode and tab
    private func filterNotesByModeAndTab(_ notes: [SocialNote]) -> [SocialNote] {
        let (expectedType, expectedSubType) = getExpectedTypes()
        let isSampleMode = appModeManager.isSampleMode
        
        return notes.filter { note in
            let subTypeMatches = note.subType == expectedSubType
            
            if isSampleMode {
                // In sample mode, show both sample data (type = 0) and user data (type != 0)
                return subTypeMatches
            } else {
                // In regular mode, only show user data (type = 1)
                let typeMatches = note.type.rawValue == expectedType
                return typeMatches && subTypeMatches
            }
        }
    }
    
    // Helper function to sort notes based on app mode
    private func sortNotes(_ notes: [SocialNote]) -> [SocialNote] {
        let isSampleMode = appModeManager.isSampleMode
        
        return notes.sorted { note1, note2 in
            if isSampleMode {
                // Ascending order (oldest first) for sample mode
                return note1.date < note2.date
            } else {
                // Descending order (newest first) for regular mode
                return note1.date > note2.date
            }
        }
    }
    
    // Helper function to filter notes by search text
    private func filterNotesBySearch(_ notes: [SocialNote], searchText: String) -> [SocialNote] {
        guard !searchText.isEmpty else { return notes }
        
        return notes.filter { note in
            note.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Separate function to process notes through all filters
    private func processNotes() -> [SocialNote] {
        // Step 1: Get all valid notes
        let allValidNotes = getAllValidNotes()
        
        // Step 2: Apply mode and tab filtering
        let modeFilteredNotes = filterNotesByModeAndTab(allValidNotes)
        
        // Step 3: Sort notes
        let sortedNotes = sortNotes(modeFilteredNotes)
        
        // Step 4: Apply search filter if needed
        return filterNotesBySearch(sortedNotes, searchText: searchText)
    }
    
    // Simplified computed property that uses the processing function
    var filteredNotes: [SocialNote] {
        processNotes()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab selector
                    HStack(spacing: 0) {
                        TabButton(
                            title: "互动记录",
                            isSelected: selectedTab == 0,
                            action: { 
                                withAnimation(.easeInOut(duration: 0.4)) { 
                                    selectedTab = 0 
                                }
                            }
                        )
                        
                        TabButton(
                            title: "话题库",
                            isSelected: selectedTab == 1,
                            action: { 
                                withAnimation(.easeInOut(duration: 0.4)) { 
                                    selectedTab = 1 
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                    
                    // TabView for content
                    TabView(selection: $selectedTab) {
                        // 互动记录 Tab
                        notesListView
                            .tag(0)
                        
                        // 话题库 Tab
                        notesListView
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.4), value: selectedTab)
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
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.green)
                                .clipShape(SwiftUI.Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("社交笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(Color.primaryBackground, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if appModeManager.isSampleMode {
                        Button(action: {
                            appModeManager.isSampleMode = false
                            appModeManager.sampleModeType = nil
                            Task {
                                await refreshNotes()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: SampleModeConfig.UIConstants.exitButtonIcon)
                                Text(SampleModeConfig.UIConstants.exitButtonTitle)
                                    .fontWeight(.bold)
                            }
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingConfigurationSheet = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(.primaryText)
                    }
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
            .sheet(isPresented: $showingSimpleNoteModal) {
                simpleNoteModalView
            }
            .sheet(isPresented: $showingNoteModal) {
                socialNoteModalView
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
            
            // Setup sample mode change observer
            setupSampleModeObserver()
        }
        .onDisappear {
            removeNotificationObservers()
            
            // Cleanup sample mode observer
            cleanupSampleModeObserver()
        }
    }
    
    private var notesListView: some View {
        Group {
            if filteredNotes.isEmpty {
                VStack(spacing: 32) {
                    Spacer()
                    VStack(spacing: 12) {
                        Text(selectedTab == 0 ? "在这里记录您的社交互动" : "在这里记录您的社交话题")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Text("\"社交大脑\"将协助管理您的社交网络")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 16) {
                        Button(action: {
                            showingSampleNoteDialog = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: selectedTab == 0 ? "person.2.fill" : "lightbulb.fill")
                                Text(selectedTab == 0 ? "查看示例记录" : "查看示例话题")
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
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: Notification.Name("RefreshNotesList"), object: nil, queue: .main) { _ in
            refreshTrigger.toggle()
        }
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("RefreshNotesList"), object: nil)
    }
    
    private func setupSampleModeObserver() {
        NotificationCenter.default.addObserver(
            forName: .sampleModeChanged,
            object: nil,
            queue: .main
        ) { _ in
            // Refresh notes when sample mode changes
            Task {
                await self.refreshNotes()
            }
        }
    }
    
    private func cleanupSampleModeObserver() {
        NotificationCenter.default.removeObserver(self, name: .sampleModeChanged, object: nil)
    }
    
    private func refreshNotes() async {
        // Simulate a small delay to show the refresh animation
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            refreshTrigger.toggle()
        }
    }
    
    private func handleSampleModeSelection(_ mode: SampleModeConfig.ModeDefinition) async {
        // Remove debug logs
        do {
            // Use the new SeedDataManager method to switch scenarios while preserving user data
            try await SeedDataManager.shared.switchToScenario(mode.scenario, in: viewContext)
            
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
    
    // Add helper function to get tab bar height
    private func getTabBarHeight() -> CGFloat {
        let standardTabBarHeight: CGFloat = 49
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
        
        let bottomInset = keyWindow?.safeAreaInsets.bottom ?? 0
        return standardTabBarHeight + bottomInset
    }
    
    private var simpleNoteModalView: some View {
        SimpleNoteModalView(
            initialText: "",
            subType: selectedTab == 0 ? .interactionRecord : .topicCollection,
            modalTitle: selectedTab == 0 ? "记录互动" : "收集话题"
        ) { _ in
            Task { @MainActor in
                await refreshNotes()
            }
        }
    }
    
    private var socialNoteModalView: some View {
        SocialNoteModalView(
            subType: selectedTab == 0 ? .interactionRecord : .topicCollection
        ) { _ in
            Task { @MainActor in
                await refreshNotes()
            }
        }
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
