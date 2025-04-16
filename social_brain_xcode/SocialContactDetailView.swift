import SwiftUI

struct SocialContactDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var activeTab: TabType = .summary
    
    // Hardcoded contact data
    private let contactName = "Manager Li"
    private let latestStatus = "最近一次联系是在上周的部门会议，讨论了新项目的进展。"
    private let relatedNotesCount = 3
    
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
        .navigationTitle(contactName)
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
                    SummarySectionHeader(title: "深化关系")
                    
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
        VStack(spacing: 0) {
            ForEach(contactNotes, id: \.id) { note in
                ContactNoteRow(note: note)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            
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
                content: "李经理最近一次联系是在上周的部门会议，讨论了新项目的进展。",
                actionText: nil
            ),
            ContactSummaryEntity(
                id: UUID(),
                type: .update,
                content: "李经理上周提到他部门已经完成了新数据分析平台的初步设计阶段。",
                actionText: nil
            ),
            
            // Topics
            ContactSummaryEntity(
                id: UUID(),
                type: .topic,
                content: "李经理的女儿刚开始学轮滑，你可以询问孩子的学习体验。（你没有记录过轮滑相关的话题，可以让AI调研一下有什么可以聊的内容）",
                actionText: "AI调研"
            ),
            ContactSummaryEntity(
                id: UUID(),
                type: .topic,
                content: "李经理的部门最近在准备一个项目，遇到李经理可以询问项目的进展。",
                actionText: nil
            ),
            
            // Connections
            ContactSummaryEntity(
                id: UUID(),
                type: .connection,
                content: "张主管是李经理的团队成员，最近与你有过沟通。可以谈谈张主管的表现。",
                actionText: nil
            ),
            ContactSummaryEntity(
                id: UUID(),
                type: .connection,
                content: "王总监是李经理的直属上级，你们上个月在季度会议上有交流。可以询问与王总监合作的情况。",
                actionText: nil
            )
        ]
    }
    
    private var contactNotes: [ContactNote] {
        [
            ContactNote(
                id: UUID(),
                title: "咖啡文化",
                content: "李经理喜欢品尝不同的咖啡，对意式咖啡尤其感兴趣。最近开始研究手冲咖啡的不同器具。",
                date: "2023年11月25日",
                tags: ["兴趣爱好", "咖啡"]
            ),
            ContactNote(
                id: UUID(),
                title: "部门项目",
                content: "李经理部门最近在开发一个新的数据分析平台，预计明年Q1上线。项目进展顺利，团队士气高涨。",
                date: "2023年11月10日",
                tags: ["工作", "项目"]
            ),
            ContactNote(
                id: UUID(),
                title: "女儿学习轮滑",
                content: "李经理的女儿最近开始学习轮滑，年龄6岁，每周末去公园练习。李经理表示孩子很喜欢，但也有些担心安全问题。",
                date: "2023年10月15日",
                tags: ["家庭", "孩子", "轮滑"]
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
                
                if relatedNotesCount > 0 {
                    Text("\(relatedNotesCount)")
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
            
            if relatedNotesCount == 0 {
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
            .padding(.top, 28)
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
                Circle()
                    .fill(Color.tertiaryText)
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

struct ContactNoteRow: View {
    let note: ContactNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and date
            HStack {
                Text(note.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Text(note.date)
                    .font(.system(size: 14))
                    .foregroundColor(.tertiaryText)
            }
            
            // Content
            Text(note.content)
                .font(.system(size: 16))
                .foregroundColor(.primaryText)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Tags
            HStack {
                ForEach(note.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 13))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondaryBackground)
                        .cornerRadius(4)
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
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

struct ContactNote: Identifiable {
    let id: UUID
    let title: String
    let content: String
    let date: String
    let tags: [String]
}

// MARK: - Previews
struct SocialContactDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SocialContactDetailView()
            .environmentObject(LocalizationManager())
            .environment(\.colorScheme, .light)
        
        SocialContactDetailView()
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
