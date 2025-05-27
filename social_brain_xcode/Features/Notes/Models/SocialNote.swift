import Foundation
import CoreData

struct SocialNote: Identifiable {
    let id: UUID
    let date: Date
    let content: String
    let type: NoteType
    let updateCompleted: Bool
    let isArchived: Bool
    
    // Initialize from Core Data Note entity
    init(from note: NSManagedObject) {
        let note = note as! Note
        self.id = note.noteId ?? UUID()
        self.date = note.createdAt ?? Date()
        self.content = note.content ?? ""
        let rawType = Int(truncatingIfNeeded: note.type)
        self.type = NoteType(rawValue: rawType) ?? .regular
        self.updateCompleted = note.updateCompleted == 1
        self.isArchived = note.isArchived
    }
    
    // Initialize with default values
    init(id: UUID = UUID(), date: Date = Date(), content: String, type: NoteType = .regular, updateCompleted: Bool = false, isArchived: Bool = false) {
        self.id = id
        self.date = date
        self.content = content
        self.type = type
        self.updateCompleted = updateCompleted
        self.isArchived = isArchived
    }
    
    var formattedDate: String {
        let day = Calendar.current.component(.day, from: date)
        let suffix = getDaySuffix(day)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d'\(suffix)' yyyy"
        return formatter.string(from: date)
    }
    
    private func getDaySuffix(_ day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
    
    // Mock data based on the image
    static let mockNotes = [
        SocialNote(
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 15))!,
            content: "今天和 @李经理 在午餐时偶遇一起吃了饭。他提到他二年级的女儿，最近开始学轮滑了。另外他自己有一套手冲咖啡器具，平时会研究咖啡。他的部门最近在准备一个项目，接下来三个月会比较忙。"
        ),
        SocialNote(
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 10))!,
            content: "今天在接佳佳的路上遇到了 @彤彤妈妈 。她提到学校下周日有「亲子阅读日」，但她可能因工作原因无法参加。她还提到自己喜欢烘焙，经常在周末做蛋糕给孩子们吃。另外，她最近想给彤彤报一个编程班，但不知道哪家机构比较好。"
        )
    ]
}

// MARK: - Preview Data
extension SocialNote {
    static var previewData: [SocialNote] {
        [
            SocialNote(content: "Sample note 1"),
            SocialNote(content: "Sample note 2"),
            SocialNote(content: "Sample note 3")
        ]
    }
} 
