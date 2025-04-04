import Foundation

struct SocialNote: Identifiable {
    let id = UUID()
    let date: Date
    let content: String
    
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
            content: "Met @Michael Johnson at Central Perk this morning. He's working as an analyst at Bridgewater Fund – seems to really know his stuff about market trends. Has two golden retrievers (Buddy and Max) that he takes to Prospect Park every weekend. Recently divorced, but didn't seem like he wanted to talk about it."
        ),
        SocialNote(
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 10))!,
            content: "@James Chen started his new PM role at Microsoft! Family moved to Seattle from Boston last week. His wife Jennifer is looking for teaching positions for the fall. Kids: Ethan (10) and Sophia (7) will start at new schools next month. They bought a house in Bellevue."
        ),
        SocialNote(
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 20))!,
            content: "@Rachel Garcia moving to Chicago next month for Deloitte consulting job. Suggested Lincoln Park or Wicker Park neighborhoods based on my visit last year. She's looking for salsa classes there – maybe connect her with my cousin in Chicago?"
        )
    ]
} 