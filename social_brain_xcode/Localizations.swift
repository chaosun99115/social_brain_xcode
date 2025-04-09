import Foundation

// This extension provides mock localizations for development
// In a production app, these would be in Localizable.strings files
extension LocalizationManager {
    // Returns English or Chinese version of the string based on current language
    func getMockLocalization(for key: String) -> String {
        if currentLanguage == "zh" {
            return chineseLocalizations[key] ?? key
        } else {
            return englishLocalizations[key] ?? key
        }
    }
    
    // English localizations
    private var englishLocalizations: [String: String] {
        [
            // Main tabs
            "social_brain": "Social Brain",
            "social_notes": "Social Notes",
            "social_contacts": "Contacts",
            
            // Social Brain view
            "new_chat": "New Chat",
            "hint_text": "Ask me about your social relationships...",
            "searching_notes": "Searching your notes...",
            "social_quote": "The quality of your life is determined by the quality of your relationships. Meaningful connections are the greatest source of happiness.",
            "quote_source": "Robert Waldinger, Harvard Study of Adult Development",
            
            // Contact views
            "search_contacts": "Search contacts",
            "no_contacts": "No contacts found",
            "add_contact": "Add a new contact with the + button",
            "last_mention": "Last mention",
            "yesterday": "yesterday",
            "days_ago": "%d days ago",
            "hours_ago": "%d hours ago",
            "minutes_ago": "%d minutes ago",
            "just_now": "just now",
            "note": "note",
            "notes": "notes",
            
            // Contact detail view
            "summary": "Summary",
            "notes": "Notes",
            "latest_status": "Latest Status",
            "related_notes": "Related Notes",
            "view_all_notes": "View all notes",
            "no_notes": "No notes related to this contact",
            "ai_research": "AI Research",
            
            // Mock contacts
            "contact_1": "Jason Smith",
            "contact_2": "Sarah Miller",
            "contact_3": "David Chen",
            "contact_4": "Manager Li",
            
            // Dialog messages
            "dialog_manager_daughter": "Manager Li's daughter recently started learning roller skating. She's 6 years old and practices every weekend in the park. Manager Li mentioned being concerned about safety but says his daughter enjoys it a lot.",
            "dialog_manager_project": "Manager Li's department is preparing for a new data analytics platform project, scheduled to launch in Q1 next year. The team is excited about it, and you might want to ask about its progress when you see him next.",
            "dialog_recent_interactions": "Are there any social interactions I need to follow up on recently?",
            "dialog_manager_status": "What's new with Manager Li? Any updates I should know about?",
            "dialog_ai_research": "AI Research",
            "dialog_view_original_note": "View Original Note",
            
            // Settings and actions
            "settings": "Settings",
            "edit": "Edit",
            "done": "Done",
            "back": "Back"
        ]
    }
    
    // Chinese localizations
    private var chineseLocalizations: [String: String] {
        [
            // Main tabs
            "social_brain": "社交大脑",
            "social_notes": "社交笔记",
            "social_contacts": "人脉",
            
            // Social Brain view
            "new_chat": "新对话",
            "hint_text": "询问我关于你社交关系的问题...",
            "searching_notes": "正在搜索你的笔记...",
            "social_quote": "你的生活质量取决于你的人际关系质量。有意义的连接是幸福感的最大来源。",
            "quote_source": "Robert Waldinger，哈佛成人发展研究",
            
            // Contact views
            "search_contacts": "搜索联系人",
            "no_contacts": "未找到联系人",
            "add_contact": "使用 + 按钮添加新联系人",
            "last_mention": "上次提及",
            "yesterday": "昨天",
            "days_ago": "%d天前",
            "hours_ago": "%d小时前",
            "minutes_ago": "%d分钟前",
            "just_now": "刚刚",
            "note": "笔记",
            "notes": "笔记",
            
            // Contact detail view
            "summary": "汇总",
            "notes": "笔记",
            "latest_status": "最新状态",
            "related_notes": "相关笔记",
            "view_all_notes": "查看所有笔记",
            "no_notes": "没有与此联系人相关的笔记",
            "ai_research": "AI调研",
            
            // Mock contacts
            "contact_1": "张伟",
            "contact_2": "王芳",
            "contact_3": "陈明",
            "contact_4": "李经理",
            
            // Dialog messages
            "dialog_manager_daughter": "李经理的女儿最近开始学习轮滑。她6岁，每个周末在公园练习。李经理表示有些担心安全问题，但说她女儿非常喜欢。",
            "dialog_manager_project": "李经理的部门正在准备一个新的数据分析平台项目，计划明年第一季度上线。团队对此很兴奋，下次见到他时，你可以询问项目进展。",
            "dialog_recent_interactions": "最近有需要跟进的社交互动吗？",
            "dialog_manager_status": "李经理最近有什么新情况？有我应该了解的更新吗？",
            "dialog_ai_research": "AI调研",
            "dialog_view_original_note": "查看原始笔记",
            
            // Settings and actions
            "settings": "设置",
            "edit": "编辑",
            "done": "完成",
            "back": "返回"
        ]
    }
}

// Make String.localized use our mock localizations
extension String {
    var localized: String {
        guard let appDelegate = UIApplication.shared.delegate as? social_brain_xcodeApp else {
            return self
        }
        
        return appDelegate.localizationManager.getMockLocalization(for: self)
    }
} 