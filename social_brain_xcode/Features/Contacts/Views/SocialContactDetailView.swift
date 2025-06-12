import SwiftUI
import CoreData

struct SocialContactDetailView: View {
    let contact: Contact
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appModeManager: AppModeManager
    @StateObject private var contactManager = ContactManager.shared
    @StateObject private var insightManager = ContactInsightManager.shared
    @State private var notes: [Note] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var contactInsights: [ContactInsight] = []
    @State private var isLoadingInsights = true
    @State private var selectedInsight: ContactInsight?
    @State private var selectedContacts: Set<UUID> = []
    @State private var showingEditSheet = false
    @State private var showingSocialBrain = false
    @State private var showingEditCircleSheet = false
    @State private var isUpdatesExpanded = false
    @State private var isReviewsExpanded = false
    @State private var showingEditContactSheet = false
    @State private var refreshTrigger = false
    @State private var showingNoteModal = false
    @State private var currentContact: Contact // Add state to track the current contact
    
    init(contact: Contact) {
        self.contact = contact
        self._currentContact = State(initialValue: contact)
    }
    
    // Add property to determine if this is a contact view
    private var isContactView: Bool {
        // Since this view is specifically for contacts, we'll always return true
        return true
    }
    
    // Context parameters for SocialBrain
    private var socialBrainContext: (sourceType: String, sourceAction: String, sourceId: String) {
        return (
            sourceType: "contact",
            sourceAction: "general",
            sourceId: currentContact.contactId?.uuidString ?? ""
        )
    }
    
