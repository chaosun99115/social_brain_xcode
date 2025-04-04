import Foundation

struct Contact: Identifiable {
    let id = UUID()
    let name: String
    let lastMentionDate: Date?
    let addedDate: Date?
    let relatedNotesCount: Int
    let latestStatus: String
    
    var timeDescription: String {
        if let lastMention = lastMentionDate {
            return "Last mention: \(formatTimeAgo(lastMention))"
        } else if let added = addedDate {
            return "Added: \(formatTimeAgo(added))"
        }
        return ""
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return "\(days) days ago"
    }
}

// Mock Data
extension Contact {
    static let mockContacts = [
        Contact(
            name: "Sarah Williams",
            lastMentionDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            addedDate: nil,
            relatedNotesCount: 12,
            latestStatus: "Planning baby shower next month, likes cheesecake"
        ),
        Contact(
            name: "James Chen",
            lastMentionDate: Calendar.current.date(byAdding: .day, value: -20, to: Date()),
            addedDate: nil,
            relatedNotesCount: 4,
            latestStatus: "Started new job at Microsoft, relocated to Seattle"
        ),
        Contact(
            name: "David Thompson",
            lastMentionDate: nil,
            addedDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            relatedNotesCount: 0,
            latestStatus: ""
        ),
        Contact(
            name: "Michael Johnson",
            lastMentionDate: nil,
            addedDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            relatedNotesCount: 0,
            latestStatus: ""
        )
    ]
} 