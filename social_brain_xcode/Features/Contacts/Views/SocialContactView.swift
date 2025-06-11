import SwiftUI
import CoreData

struct SocialContactView: View {
    @State private var searchText = ""
    @State private var selectedTab = 0 // 0 for 熟人, 1 for 圈子
    @EnvironmentObject var appModeManager: AppModeManager
    @StateObject private var contactManager = ContactManager.shared
    @StateObject private var circleManager = CircleManager.shared
    @State private var contacts: [Contact] = []
    @State private var circles: [Circle] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil
    @State private var showingAddContact = false
    @State private var showingAddCircleSheet = false
    @State private var showingEditCircleContactsSheet = false
    @State private var showingConfigurationSheet = false
    @State private var isViewActive = false
    
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
        
        // Filter out contacts with nil contactId and validate relationships
        let validContacts = fetchedContacts.filter { contact in
            guard let contactId = contact.contactId else {
                return false
            }
            
            do {
                try contactManager.validateContactRelationships(contact)
                return true
            } catch {
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
            // Filter contacts based on tab selection and contact type
            filtered = contacts.filter { contact in
                guard let contactId = contact.contactId else {
                    return false
                }
                // Only show type=1 contacts in non-sample mode and exclude archived contacts
                return contact.type == 1 && !contact.isArchived
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
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                    
                    // TabView for content
                    TabView(selection: $selectedTab) {
                        // 熟人 Tab
                        ContactListView(
                            contacts: filteredContacts,
                            isLoading: isLoading,
                            errorMessage: errorMessage,
                            isRefreshing: isRefreshing,
                            searchText: $searchText,
                            onRefresh: { await refreshContacts() },
                            onSampleModeSelected: { await refreshContacts() },
                            selectedTab: 0
                        )
                        .tag(0)
                        .onAppear {
                            updateLayout()
                        }
                        
                        // 圈子 Tab
                        CircleListView(
                            circles: circles,
                            isLoading: isLoading,
                            errorMessage: errorMessage,
                            isRefreshing: isRefreshing,
                            searchText: $searchText,
                            onRefresh: { await refreshContacts() },
                            onSampleModeSelected: { await refreshContacts() }
                        )
                        .tag(1)
                        .onAppear {
                            updateLayout()
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.4), value: selectedTab)
                    
                    // Floating Action Button - Moved inside VStack
                    HStack {
                        Spacer()
                        Button(action: {
                            if selectedTab == 0 {
                                showingAddContact = true
                            } else {
                                showingAddCircleSheet = true
                            }
                        }) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 22, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.green)
                                .clipShape(SwiftUI.Circle())
                                .shadow(color: Color.primaryText.opacity(0.2), radius: 5)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
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
                                await refreshContacts()
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
                isPresented: $showingSampleDialog,
                titleVisibility: .visible
            ) {
                ForEach(SampleModeConfig.availableModes, id: \.id) { mode in
                    Button(mode.title) {
                        Task { await handleSampleModeSelection(mode) }
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .task {
                await loadContacts()
                await loadCircles()
            }
            .onChange(of: refreshTrigger) { _ in
                Task {
                    await loadContacts()
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddContactSheet(refreshTrigger: $refreshTrigger)
            }
            .sheet(isPresented: $showingAddCircleSheet, onDismiss: {
                Task { await loadCircles() }
            }) {
                AddCircleView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            }
            .sheet(isPresented: $showingConfigurationSheet) {
                ConfigurationSheetView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            isViewActive = true
            updateLayout()
            
            // Setup sample mode change observer
            setupSampleModeObserver()
            
            // Refresh contacts when view appears (e.g., when returning from detail view)
            Task {
                await loadContacts()
                await loadCircles()
            }
        }
        .onDisappear {
            isViewActive = false
            
            // Cleanup sample mode observer
            cleanupSampleModeObserver()
        }
        .onChange(of: isViewActive) { newValue in
            if newValue {
                updateLayout()
            }
        }
    }
    
    @State private var showingSampleDialog = false
    @State private var showingCreateContact = false // Placeholder for create action
    @State private var isImportingSample = false
    @State private var errorMessageSample: String? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @State private var refreshTrigger = false
    
    private func handleSampleModeSelection(_ mode: SampleModeConfig.ModeDefinition) async {
        isImportingSample = true
        errorMessageSample = nil
        
        do {
            // Use the new SeedDataManager method to switch scenarios while preserving user data
            try await SeedDataManager.shared.switchToScenario(mode.scenario, in: viewContext)
            
            await MainActor.run {
                appModeManager.isSampleMode = true
                appModeManager.sampleModeType = (mode.id == "indie") ? "indieDev" : mode.id
                refreshTrigger.toggle()
            }
        } catch {
            await MainActor.run {
                errorMessageSample = error.localizedDescription
            }
        }
        isImportingSample = false
        // Optionally trigger refresh in parent
        await refreshContacts()
    }
    
    // Add helper function to get tab bar height
    private func getTabBarHeight() -> CGFloat {
        // Standard tab bar height is 49 points
        let standardTabBarHeight: CGFloat = 49
        
        // Get the bottom safe area inset
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
        
        let bottomInset = keyWindow?.safeAreaInsets.bottom ?? 0
        
        // Return total height including safe area
        return standardTabBarHeight + bottomInset
    }
    
    // Add function to update layout
    private func updateLayout() {
        // Ensure tab bar is visible and properly laid out
        DispatchQueue.main.async {
            if let tabBarController = UIApplication.shared.windows.first?.rootViewController?.children.first as? UITabBarController {
                tabBarController.tabBar.isHidden = false
                tabBarController.view.layoutIfNeeded()
            }
            
            // Force layout update for the entire window
            UIApplication.shared.windows.first?.layoutIfNeeded()
        }
    }
    
    private func setupSampleModeObserver() {
        NotificationCenter.default.addObserver(
            forName: .sampleModeChanged,
            object: nil,
            queue: .main
        ) { _ in
            // Refresh contacts and circles when sample mode changes
            Task {
                await self.loadContacts()
                await self.loadCircles()
            }
        }
    }
    
    private func cleanupSampleModeObserver() {
        NotificationCenter.default.removeObserver(self, name: .sampleModeChanged, object: nil)
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
    let onSampleModeSelected: () async -> Void
    let selectedTab: Int
    
    @State private var showingSampleDialog = false
    @State private var showingCreateContact = false // Placeholder for create action
    @State private var isImportingSample = false
    @State private var errorMessageSample: String? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var appModeManager: AppModeManager
    @State private var refreshTrigger = false
    
    // Add a computed property to ensure we have valid contacts with IDs
    private var validContacts: [Contact] {
        let valid = contacts.compactMap { contact -> (Contact, UUID)? in
            guard let contactId = contact.contactId else {
                return nil
            }
            return (contact, contactId)
        }.map { $0.0 }
        
        return valid
    }
    
    var body: some View {
        Group {
            if isLoading || isImportingSample {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            } else if let error = errorMessage ?? errorMessageSample {
                errorView(message: error)
            } else if validContacts.isEmpty {
                emptyTabView
            } else {
                List {
                    ForEach(validContacts, id: \.contactId) { contact in
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
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: getTabBarHeight())
                }
                .onAppear {
                    // Force layout update when list appears
                    DispatchQueue.main.async {
                        UIApplication.shared.windows.first?.layoutIfNeeded()
                    }
                    // Refresh contacts when view appears (e.g., when returning from detail view)
                    Task {
                        await onRefresh()
                    }
                }
            }
        }
        .confirmationDialog(
            SampleModeConfig.selectionDialogMessage,
            isPresented: $showingSampleDialog,
            titleVisibility: .visible
        ) {
            ForEach(SampleModeConfig.availableModes, id: \.id) { mode in
                Button(mode.title) {
                    Task { await handleSampleModeSelection(mode) }
                }
            }
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
                    Text("\"社交大脑\"将协助管理您的社交网络")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("在这里记录您的社交圈子")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("\"社交大脑\"将协助管理您的社交网络")
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
    }
    
    private func handleSampleModeSelection(_ mode: SampleModeConfig.ModeDefinition) async {
        isImportingSample = true
        errorMessageSample = nil
        
        do {
            // Use the new SeedDataManager method to switch scenarios while preserving user data
            try await SeedDataManager.shared.switchToScenario(mode.scenario, in: viewContext)
            
            await MainActor.run {
                appModeManager.isSampleMode = true
                appModeManager.sampleModeType = (mode.id == "indie") ? "indieDev" : mode.id
                refreshTrigger.toggle()
            }
        } catch {
            await MainActor.run {
                errorMessageSample = error.localizedDescription
            }
        }
        isImportingSample = false
        // Optionally trigger refresh in parent
        await onSampleModeSelected()
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
        guard let contactId = contact.contactId else { return "未知时间" }
        
        // Get the latest note for this contact
        let notes = contactManager.getActiveNotesForContact(contactId: contactId)
        guard let latestNote = notes.max(by: { 
            ($0.updatedAt ?? Date.distantPast) < ($1.updatedAt ?? Date.distantPast) 
        }) else {
            return "暂无笔记"
        }
        
        guard let latestNoteDate = latestNote.updatedAt else { return "未知时间" }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: latestNoteDate, to: now)
        
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


// Add CircleListView component before SocialContactView_Previews
struct CircleListView: View {
    let circles: [Circle]
    let isLoading: Bool
    let errorMessage: String?
    let isRefreshing: Bool
    @Binding var searchText: String
    let onRefresh: () async -> Void
    let onSampleModeSelected: () async -> Void
    
    @State private var showingCreateCircle = false
    @State private var showingSampleDialog = false
    @State private var isImportingSample = false
    @State private var errorMessageSample: String? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var appModeManager: AppModeManager
    @State private var refreshTrigger = false
    
    var filteredCircles: [Circle] {
        let base: [Circle]
        if appModeManager.isSampleMode {
            base = circles.filter { $0.type == 0 }  // Show type=0 circles in sample mode
        } else {
            base = circles.filter { $0.type == 1 }  // Show type=1 circles in non-sample mode
        }
        
        if searchText.isEmpty {
            return base
        }
        return base.filter { circle in
            guard let name = circle.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        }
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
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: getTabBarHeight())
                }
                .onAppear {
                    // Force layout update when list appears
                    DispatchQueue.main.async {
                        UIApplication.shared.windows.first?.layoutIfNeeded()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateCircle) {
            Text("创建圈子功能待实现")
                .font(.title)
                .padding()
        }
        .confirmationDialog(
            SampleModeConfig.selectionDialogMessage,
            isPresented: $showingSampleDialog,
            titleVisibility: .visible
        ) {
            ForEach(SampleModeConfig.availableModes, id: \.id) { mode in
                Button(mode.title) {
                    Task { await handleSampleModeSelection(mode) }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert(isPresented: Binding<Bool>(get: { errorMessageSample != nil }, set: { _ in errorMessageSample = nil })) {
            Alert(title: Text("导入示例数据失败"), message: Text(errorMessageSample ?? "未知错误"), dismissButton: .default(Text("确定")))
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
    }

    private func handleSampleModeSelection(_ mode: SampleModeConfig.ModeDefinition) async {
        isImportingSample = true
        errorMessageSample = nil
        
        do {
            // Use the new SeedDataManager method to switch scenarios while preserving user data
            try await SeedDataManager.shared.switchToScenario(mode.scenario, in: viewContext)
            
            await MainActor.run {
                appModeManager.isSampleMode = true
                appModeManager.sampleModeType = (mode.id == "indie") ? "indieDev" : mode.id
                refreshTrigger.toggle()
            }
        } catch {
            await MainActor.run {
                errorMessageSample = error.localizedDescription
            }
        }
        isImportingSample = false
        // Optionally trigger refresh in parent
        await onSampleModeSelected()
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
        
        SocialContactView()
            .environment(\.colorScheme, .dark)
    }
}
