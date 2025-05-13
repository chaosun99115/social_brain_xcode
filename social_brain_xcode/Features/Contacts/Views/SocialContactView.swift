import SwiftUI
import CoreData

struct SocialContactView: View {
    @State private var searchText = ""
    @State private var selectedTab = 0 // 0 for 熟人, 1 for 圈子
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var appModeManager: AppModeManager
    @StateObject private var contactManager = ContactManager.shared
    @StateObject private var circleManager = CircleManager.shared
    @State private var contacts: [Contact] = []
    @State private var circles: [Circle] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil
    
    // Fetch contacts from CoreData (initial load)
    private func loadContacts() async {
        // Only set isLoading for initial load
        if !isRefreshing {
            await MainActor.run { isLoading = true }
        }
        errorMessage = nil
        defer {
            Task { @MainActor in
                isLoading = false
                isRefreshing = false
            }
        }
        
        let fetchedContacts = contactManager.fetchContacts()
        let validContacts = fetchedContacts.filter { contact in
            do {
                try contactManager.validateContactRelationships(contact)
                return true
            } catch {
                print("Invalid relationships for contact: \(contact.name ?? "Unknown")")
                return false
            }
        }
        
        await MainActor.run {
            self.contacts = validContacts
        }
    }
    
    // Add loadCircles function
    private func loadCircles() async {
        if !isRefreshing {
            await MainActor.run { isLoading = true }
        }
        errorMessage = nil
        defer {
            Task { @MainActor in
                isLoading = false
                isRefreshing = false
            }
        }
        
        let fetchedCircles = circleManager.fetchCircles()
        let validCircles = fetchedCircles.filter { circle in
            do {
                try circleManager.validateCircleRelationships(circle)
                return true
            } catch {
                print("Invalid relationships for circle: \(circle.name ?? "Unknown")")
                return false
            }
        }
        
        await MainActor.run {
            self.circles = validCircles
        }
    }
    
    // Pull-to-refresh
    private func refreshContacts() async {
        await MainActor.run { isRefreshing = true }
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        // Add a small delay to ensure the refresh control is in the correct state
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        await loadContacts()
        await loadCircles()
    }
    
    var filteredContacts: [Contact] {
        let filtered: [Contact]
        if appModeManager.isSampleMode {
            filtered = contacts
        } else {
            // Filter contacts based on tab selection and note type
            filtered = contacts.filter { contact in
                guard let contactId = contact.contactId else { return false }
                let notes = ContactManager.shared.getNotesForContact(contactId: contactId)
                let hasValidNotes = notes.contains(where: { $0.type != 0 })
                
                // For 熟人 tab (selectedTab == 0), show contacts with type 1 notes
                // For 圈子 tab (selectedTab == 1), show contacts with type 2 notes
                let noteType = selectedTab == 0 ? 1 : 2
                return hasValidNotes && notes.contains(where: { $0.type == noteType })
            }
        }
        
        if searchText.isEmpty {
            return filtered
        }
        return filtered.filter { contact in
            guard let name = contact.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
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
                            Task { await loadContacts() }
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
                    
                    // Tab selector
                    HStack(spacing: 0) {
                        TabButton(
                            title: "熟人",
                            isSelected: selectedTab == 0,
                            action: { 
                                withAnimation(.easeInOut(duration: 0.4)) { 
                                    selectedTab = 0 
                                }
                            }
                        )
                        
                        TabButton(
                            title: "圈子",
                            isSelected: selectedTab == 1,
                            action: { 
                                withAnimation(.easeInOut(duration: 0.4)) { 
                                    selectedTab = 1 
                                }
                            }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Modify TabView to use CircleListView for circles tab
                    TabView(selection: $selectedTab) {
                        // 熟人 Tab
                        ContactListView(
                            contacts: filteredContacts,
                            isLoading: isLoading,
                            errorMessage: errorMessage,
                            isRefreshing: isRefreshing,
                            searchText: $searchText,
                            onRefresh: { await refreshContacts() },
                            selectedTab: 0
                        )
                        .tag(0)
                        
                        // 圈子 Tab
                        CircleListView(
                            circles: circles,
                            isLoading: isLoading,
                            errorMessage: errorMessage,
                            isRefreshing: isRefreshing,
                            searchText: $searchText,
                            onRefresh: { await refreshContacts() }
                        )
                        .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.4), value: selectedTab)
                }
                
                // Floating Action Button
                if !filteredContacts.isEmpty && !appModeManager.isSampleMode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                // Add contact action
                            }) {
                                Image(systemName: "person.badge.plus")
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
                
                // Show overlay spinner only during refresh
                if isRefreshing && !isLoading {
                    Color.primaryBackground.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("社交关系")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "search_contacts".localized)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await loadContacts()
            await loadCircles()
        }
    }
}

