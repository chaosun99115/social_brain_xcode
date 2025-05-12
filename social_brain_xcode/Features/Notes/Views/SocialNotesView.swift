import SwiftUI
import CoreData

struct SocialNotesView: View {
    @State private var searchText = ""
    @State private var showingNoteModal = false
    @State private var showingSimpleNoteModal = false
    @State private var selectedNote: SocialNote? = nil
    @State private var showingNoteDetail = false
    @State private var refreshTrigger = false
    @State private var showingDebugMenu = false
    @State private var showingSampleNoteModal = false
    @State private var showingSampleNoteDialog = false
    @EnvironmentObject var noteManager: NoteManager
    @EnvironmentObject var appModeManager: AppModeManager
    @Environment(\.managedObjectContext) private var viewContext
    
    var filteredNotes: [SocialNote] {
        let allNotes = noteManager.fetchNotes()
            .map { SocialNote(from: $0) }
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if appModeManager.isSampleMode {
            // Show all notes (including sample)
            if searchText.isEmpty {
                return allNotes
            }
            return allNotes.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        } else {
            // Hide sample notes (type == 0)
            let userNotes = allNotes.filter { $0.type.rawValue != 0 }
            if searchText.isEmpty {
                return userNotes
            }
            return userNotes.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if appModeManager.isSampleMode {
                        Button(action: {
                            appModeManager.isSampleMode = false
                            appModeManager.sampleModeType = nil
                            refreshTrigger.toggle()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("退出示例模式")
                            }
                            .font(.footnote)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color(hex: "4085F3"))
                            .cornerRadius(6)
                            .padding(.horizontal, 100)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }

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
                                    // Show confirmation dialog instead of directly entering sample mode
                                    showingSampleNoteDialog = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                        Text("查看示例笔记")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "4085F3"))
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal, 60)

                                Button(action: {
                                    showingSimpleNoteModal = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.pencil")
                                        Text("创建笔记")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(Color.primaryAction)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.primaryAction, lineWidth: 1)
                                    )
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
                if !filteredNotes.isEmpty && !appModeManager.isSampleMode {
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
            }
            .navigationTitle("社交笔记")
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
            .confirmationDialog(
                "选择一个用户场景。进入示例模式后，将会生成虚拟的示例数据，供你全面体验小日常的功能。示例模式不影响你的私有数据，退出示例模式后将恢复原状。",
                isPresented: $showingSampleNoteDialog,
                titleVisibility: .visible
            ) {
                Button("换了一份新工作") {
                    Task {
                        await handleSampleModeSelection("换了一份新工作")
                    }
                }
                Button("孩子进了新学校") {
                    Task {
                        await handleSampleModeSelection("孩子进了新学校")
                    }
                }
                Button("打算职业转型") {
                    Task {
                        await handleSampleModeSelection("打算职业转型")
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
        }
        .onAppear {
            setupNotificationObservers()
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
    
    private func handleSampleModeSelection(_ mode: String) async {
        print("\n[SocialNotesView] ===== Starting Sample Mode Selection =====")
        print("[SocialNotesView] Selected mode: \(mode)")
        
        // Map the mode string to SeedDataScenario
        let scenario: SeedDataScenario
        switch mode {
        case "换了一份新工作":
            scenario = .changedJob
        case "孩子进了新学校":
            scenario = .changedSchool
        case "打算职业转型":
            scenario = .careerPivot
        default:
            print("[SocialNotesView] ❌ Unknown sample mode: \(mode)")
            return
        }
        print("[SocialNotesView] Mapped to scenario: \(scenario.rawValue)")
        
        do {
            print("\n[SocialNotesView] 🧹 Clearing existing sample data...")
            // Clear existing sample data if any
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Note.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "type == %d", 0)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try viewContext.execute(deleteRequest)
            try viewContext.save()
            print("[SocialNotesView] ✅ Successfully cleared existing sample data")
            
            print("\n[SocialNotesView] 📥 Starting data import for scenario: \(scenario.rawValue)")
            // Import new sample data
            try await SeedDataManager.shared.importSeedData(into: viewContext, scenario: scenario)
            print("[SocialNotesView] ✅ Successfully imported sample data")
            
            // Update UI
            print("\n[SocialNotesView] 🔄 Updating UI state...")
            await MainActor.run {
                appModeManager.isSampleMode = true
                appModeManager.sampleModeType = mode
                refreshTrigger.toggle()
                print("[SocialNotesView] ✅ UI state updated")
            }
            
            print("\n[SocialNotesView] ===== Sample Mode Selection Completed =====")
        } catch {
            print("\n[SocialNotesView] ❌ Error during sample mode setup:")
            print("- Error: \(error)")
            print("- Mode: \(mode)")
            print("- Scenario: \(scenario.rawValue)")
            // Handle error appropriately
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
