import SwiftUI

struct SocialContactDetailView: View {
    let contact: MockContact
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var activeTab: TabType = .summary
    
    enum TabType: String, CaseIterable {
        case summary = "汇总"
        case notes = "笔记"
        
        var localizedName: String {
            switch self {
            case .summary: return "汇总"
            case .notes: return "笔记"
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
            }
        }
        .navigationTitle(contact.name)
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
                        Text("back".localized)
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.primaryAction)
                }
            }
        }
    }
    
    // MARK: - Summary Section
    private var summarySectionView: some View {
        VStack(spacing: 0) {
            
            // Group and display items by type
            Group {
                // Update section
                if !contactSummaries.filter({ $0.type == .update }).isEmpty {
                    SummarySectionHeader(title: "最新动态")
                    
                    SectionContentWrapper {
                        let updateItems = contactSummaries.filter({ $0.type == .update })
                        ForEach(Array(updateItems.enumerated()), id: \.element.id) { index, item in
                            ContactSummaryRow(
                                item: item,
                                isLast: index == updateItems.count - 1
                            )
                        }
                    }
                }
                
                // Topic section
                if !contactSummaries.filter({ $0.type == .topic }).isEmpty {
                    SummarySectionHeader(title: "互动话题")
                
                    SectionContentWrapper {
                        let topicItems = contactSummaries.filter({ $0.type == .topic })
                        ForEach(Array(topicItems.enumerated()), id: \.element.id) { index, item in
                            ContactSummaryRow(
                                item: item,
                                isLast: index == topicItems.count - 1
                            )
                        }
                    }
                }
                
                // Connection section
                if !contactSummaries.filter({ $0.type == .connection }).isEmpty {
                    SummarySectionHeader(title: "关系备忘录")
                    
                    SectionContentWrapper {
                        let connectionItems = contactSummaries.filter({ $0.type == .connection })
                        ForEach(Array(connectionItems.enumerated()), id: \.element.id) { index, item in
                            ContactSummaryRow(
                                item: item,
                                isLast: index == connectionItems.count - 1
                            )
                        }
                    }
                }
            }
            
            // Spacer at the bottom for better scrolling
            Spacer().frame(height: 40)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Notes Section
    private var notesSectionView: some View {
        VStack {
            SocialNotesList(notes: contactNotes, showFullContent: true)
            
            // Spacer at the bottom for better scrolling
            Spacer().frame(height: 40)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Mock Data
    private var contactSummaries: [ContactSummaryEntity] {
        [
            // Updates
            ContactSummaryEntity(
                id: UUID(),
                type: .update,
                content: "你和Chao两天之前聊过，他正在开发自己的一款移动应用，叫做社交大脑。",
                actionText: "查看相关笔记"
            ),
            
            // Topics
            ContactSummaryEntity(
                id: UUID(),
                type: .topic,
                content: "Chao之前做过一次针对App的demo演示，下次遇见可以问问app的开发进展如何了",
                actionText: nil
            ),
            ContactSummaryEntity(
                id: UUID(),
                type: .topic,
                content: "Chao喜欢阅读，可以问问他有新读了哪些书",
                actionText: nil
            ),
            
            // Connections
            ContactSummaryEntity(
                id: UUID(),
                type: .connection,
                content: "你与Chao是通过灵买的平台认识的",
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
                content: "你在三个月前与 李经理 聊过职业转型的想法，下次遇见Chao，也许你可以了解下他的转型经历，看看会不会给自己带来启发",
                actionText: nil
            )
        ]
    }
    
    private var contactNotes: [SocialNote] {
        [
            SocialNote(
                date: Calendar.current.date(from: DateComponents(year: 2023, month: 11, day: 25))!,
                content: "在灵买的平台上与Chao互动过。Chao分享他正在开发一款叫做社交大脑的移动应用。"
            )
        ]
    }
    
    
    private var relatedNotesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("related_notes".localized)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if contact.notesCount > 0 {
                    Text("\(contact.notesCount)")
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
            
            if contact.notesCount == 0 {
                Text("no_notes".localized)
                    .font(.subheadline)
                    .foregroundColor(.tertiaryText)
                    .padding(.vertical, 10)
            } else {
                Button(action: {
                    // View all notes action
                }) {
                    Text("view_all_notes".localized)
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
        SocialContactDetailView(
            contact: MockContact(
                name: "Chao", 
                createdAt: Date().addingTimeInterval(-86400), 
                notesCount: 3
            )
        )
        .environmentObject(LocalizationManager())
        .environment(\.colorScheme, .light)
        
        SocialContactDetailView(
            contact: MockContact(
                name: "Jane", 
                createdAt: Date().addingTimeInterval(-172800), 
                notesCount: 2
            )
        )
        .environmentObject(LocalizationManager())
        .environment(\.colorScheme, .dark)
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