// Extracted ContactListView for reuse
struct ContactListView: View {
    let contacts: [Contact]
    let isLoading: Bool
    let errorMessage: String?
    let isRefreshing: Bool
    @Binding var searchText: String
    let onRefresh: () async -> Void
    let selectedTab: Int
    
    @State private var showingSampleDialog = false
    @State private var showingCreateContact = false // Placeholder for create action
    @State private var isImportingSample = false
    @State private var errorMessageSample: String? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var appModeManager: AppModeManager
    @State private var refreshTrigger = false
    
    var body: some View {
        Group {
            if isLoading || isImportingSample {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            } else if let error = errorMessage ?? errorMessageSample {
                errorView(message: error)
            } else if contacts.isEmpty {
                emptyTabView
            } else {
                List {
                    ForEach(contacts, id: \ .contactId) { contact in
                        NavigationLink(destination: SocialContactDetailView(contact: contact)) {
                            ContactCardView(contact: contact)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.visible)
                        .listRowBackground(Color.cardBackground)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await onRefresh()
                }
            }
        }
        .confirmationDialog(
            "选择一个用户场景。进入示例模式后，将会生成虚拟的示例数据，供你全面体验小日常的功能。示例模式不影响你的私有数据，退出示例模式后将恢复原状。",
            isPresented: $showingSampleDialog,
            titleVisibility: .visible
        ) {
            Button("换了一份新工作") { Task { await handleSampleModeSelection("换了一份新工作") } }
            Button("孩子进了新学校") { Task { await handleSampleModeSelection("孩子进了新学校") } }
            Button("打算职业转型") { Task { await handleSampleModeSelection("打算职业转型") } }
            Button("取消", role: .cancel) {}
        }
        .alert(isPresented: Binding<Bool>(get: { errorMessageSample != nil }, set: { _ in errorMessageSample = nil })) {
            Alert(title: Text("导入示例数据失败"), message: Text(errorMessageSample ?? "未知错误"), dismissButton: .default(Text("确定")))
        }
        // Placeholder for create contact/circle modal
        .sheet(isPresented: $showingCreateContact) {
            Text("创建功能待实现")
                .font(.title)
                .padding()
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color.tertiaryText)
            Text(message)
                .font(.headline)
                .foregroundColor(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task {
                    await onRefresh()
                }
            }
            .padding()
            .background(Color.primaryAction)
            .foregroundColor(.white)
            .cornerRadius(8)
            Spacer()
        }
    }
    