    var body: some View {
        ZStack {
            Color.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Single scrollable content view
                ScrollView {
                    VStack(spacing: 40) {
                        // Basic Info Section
                        basicInfoSectionView
                        
                        // Notes Section
                        notesSectionView
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100) // Extra padding for bottom toolbar
                }
                
                // Fixed bottom toolbar that respects safe areas
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 0) {
                        // AI Insights button
                        Button(action: {
                            showingSocialBrain = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20))
                                Text("关系备忘录")
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 44)
                    .padding(.bottom, safeAreaInset)
                }
                .background(
                    VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(currentContact.name ?? "联系人")
        .sheet(isPresented: $showingSocialBrain) {
            SocialBrainSheetView(
                sourceType: socialBrainContext.sourceType,
                sourceAction: socialBrainContext.sourceAction,
                sourceId: socialBrainContext.sourceId,
                initialContact: currentContact
            )
            .environmentObject(appModeManager)
        }
        .sheet(isPresented: $showingEditCircleSheet) {
            EditContactCirclesSheet(
                contact: contact,
                isPresented: $showingEditCircleSheet
            )
        }
        .fullScreenCover(isPresented: $showingEditContactSheet) {
            EditContactView(contact: currentContact, refreshTrigger: $refreshTrigger)
        }
        .sheet(isPresented: $showingNoteModal) {
            SimpleNoteModalView(
                initialText: "",
                subType: .interactionRecord,
                modalTitle: "记录与\(currentContact.name ?? "联系人")的互动",
                onSave: { _ in
                    loadContactNotes()
                }
            )
            .environmentObject(NoteManager.shared)
            .environmentObject(appModeManager)
        }
        .onChange(of: refreshTrigger) { _ in
            // Reload data when contact is updated
            refreshContactData()
            loadContactNotes()
            loadContactInsights()
        }
        .onAppear {
            loadContactNotes()
            loadContactInsights()
            // Hide the tab bar
            hideTabBar(true)
            
            // Setup notification observers for iCloud sync
            setupNotificationObservers()
        }
        .onDisappear {
            // Show the tab bar again when leaving this view
            hideTabBar(false)
            
            // Cleanup notification observers
            cleanupNotificationObservers()
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // Dynamic safe area inset for different devices (HIG compliant)
    private var safeAreaInset: CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
        return keyWindow?.safeAreaInsets.bottom ?? 0
    }
    
    // UIViewRepresentable wrapper for UIVisualEffectView to use blur effects
    struct VisualEffectView: UIViewRepresentable {
        var effect: UIVisualEffect?
        
        func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
            UIVisualEffectView()
        }
        
        func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
            uiView.effect = effect
        }
    }
    
    // Function to hide/show the tab bar
    private func hideTabBar(_ hidden: Bool) {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
            
        if let keyWindow = keyWindow {
            keyWindow.rootViewController?.children.forEach { child in
                // Find the UITabBarController and hide its tabBar
                if let tabBarController = child as? UITabBarController {
                    tabBarController.tabBar.isHidden = hidden
                }
            }
        }
    }
    
    private func loadContactNotes() {
        guard let contactId = contact.contactId else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Load notes using ContactManager - only active (non-archived) notes
        DispatchQueue.main.async {
            let activeNotes = self.contactManager.getActiveNotesForContact(contactId: contactId)
            
            // Sort notes by date descending
            self.notes = activeNotes.sorted { (note1, note2) -> Bool in
                let date1 = note1.createdAt ?? Date.distantPast
                let date2 = note2.createdAt ?? Date.distantPast
                return date1 > date2
            }
            
            self.isLoading = false
        }
    }
    
    private func loadContactInsights() {
        isLoadingInsights = true
        guard let contactId = currentContact.contactId else { contactInsights = []; isLoadingInsights = false; return }
        
        // Fetch insights directly for this contact
        contactInsights = insightManager.getInsightsForContact(contactId: contactId)
        
        // Sort by order
        contactInsights.sort { (a, b) in
            a.order < b.order
        }
        
        isLoadingInsights = false
    }
    
    // Function to refresh contact data from Core Data
    private func refreshContactData() {
        guard let contactId = currentContact.contactId else { return }
        
        // Fetch the updated contact from Core Data
        if let updatedContact = contactManager.fetchContact(withId: contactId) {
            currentContact = updatedContact
        }
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        // Add observer for iCloud sync refresh notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshContactsList"),
            object: nil,
            queue: .main
        ) { _ in
            // Refresh contact data when iCloud sync completes
            self.refreshContactData()
            self.loadContactNotes()
            self.loadContactInsights()
        }
        
        // Add observer for notes refresh notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshNotesList"),
            object: nil,
            queue: .main
        ) { _ in
            // Refresh contact notes when iCloud sync completes
            self.loadContactNotes()
        }
    }
    
    private func cleanupNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("RefreshContactsList"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("RefreshNotesList"), object: nil)
    }
    
    // MARK: - Basic Info Section
    private var basicInfoSectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text("基本信息")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Button(action: {
                    showingEditContactSheet = true
                }) {
                    Text("编辑")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Name Field - Always show since it's required
                CompactContactInfoField(
                    placeholder: "姓名",
                    text: contact.name,
                    isMultiline: false
                )
                .padding(.top, 12)
                
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                
                // Telephone Field - Show with placeholder if nil
                CompactContactInfoField(
                    placeholder: "电话",
                    text: contact.tel,
                    isMultiline: false
                )
                
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                
                // Birthday Field - Show with placeholder if nil
                VStack(alignment: .leading, spacing: 0) {
                    Text("生日")
                        .foregroundColor(.black)
                        .font(.subheadline)
                        .padding(.top, 8)
                        .padding(.leading, 16)
                    
                    HStack {
                        if let birthday = contact.birthday {
                            Text(dateFormatter.string(from: birthday))
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        } else {
                            Text("未设置")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                    .frame(height: 32)
                }
                .background(Color(.systemBackground))
                
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                
                // Memo Section - Always show but with placeholder if empty
                CompactContactInfoField(
                    placeholder: "其他信息",
                    text: contact.memo,
                    isMultiline: true,
                    defaultHeight: 40
                )
            }
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
    }
    
    // Add date formatter for birthday display
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    // MARK: - Notes Section
    private var notesSectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text("相关笔记")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Button(action: {
                    showingNoteModal = true
                }) {
                    Text("新增笔记")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Content
            VStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding()
                } else if let error = errorMessage {
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Button("Retry") {
                        loadContactNotes()
                    }
                    .padding()
                } else if notes.isEmpty {
                    VStack(spacing: 12) {
                        Text("还没有关于\(contact.name ?? "该联系人")的笔记")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(notes, id: \.noteId) { note in
                        NavigationLink(destination: NoteDetailNav(note: note)) {
                            NoteCardView(note: note)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Mock Data
    private var contactSummaries: [ContactSummaryEntity] {
        // For now, we'll keep using mock data for the summaries
        // In a real implementation, this would come from CoreData or an API
        let name = contact.name ?? "this contact"
        
        return [
            // Updates
            ContactSummaryEntity(
                id: UUID(),
                type: .update,
                content: "你和\(name)两天之前聊过，他正在开发自己的一款移动应用，叫做社交大脑。",
                actionText: "查看相关笔记"
            ),
            
            // Connections
            ContactSummaryEntity(
                id: UUID(),
                type: .connection,
                content: "你与\(name)是通过灵买的平台认识的",
                actionText: nil
            ),
            ContactSummaryEntity(
                id: UUID(),
                type: .connection,
                content: "你下载使用社交大脑之后，可以给他发个信息告诉他你的使用体验",
                actionText: nil
            ),
            ContactSummaryEntity(
                id: UUID(),
                type: .connection,
                content: "你在三个月前与 李经理 聊过职业转型的想法，下次遇见\(name)，也许你可以了解下他的转型经历，看看会不会给自己带来启发",
                actionText: nil
            )
        ]
    }
    
    private var relatedNotesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("related_notes")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if !notes.isEmpty {
                    Text("\(notes.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.primaryAction.opacity(0.15))
                        )
                        .foregroundColor(Color.primaryAction)
                }
            }
            
            if notes.isEmpty {
                Text("no_notes")
                    .font(.subheadline)
                    .foregroundColor(.tertiaryText)
                    .padding(.vertical, 10)
            } else {
                Button(action: {
                    // View all notes action
                }) {
                    Text("view_all_notes")
                        .font(.subheadline)
                        .foregroundColor(.primaryAction)
                        .padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Supporting Views
struct NoteCardView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(formattedDate(for: note.createdAt ?? Date()))
                .font(.headline)
                .foregroundColor(.secondaryText)
            
            if let content = note.content {
                MentionTextView(text: content, preserveEmptyLines: false)
                    .font(.body)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.primaryText.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.divider, lineWidth: 0.5)
        )
        .padding(.bottom, 8)
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

struct SummarySectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 16)
    }
}

struct ContactSummaryRow: View {
    let item: ContactSummaryEntity
    let isLast: Bool
    
    init(item: ContactSummaryEntity, isLast: Bool = false) {
        self.item = item
        self.isLast = isLast
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Bullet point
                SwiftUI.Circle()
                    .foregroundColor(Color.tertiaryText)
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.content)
                        .font(.system(size: 16))
                        .foregroundColor(.primaryText)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Action button
                    if let actionText = item.actionText {
                        Button(action: {
                            // Action handler
                        }) {
                            Text(actionText)
                                .font(.system(size: 15))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .foregroundColor(.white)
                                .background(Color.primaryAction)
                                .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            
            if !isLast {
                Divider()
                    .padding(.leading, 22)
                    .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Models
struct ContactSummaryEntity: Identifiable {
    enum SummaryType: Int {
        case update = 0
        case connection = 1
    }
    
    let id: UUID
    let type: SummaryType
    let content: String
    let actionText: String?
}

// MARK: - Previews
struct SocialContactDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let previewContext = CoreDataManager.shared.viewContext
        let contact = Contact(context: previewContext)
        contact.name = "Preview Contact"
        contact.contactId = UUID()
        contact.createdAt = Date()
        
        return SocialContactDetailView(contact: contact)
            .environment(\.colorScheme, .light)
    }
}

// New SectionContentWrapper view
struct SectionContentWrapper<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Supporting Views
struct ContactDetailInsightRow: View {
    let insight: ContactInsight
    let isLast: Bool
    let onTap: (() -> Void)?

    init(insight: ContactInsight, isLast: Bool = false, onTap: (() -> Void)? = nil) {
        self.insight = insight
        self.isLast = isLast
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                SwiftUI.Circle()
                    .foregroundColor(Color.tertiaryText)
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 8) {
                    Text(insight.content ?? "")
                        .font(.system(size: 16))
                        .foregroundColor(.primaryText)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !isLast {
                Divider()
                    .padding(.leading, 22)
                    .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - EditContactCirclesSheet
struct EditContactCirclesSheet: View {
    let contact: Contact
    @Binding var isPresented: Bool
    @StateObject private var circleManager = CircleManager.shared
    @State private var allCircles: [Circle] = []
    @State private var selectedCircleIds: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(allCircles, id: \ .circleId) { circle in
                    HStack {
                        Text(circle.name ?? "圈子")
                        Spacer()
                        CheckboxView(isChecked: selectedCircleIds.contains(circle.circleId ?? UUID())) {
                            toggleCircle(circle)
                        }
                    }
                }
            }
            .navigationTitle("选择所属圈子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                loadCircles()
            }
        }
    }
    
    private func loadCircles() {
        allCircles = circleManager.fetchCircles()
        if let contactId = contact.contactId {
            let related = circleManager.getCirclesForContact(contactId: contactId)
            selectedCircleIds = Set(related.compactMap { $0.circleId })
        }
    }
    
    private func toggleCircle(_ circle: Circle) {
        guard let circleId = circle.circleId, let contactId = contact.contactId else { return }
        if selectedCircleIds.contains(circleId) {
            // Remove
            if circleManager.removeContactFromCircle(circleId: circleId, contactId: contactId) {
                selectedCircleIds.remove(circleId)
            }
        } else {
            // Add
            if circleManager.addContactToCircle(circleId: circleId, contactId: contactId) {
                selectedCircleIds.insert(circleId)
            }
        }
    }
}

struct CheckboxView: View {
    var isChecked: Bool
    var onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .foregroundColor(isChecked ? .accentColor : .secondary)
                .font(.system(size: 22))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Update ContactInfoField to handle empty state
struct ContactInfoField: View {
    let placeholder: String
    let text: String?
    let isMultiline: Bool
    let defaultHeight: CGFloat?
    
    // Constants for sizing
    private let minHeight: CGFloat = 44
    private let maxHeight: CGFloat = 200
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 12
    
    init(placeholder: String, text: String?, isMultiline: Bool, defaultHeight: CGFloat? = nil) {
        self.placeholder = placeholder
        self.text = text
        self.isMultiline = isMultiline
        self.defaultHeight = defaultHeight
    }
    
    private var displayText: String {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedText.isEmpty ? "未设置" : trimmedText
    }
    
    private var isEmpty: Bool {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedText.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color(.systemBackground)
                .cornerRadius(0)
            
            VStack(alignment: .leading, spacing: 0) {
                // Fixed label
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.top, verticalPadding)
                    .padding(.leading, horizontalPadding)
                
                // Text display area
                if isMultiline {
                    Text(displayText)
                        .font(.body)
                        .foregroundColor(isEmpty ? .secondary : .primary)
                        .frame(minHeight: defaultHeight ?? minHeight, maxHeight: maxHeight, alignment: .topLeading)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 4)
                        .background(Color.clear)
                } else {
                    Text(displayText)
                        .font(.body)
                        .foregroundColor(isEmpty ? .secondary : .primary)
                        .frame(height: minHeight, alignment: .leading)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 4)
                        .background(Color.clear)
                }
            }
        }
    }
}

// MARK: - Compact Contact Info Field
struct CompactContactInfoField: View {
    let placeholder: String
    let text: String?
    let isMultiline: Bool
    let defaultHeight: CGFloat?
    
    // Constants for compact sizing
    private let minHeight: CGFloat = 32
    private let maxHeight: CGFloat = 120
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 8
    
    init(placeholder: String, text: String?, isMultiline: Bool, defaultHeight: CGFloat? = nil) {
        self.placeholder = placeholder
        self.text = text
        self.isMultiline = isMultiline
        self.defaultHeight = defaultHeight
    }
    
    private var displayText: String {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedText.isEmpty ? "未设置" : trimmedText
    }
    
    private var isEmpty: Bool {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedText.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color(.systemBackground)
                .cornerRadius(0)
            
            VStack(alignment: .leading, spacing: 0) {
                // Fixed label - use system black color
                Text(placeholder)
                    .foregroundColor(.black)
                    .font(.subheadline)
                    .padding(.top, verticalPadding)
                    .padding(.leading, horizontalPadding)
                
                // Text display area - use system grey color for values
                if isMultiline {
                    Text(displayText)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(minHeight: defaultHeight ?? minHeight, maxHeight: maxHeight, alignment: .topLeading)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 2)
                        .background(Color.clear)
                } else {
                    Text(displayText)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(height: minHeight, alignment: .leading)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 2)
                        .background(Color.clear)
                }
            }
        }
    }
}

