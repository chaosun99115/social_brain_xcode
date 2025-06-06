import SwiftUI
import CoreData

struct SocialContactDetailView: View {
    let contact: Contact
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appModeManager: AppModeManager
    @StateObject private var contactManager = ContactManager.shared
    @StateObject private var insightManager = ContactInsightManager.shared
    @State private var activeTab: TabType = .basicInfo
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
            sourceId: contact.contactId?.uuidString ?? ""
        )
    }
    
    enum TabType: String, CaseIterable {
        case basicInfo = "基本信息"
        case notes = "相关笔记"
        
        var localizedName: String {
            switch self {
            case .basicInfo: return "基本信息"
            case .notes: return "相关笔记"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tabs
                HStack(spacing: 0) {
                    ForEach(TabType.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeTab = tab
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(tab.localizedName)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(activeTab == tab ? .primaryText : .secondaryText)
                                
                                // Active indicator
                                Rectangle()
                                    .fill(activeTab == tab ? Color.primaryText : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 0)
                
                // Content based on active tab
                Group {
                    switch activeTab {
                    case .basicInfo:
                        ScrollView {
                            basicInfoSectionView
                        }
                    case .notes:
                        ScrollView {
                            notesSectionView
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
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
        .navigationTitle(contact.name ?? "联系人")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.accentColor)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingEditContactSheet = true
                }) {
                    Text("编辑")
                        .font(.system(size: 17))
                        .foregroundColor(.green)
                }
            }
        }
        .sheet(isPresented: $showingSocialBrain) {
            SocialBrainSheetView(
                sourceType: socialBrainContext.sourceType,
                sourceAction: socialBrainContext.sourceAction,
                sourceId: socialBrainContext.sourceId
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
            EditContactView(contact: contact, refreshTrigger: $refreshTrigger)
        }
        .onAppear {
            loadContactNotes()
            loadContactInsights()
            // Hide the tab bar
            hideTabBar(true)
        }
        .onDisappear {
            // Show the tab bar again when leaving this view
            hideTabBar(false)
        }
        .onChange(of: refreshTrigger) { _ in
            // Reload data when contact is updated
            loadContactNotes()
            loadContactInsights()
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
        
        // Load notes using ContactManager
        DispatchQueue.main.async {
            let allNotes = self.contactManager.getNotesForContact(contactId: contactId)
            
            // Sort notes by date descending
            self.notes = allNotes.sorted { (note1, note2) -> Bool in
                let date1 = note1.createdAt ?? Date.distantPast
                let date2 = note2.createdAt ?? Date.distantPast
                return date1 > date2
            }
            
            self.isLoading = false
        }
    }
    
    private func loadContactInsights() {
        isLoadingInsights = true
        guard let contactId = contact.contactId else { contactInsights = []; isLoadingInsights = false; return }
        
        // Fetch insights directly for this contact
        contactInsights = insightManager.getInsightsForContact(contactId: contactId)
        
        // Sort by order
        contactInsights.sort { (a, b) in
            a.order < b.order
        }
        
        isLoadingInsights = false
    }
    
    // MARK: - Basic Info Section
    private var basicInfoSectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Name Field
            ContactInfoField(
                placeholder: "姓名",
                text: contact.name ?? "",
                isMultiline: false
            )
            .padding(.top, 24)
            
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            // Telephone Field
            ContactInfoField(
                placeholder: "电话",
                text: contact.tel ?? "",
                isMultiline: false
            )
            
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            // Birthday Field
            VStack(alignment: .leading, spacing: 0) {
                Text("生日")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.top, 12)
                    .padding(.leading, 16)
                
                HStack {
                    if let birthday = contact.birthday {
                        Text(dateFormatter.string(from: birthday))
                            .foregroundColor(.primary)
                            .font(.body)
                    } else {
                        Text("")
                            .foregroundColor(.primary)
                            .font(.body)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 44)
            }
            .background(Color(.systemBackground))
            
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            // Memo Section - New Implementation
            if let memo = contact.memo, !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("备注")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .padding(.top, 12)
                        .padding(.leading, 16)
                    
                    Text(memo)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(.systemBackground))
                
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 0)
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
                    Spacer()
                    Text("还没有关于\(contact.name ?? "该联系人")的笔记")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(notes, id: \.noteId) { note in
                    NavigationLink(destination: SocialNoteDetailView(note: note)) {
                        NoteCardView(note: note)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Spacer at the bottom for better scrolling
            Spacer().frame(height: 40)
        }
        .padding(.top, 16)
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
                MentionTextView(text: content)
                    .font(.body)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.primaryText.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.divider, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
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

// Add new ContactInfoField view for read-only display
struct ContactInfoField: View {
    let placeholder: String
    let text: String
    let isMultiline: Bool
    let defaultHeight: CGFloat?
    
    // Constants for sizing
    private let minHeight: CGFloat = 44
    private let maxHeight: CGFloat = 200
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 12
    
    init(placeholder: String, text: String, isMultiline: Bool, defaultHeight: CGFloat? = nil) {
        self.placeholder = placeholder
        self.text = text
        self.isMultiline = isMultiline
        self.defaultHeight = defaultHeight
    }
    
    var body: some View {
        // Only show the field if there's actual content
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                        Text(text)
                            .font(.body)
                            .frame(minHeight: defaultHeight ?? minHeight, maxHeight: maxHeight, alignment: .topLeading)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.vertical, 4)
                            .background(Color.clear)
                    } else {
                        Text(text)
                            .font(.body)
                            .frame(height: minHeight, alignment: .leading)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.vertical, 4)
                            .background(Color.clear)
                    }
                }
            }
        }
    }
}