    private var emptyTabView: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                if selectedTab == 0 {
                    Text("在这里记录您的社交熟人")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("\"社交大脑\"将协助你管理你的社交关系")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("在这里记录您的社交圈子")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("\"社交大脑\"将协助你管理你的社交关系")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            VStack(spacing: 16) {
                Button(action: {
                    showingSampleDialog = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: selectedTab == 0 ? "person.3.sequence.fill" : "person.2.circle")
                        Text(selectedTab == 0 ? "查看示例熟人" : "查看示例圈子")
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
                    showingCreateContact = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: selectedTab == 0 ? "person.crop.circle.badge.plus" : "plus.circle")
                        Text(selectedTab == 0 ? "创建熟人" : "创建圈子")
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
    }
    
    private func handleSampleModeSelection(_ mode: String) async {
        isImportingSample = true
        errorMessageSample = nil
        let scenario: SeedDataScenario
        switch mode {
        case "换了一份新工作":
            scenario = .changedJob
        case "孩子进了新学校":
            scenario = .changedSchool
        case "打算职业转型":
            scenario = .careerPivot
        default:
            isImportingSample = false
            errorMessageSample = "未知示例场景"
            return
        }
        do {
            // Clear existing sample data
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Note.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "type == %d", 0)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try viewContext.execute(deleteRequest)
            try viewContext.save()
            // Import new sample data
            try await SeedDataManager.shared.importSeedData(into: viewContext, scenario: scenario)
            await MainActor.run {
                appModeManager.isSampleMode = true
                appModeManager.sampleModeType = mode
                refreshTrigger.toggle()
            }
        } catch {
            await MainActor.run {
                errorMessageSample = error.localizedDescription
            }
        }
        isImportingSample = false
        // Optionally trigger refresh in parent
        await onRefresh()
    }
}

struct ContactCardView: View {
    let contact: Contact
    @StateObject private var contactManager = ContactManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.name ?? "Unnamed Contact")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primaryText)
            
            HStack {
                Text("共有\(getNotesCount())条笔记")
                Text("｜")
                Text("\(formatLastUpdateTime())")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    
    private func getNotesCount() -> Int {
        guard let contactId = contact.contactId else { return 0 }
        return contactManager.getNotesCount(forContactId: contactId)
    }
    
    private func formatLastUpdateTime() -> String {
        guard let updatedAt = contact.updatedAt else { return "未知时间" }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: updatedAt, to: now)
        
        if let days = components.day {
            if days == 0 {
                return "今天更新"
            } else if days == 1 {
                return "昨天更新"
            } else {
                return "\(days)天前更新"
            }
        }
        return "未知时间"
    }
}

// Tab Button Component
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .primaryAction : .secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    VStack {
                        Spacer()
                        if isSelected {
                            Rectangle()
                                .fill(Color.primaryAction)
                                .frame(height: 2)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.4), value: isSelected)
    }
}

// Add CircleListView component before SocialContactView_Previews
struct CircleListView: View {
    let circles: [Circle]
    let isLoading: Bool
    let errorMessage: String?
    let isRefreshing: Bool
    @Binding var searchText: String
    let onRefresh: () async -> Void
    
    @State private var showingCreateCircle = false
    @State private var showingSampleDialog = false
    @State private var isImportingSample = false
    @State private var errorMessageSample: String? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var appModeManager: AppModeManager
    @State private var refreshTrigger = false
    
