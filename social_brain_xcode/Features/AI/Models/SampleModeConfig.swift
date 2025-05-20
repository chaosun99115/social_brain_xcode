import Foundation

// MARK: - Sample Mode Configuration
struct SampleModeConfig {
    // MARK: - Sample Mode Definition
    struct ModeDefinition {
        let id: String
        let title: String
        let description: String
        let scenario: SeedDataScenario
    }
    
    // MARK: - Available Sample Modes
    static let availableModes: [ModeDefinition] = [
        ModeDefinition(
            id: "changedJob",
            title: "融入新群体（我刚加入了新团队）",
            description: "",
            scenario: .changedJob
        ),
        ModeDefinition(
            id: "changedSchool",
            title: "融入新群体（孩子刚进了新学校）",
            description: "",    
            scenario: .changedSchool
        ),
        ModeDefinition(
            id: "careerPivot",
            title: "拓展人脉（我正计划跳槽）",
            description: "",
            scenario: .careerPivot
        ),
        ModeDefinition(
            id: "indie",
            title: "拓展人脉（我独立经营自己的项目）",
            description: "",
            scenario: .indie
        )
    ]
    
    // MARK: - Sample Mode Selection Dialog
    static let selectionDialogTitle = "选择一个用户场景"
    static let selectionDialogMessage = "每个用户场景下的示例数据能够让你你全面体验社交大脑的功能。示例模式不影响你的私有数据，退出示例模式后将恢复原状。"
    
    // MARK: - Helper Methods
    static func getModeDefinition(forId id: String) -> ModeDefinition? {
        availableModes.first { $0.id == id }
    }
    
    static func getModeDefinition(forTitle title: String) -> ModeDefinition? {
        availableModes.first { $0.title == title }
    }
    
    static func getModeDefinition(forScenario scenario: SeedDataScenario) -> ModeDefinition? {
        availableModes.first { $0.scenario == scenario }
    }
    
    // MARK: - UI Constants
    struct UIConstants {
        static let exitButtonTitle = "退出示例模式"
        static let exitButtonIcon = "rectangle.portrait.and.arrow.right"
        static let exitButtonColor = "4085F3"
        
        static let sampleButtonTitle = "查看示例笔记"
        static let sampleButtonIcon = "doc.text.magnifyingglass"
        static let sampleButtonColor = "4085F3"
    }
} 