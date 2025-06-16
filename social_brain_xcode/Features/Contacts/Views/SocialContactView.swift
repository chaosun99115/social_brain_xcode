import SwiftUI
import CoreData

// MARK: - SocialContactView
// Optimized refresh logic to reduce frequent refresh splashes:
// 1. Debounced refresh operations (1 second interval)
// 2. Separate initial load from refresh operations
// 3. Smart refresh on view activation (only when returning from detail views)
// 4. Consolidated notification observers
// 5. Removed redundant refresh calls from child views

struct SocialContactView: View {
    @State private var searchText = ""
    @State private var selectedTab = 0 // 0 for 熟人, 1 for 圈子
    @EnvironmentObject var appModeManager: AppModeManager
    @EnvironmentObject var tabBarManager: TabBarManager
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
    
    // Drag-to-back gesture state
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @Environment(\.presentationMode) var presentationMode
    
    // Sample mode state
    @State private var showingSampleDialog = false
    @State private var showingCreateContact = false // Placeholder for create action
    @State private var isImportingSample = false
    @State private var errorMessageSample: String? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @State private var refreshTrigger = false
    
    // Add debouncing for refresh operations
    @State private var lastRefreshTime: Date = Date(timeIntervalSince1970: 0.0)
    private let refreshDebounceInterval: TimeInterval = 1.0 // 1 second debounce
    
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
    
    // Consolidated refresh function with debouncing
    private func refreshContacts() async {
        // Check if we should debounce this refresh
        let now = Date()
        if now.timeIntervalSince(lastRefreshTime) < refreshDebounceInterval {
            return
        }
        
        await MainActor.run { 
            isRefreshing = true 
            lastRefreshTime = now
        }
        
        // Add a small delay to ensure the refresh control is in the correct state
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Load contacts and circles
        await loadContacts()
        await loadCircles()
        
        await MainActor.run {
            // Reset refresh state
            isRefreshing = false
        }
    }
    
    // Separate function for initial load (no debouncing)
    private func initialLoad() async {
        await MainActor.run { isLoading = true }
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
        
        // Apply search filter
        let searchFiltered: [Contact]
        if searchText.isEmpty {
            searchFiltered = filtered
        } else {
            searchFiltered = filtered.filter { contact in
                guard let name = contact.name else { return false }
                return name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort contacts by latest note update time (descending - newest first)
        return searchFiltered.sorted { contact1, contact2 in
            let latestDate1 = getLatestNoteUpdateDate(for: contact1)
            let latestDate2 = getLatestNoteUpdateDate(for: contact2)
            
            // Handle cases where contacts have no notes
            // Contacts with notes should come before contacts without notes
            if latestDate1 == nil && latestDate2 == nil {
                // Both have no notes, sort by name
                return (contact1.name ?? "") < (contact2.name ?? "")
            } else if latestDate1 == nil {
                return false // contact1 goes after contact2
            } else if latestDate2 == nil {
                return true // contact1 goes before contact2
            } else {
                // Both have notes, sort by latest update time (descending)
                return latestDate1! > latestDate2!
            }
        }
    }
    
    // Helper function to get the latest note update date for a contact
    private func getLatestNoteUpdateDate(for contact: Contact) -> Date? {
        guard let contactId = contact.contactId else { return nil }
        
        let notes = contactManager.getActiveNotesForContact(contactId: contactId)
        guard let latestNote = notes.max(by: { 
            ($0.updatedAt ?? Date.distantPast) < ($1.updatedAt ?? Date.distantPast) 
        }) else {
            return nil
        }
        
        return latestNote.updatedAt
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
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
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.4), value: selectedTab)
                }
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow dragging from the left edge (first 50 points)
                            let startLocation = value.startLocation
                            if startLocation.x < 50 && value.translation.width > 0 {
                                isDragging = true
                                // Limit drag to positive values (rightward movement)
                                dragOffset = min(value.translation.width, UIScreen.main.bounds.width * 0.3)
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            let threshold: CGFloat = 100
                            
                            if dragOffset > threshold {
                                // Dismiss the view
                                withAnimation(.easeOut(duration: 0.3)) {
                                    dragOffset = UIScreen.main.bounds.width
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            } else {
                                // Snap back to original position
                                withAnimation(.easeOut(duration: 0.3)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                
                // Floating Action Button as overlay
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
                
                // Show overlay spinner only during refresh
                if isRefreshing && !isLoading {
                    Color.primaryBackground.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
                
                // Visual feedback during drag
                if isDragging && dragOffset > 0 {
                    HStack {
                        // Semi-transparent overlay on the left
                        Color.black.opacity(0.3 * (dragOffset / UIScreen.main.bounds.width))
                            .frame(width: dragOffset)
                            .ignoresSafeArea()
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("关系")
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
                await initialLoad()
            }
            .onChange(of: refreshTrigger) { _ in
                Task {
                    await refreshContacts()
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddContactSheet(refreshTrigger: $refreshTrigger)
            }
            .sheet(isPresented: $showingAddCircleSheet, onDismiss: {
                // Only refresh if we actually added a circle (we could add a flag for this)
                // For now, let's be conservative and not refresh automatically
                // The user can manually refresh if needed
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
            
            // Setup sample mode change observer
            setupSampleModeObserver()
            
            // Only do initial load, don't refresh on every appear
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Handle app returning from background - ensure proper state restoration
            if isViewActive {
                Task {
                    // Small delay to ensure proper state restoration
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    await refreshContacts()
                }
            }
        }
        .onDisappear {
            isViewActive = false
            
            // Cleanup sample mode observer
            cleanupSampleModeObserver()
        }
        .onChange(of: isViewActive) { newValue in
            if newValue {
                // Only refresh if we have a specific reason to do so
                // Remove the automatic refresh on every activation
            }
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
        // Use debounced refresh instead of direct call
        await refreshContacts()
    }
    
    private func setupSampleModeObserver() {
        NotificationCenter.default.addObserver(
            forName: .sampleModeChanged,
            object: nil,
            queue: .main
        ) { _ in
            // Refresh contacts and circles when sample mode changes
            Task {
                await self.refreshContacts()
            }
        }
        
        // Add observer for iCloud sync refresh notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshContactsList"),
            object: nil,
            queue: .main
        ) { notification in
            // Refresh contacts and circles when iCloud sync completes
            Task {
                await self.refreshContacts()
            }
        }
        
        // Add observer for circles refresh notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshCirclesList"),
            object: nil,
            queue: .main
        ) { notification in
            // Refresh contacts and circles when iCloud sync completes
            Task {
                await self.refreshContacts()
            }
        }
    }
    
    private func cleanupSampleModeObserver() {
        NotificationCenter.default.removeObserver(self, name: .sampleModeChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("RefreshContactsList"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("RefreshCirclesList"), object: nil)
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
    @EnvironmentObject var tabBarManager: TabBarManager
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
                        NavigationLink(destination: SocialContactDetailView(contact: contact)
                            .environmentObject(tabBarManager)) {
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
                    Text("在这里记录你人际网络里的熟人")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("在这里记录你人际网络里的圈子")
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
        // Use debounced refresh instead of direct call
        await onSampleModeSelected()
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
    @EnvironmentObject var tabBarManager: TabBarManager
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
                        NavigationLink(destination: CircleDetailView(circle: circle)
                            .environmentObject(tabBarManager)) {
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
        // Use debounced refresh instead of direct call
        await onSampleModeSelected()
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