    var filteredCircles: [Circle] {
        print("[CircleListView] appModeManager.isSampleMode = \(appModeManager.isSampleMode)")
        print("[CircleListView] circles count before filtering: \(circles.count)")
        print("[CircleListView] circles types: \(circles.map { $0.type })")
        let base: [Circle]
        if appModeManager.isSampleMode {
            base = circles
            print("[CircleListView] In sample mode, showing all circles.")
        } else {
            base = circles.filter { $0.type != 0 }
            print("[CircleListView] Not in sample mode, filtered circles count: \(base.count)")
            print("[CircleListView] Filtered circles types: \(base.map { $0.type })")
        }
        if searchText.isEmpty {
            print("[CircleListView] Returning \(base.count) circles after filtering by type.")
            return base
        }
        let filtered = base.filter { circle in
            guard let name = circle.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        }
        print("[CircleListView] Returning \(filtered.count) circles after filtering by search text '", searchText, "'.")
        return filtered
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            } else if let error = errorMessage {
                errorView(message: error)
            } else if filteredCircles.isEmpty {
                emptyCircleView
            } else {
                List {
                    ForEach(filteredCircles, id: \.circleId) { circle in
                        NavigationLink(destination: CircleDetailView(circle: circle)) {
                            CircleCardView(circle: circle)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.visible)
                        .listRowBackground(Color.cardBackground)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await onRefresh()
                }
            }
        }
        .sheet(isPresented: $showingCreateCircle) {
            Text("创建圈子功能待实现")
                .font(.title)
                .padding()
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color.tertiaryText)
            Text(message)
                .font(.headline)
                .foregroundColor(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task {
                    await onRefresh()
                }
            }
            .padding()
            .background(Color.primaryAction)
            .foregroundColor(.white)
            .cornerRadius(8)
            Spacer()
        }
    }
    
    private var emptyCircleView: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Text("在这里记录您的社交圈子")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("\"社交大脑\"将协助你管理你的社交圈子")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 16) {
                Button(action: {
                    showingSampleDialog = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.circle")
                        Text("查看示例圈子")
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
                    showingCreateCircle = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("创建圈子")
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
        .confirmationDialog(
            "选择一个用户场景。进入示例模式后，将会生成虚拟的示例数据，供你全面体验小日常的功能。示例模式不影响你的私有数据，退出示例模式后将恢复原状。",
            isPresented: $showingSampleDialog,
            titleVisibility: .visible
        ) {
            Button("换了一份新工作") { Task { await handleSampleModeSelection("换了一份新工作") } }
            Button("孩子进了新学校") { Task { await handleSampleModeSelection("孩子进了新学校") } }
            Button("打算职业转型") { Task { await handleSampleModeSelection("打算职业转型") } }
            Button("取消", role: .cancel) {}
        }
        .alert(isPresented: Binding<Bool>(get: { errorMessageSample != nil }, set: { _ in errorMessageSample = nil })) {
            Alert(title: Text("导入示例数据失败"), message: Text(errorMessageSample ?? "未知错误"), dismissButton: .default(Text("确定")))
        }
    }

    private func handleSampleModeSelection(_ mode: String) async {
        isImportingSample = true
        errorMessageSample = nil
        let scenario: SeedDataScenario
        switch mode {
        case "换了一份新工作":
            scenario = .changedJob
        case "孩子进了新学校":
            scenario = .changedSchool
        case "打算职业转型":
            scenario = .careerPivot
        default:
            isImportingSample = false
            errorMessageSample = "未知示例场景"
            return
        }
        do {
            // Clear existing sample data
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Note.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "type == %d", 0)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try viewContext.execute(deleteRequest)
            try viewContext.save()
            // Import new sample data
            try await SeedDataManager.shared.importSeedData(into: viewContext, scenario: scenario)
            await MainActor.run {
                appModeManager.isSampleMode = true
                appModeManager.sampleModeType = mode
                refreshTrigger.toggle()
            }
        } catch {
            await MainActor.run {
                errorMessageSample = error.localizedDescription
            }
        }
        isImportingSample = false
        // Optionally trigger refresh in parent
        await onRefresh()
    }
}

struct CircleCardView: View {
    let circle: Circle
    @StateObject private var circleManager = CircleManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(circle.name ?? "Unnamed Circle")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primaryText)
            
            Text("共有\(getContactsCount())个熟人")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    
    private func getContactsCount() -> Int {
        guard let circleId = circle.circleId else { return 0 }
        return circleManager.getContactsCount(forCircleId: circleId)
    }
}

// Preview
struct SocialContactView_Previews: PreviewProvider {
    static var previews: some View {
        SocialContactView()
            .environment(\.colorScheme, .light)
            .environmentObject(LocalizationManager())
        
        SocialContactView()
            .environment(\.colorScheme, .dark)
            .environmentObject(LocalizationManager())
    }
}
