import SwiftUI
import CoreData

struct SocialContactDetailView: View {
    let contact: Contact
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appModeManager: AppModeManager
    @StateObject private var contactManager = ContactManager.shared
    @StateObject private var insightManager = ContactInsightManager.shared
    @State private var activeTab: TabType = .summary
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
    
    // Context parameters for SocialBrain
    private var socialBrainContext: (sourceType: String, sourceAction: String, sourceId: String) {
        return (
            sourceType: "contact",
            sourceAction: "general",
            sourceId: contact.contactId?.uuidString ?? ""
        )
    }
    
    enum TabType: String, CaseIterable {
        case summary = "关系备忘录"
        case notes = "关联笔记"
        
        var localizedName: String {
            switch self {
            case .summary: return "关系备忘录"
            case .notes: return "关联笔记"
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
                
                // Divider under tabs
                Divider()
                
                // Content based on active tab
                ScrollView {
                    if activeTab == .summary {
                        summarySectionView
                    } else {
                        notesSectionView
                    }
                }
                
                // Fixed bottom toolbar that respects safe areas
                VStack(spacing: 0) {
                    Divider()
                    
                    // Bottom toolbar content
                    HStack(spacing: 0) {
                        // AI Insights button
                        Button(action: {
                            showingSocialBrain = true
                        }) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 44)
                    .padding(.bottom, safeAreaPadding)
                }
                .background(
                    VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                        .ignoresSafeArea()
                )
            }
        }
        .navigationTitle(contact.name ?? "Contact")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17))
                        Text("back")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.primaryAction)
                }
            }
        }
        .sheet(isPresented: $showingSocialBrain) {
            SocialBrainView(
                sourceType: socialBrainContext.sourceType,
                sourceAction: socialBrainContext.sourceAction,
                sourceId: socialBrainContext.sourceId
            )
            .environmentObject(appModeManager)
            .onAppear {
                print("[SocialContactDetailView] Opening SocialBrainView with context: type=\(socialBrainContext.sourceType), action=\(socialBrainContext.sourceAction), id=\(socialBrainContext.sourceId)")
            }
        }
        .sheet(isPresented: $showingEditCircleSheet) {
            EditContactCirclesSheet(
                contact: contact,
                isPresented: $showingEditCircleSheet
            )
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
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // Dynamic safe area padding for different devices
    private var safeAreaPadding: CGFloat {
        // Get the bottom safe area inset
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
            
        let bottomInset = keyWindow?.safeAreaInsets.bottom ?? 0
        
        // Add padding based on whether device has home indicator
        return bottomInset > 0 ? bottomInset + 8 : 8
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
            self.notes = contactManager.getNotesForContact(contactId: contactId)
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
        
        print("\n--- ContactInsight Debug Log ---")
        print("Current Contact ID: \(contactId)")
        print("Related insights count: \(contactInsights.count)")
        for insight in contactInsights {
            print("Insight [id: \(insight.insightId?.uuidString ?? "nil")] category: \(insight.category ?? "nil") content: \(insight.content ?? "nil")")
        }
        print("--- End ContactInsight Debug Log ---\n")
        
        isLoadingInsights = false
    }
    
    // MARK: - Summary Section
    private var summarySectionView: some View {
        VStack(spacing: 0) {
            // --- Related Circles Section ---
            if let contactId = contact.contactId {
                let relatedCircles = CircleManager.shared.getCirclesForContact(contactId: contactId)
                if !relatedCircles.isEmpty {
                    SummarySectionHeader(title: "所属圈子")
                    HStack(alignment: .center, spacing: 0) {
                        HStack(spacing: 8) {
                            ForEach(relatedCircles, id: \ .circleId) { circle in
                                NavigationLink(destination: CircleDetailView(circle: circle)) {
                                    Text(circle.name ?? "圈子")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.12))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        Spacer()
                        Button(action: {
                            showingEditCircleSheet = true
                        }) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color.blue)
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            if isLoadingInsights {
                ProgressView().padding()
            } else {
                // 最新近况
                let updates = contactInsights.filter { $0.category?.lowercased() == "update" }
                if !updates.isEmpty {
                    SummarySectionHeader(title: "最新近况")
                    SectionContentWrapper {
                        VStack(alignment: .leading, spacing: 0) {
                            let displayUpdates = isUpdatesExpanded ? updates : Array(updates.prefix(3))
                            ForEach(Array(displayUpdates.enumerated()), id: \.element.insightId) { idx, insight in
                                ContactDetailInsightRow(
                                    insight: insight,
                                    isLast: idx == displayUpdates.count - 1,
                                    onTap: {
                                        selectedInsight = insight
                                        if let insightId = insight.insightId {
                                            selectedContacts = Set(insightManager.getContactsForInsight(insightId: insightId).compactMap { $0.contactId })
                                        }
                                        showingEditSheet = true
                                    }
                                )
                            }
                            
                            if updates.count > 3 {
                                Divider()
                                    .padding(.leading, 22)
                                    .padding(.vertical, 8)
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isUpdatesExpanded.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text(isUpdatesExpanded ? "收起" : "展开更多")
                                            .font(.system(size: 15))
                                            .foregroundColor(.primaryAction)
                                        Image(systemName: isUpdatesExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 13))
                                            .foregroundColor(.primaryAction)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                    }
                }
                
                // 关系回顾
                let reviews = contactInsights.filter { $0.category?.lowercased() == "review" }
                if !reviews.isEmpty {
                    SummarySectionHeader(title: "关系回顾")
                    SectionContentWrapper {
                        VStack(alignment: .leading, spacing: 0) {
                            let displayReviews = isReviewsExpanded ? reviews : Array(reviews.prefix(3))
                            ForEach(Array(displayReviews.enumerated()), id: \.element.insightId) { idx, insight in
                                ContactDetailInsightRow(
                                    insight: insight,
                                    isLast: idx == displayReviews.count - 1,
                                    onTap: {
                                        selectedInsight = insight
                                        if let insightId = insight.insightId {
                                            selectedContacts = Set(insightManager.getContactsForInsight(insightId: insightId).compactMap { $0.contactId })
                                        }
                                        showingEditSheet = true
                                    }
                                )
                            }
                            
                            if reviews.count > 3 {
                                Divider()
                                    .padding(.leading, 22)
                                    .padding(.vertical, 8)
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isReviewsExpanded.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text(isReviewsExpanded ? "收起" : "展开更多")
                                            .font(.system(size: 15))
                                            .foregroundColor(.primaryAction)
                                        Image(systemName: isReviewsExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 13))
                                            .foregroundColor(.primaryAction)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                    }
                }
            }
            Spacer().frame(height: 40)
        }
        .padding(.top, 16)
    }
    
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
                Text("No notes for this contact")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
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
            
            // Topics
            ContactSummaryEntity(
                id: UUID(),
                type: .topic,
                content: "\(name)之前做过一次针对App的demo演示，下次遇见可以问问app的开发进展如何了",
                actionText: nil
            ),
            ContactSummaryEntity(
                id: UUID(),
                type: .topic,
                content: "\(name)喜欢阅读，可以问问他有新读了哪些书",
                actionText: nil
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
        case topic = 1
        case connection = 2
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
