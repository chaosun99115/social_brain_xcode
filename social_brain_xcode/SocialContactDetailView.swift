import SwiftUI

struct SocialContactDetailView: View {
    let contact: Contact
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var activeTab: TabType = .summary
    
    enum TabType: String, CaseIterable {
        case summary = "汇总"
        case notes = "笔记"
        
        var localizedName: String {
            switch self {
            case .summary: return "summary".localized
            case .notes: return "notes".localized
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
            // Conversation topics suggestions from AI
            ForEach(contactTopics, id: \.id) { topic in
                ContactTopicRow(topic: topic)
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
            }
            
            // Spacer at the bottom for better scrolling
            Spacer().frame(height: 40)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Mock Data
    private var contactTopics: [ContactTopic] {
        [
            ContactTopic(
                id: UUID(),
                content: "李经理的女儿刚开始学轮滑，你可以询问孩子的学习体验。（你没有记录过轮滑相关的话题，可以让AI调研一下有什么可以聊的内容）",
                actionText: "AI调研"
            ),
            ContactTopic(
                id: UUID(),
                content: "李经理的的部门最近在准备一个项目，遇到李经理可以询问项目的进展",
                actionText: nil
            ),
            ContactTopic(
                id: UUID(),
                content: "李经理喜欢咖啡文化（你没有记录过咖啡相关的话题，可以让AI调研一下有什么可以聊的内容）",
                actionText: "AI调研"
            ),
            ContactTopic(
                id: UUID(),
                content: "你和李经理的小孩同龄，你可以分享你自己孩子的兴趣爱好，包括钢琴，芭蕾。如果有一样的兴趣可以一起活动。",
                actionText: nil
            ),
            ContactTopic(
                id: UUID(),
                content: "你最近担心裁员，可以问问李经理的部门是否有招人，是否有转部门的可能性。",
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
    
    private var latestStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("latest_status".localized)
                .font(.headline)
                .foregroundColor(.primaryText)
                
            Text(contact.latestStatus)
                .font(.body)
                .foregroundColor(.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondaryBackground)
                .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var relatedNotesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("related_notes".localized)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if contact.relatedNotesCount > 0 {
                    Text("\(contact.relatedNotesCount)")
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
            
            if contact.relatedNotesCount == 0 {
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
struct ContactTopicRow: View {
    let topic: ContactTopic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Bullet point
                Circle()
                    .fill(Color.tertiaryText)
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)
                
                // Topic content
                VStack(alignment: .leading, spacing: 8) {
                    Text(topic.content)
                        .font(.system(size: 16))
                        .foregroundColor(.primaryText)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Action button
                    if let actionText = topic.actionText {
                        Button(action: {
                            // AI research action
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
            
            Divider()
                .padding(.leading, 22)
                .padding(.vertical, 16)
        }
        .padding(.horizontal, 20)
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
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Supporting Models
struct ContactTopic: Identifiable {
    let id: UUID
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
        SocialContactDetailView(contact: Contact.mockContacts[0])
            .environmentObject(LocalizationManager())
            .environment(\.colorScheme, .light)
        
        SocialContactDetailView(contact: Contact.mockContacts[0])
            .environmentObject(LocalizationManager())
            .environment(\.colorScheme, .dark)
    }
} 