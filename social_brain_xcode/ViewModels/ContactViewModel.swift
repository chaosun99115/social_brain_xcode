import Foundation
import CoreData
import SwiftUI

class ContactViewModel: ObservableObject, Identifiable {
    private let contact: Contact
    
    @Published var name: String
    @Published var latestStatus: String
    @Published var avatarColor: AvatarColor
    @Published var avatarSymbol: String
    @Published var relationship: String
    @Published var relatedNotesCount: Int
    @Published var lastMentionDate: Date?
    @Published var addedDate: Date
    
    var id: UUID { contact.contactId ?? UUID() }
    
    var timeDescription: String {
        if let lastMention = lastMentionDate {
            return "last_mention".localized + ": \(formatTimeAgo(lastMention))"
        } else {
            return "Added: \(formatTimeAgo(addedDate))"
        }
    }
    
    init(contact: Contact) {
        self.contact = contact
        self.name = contact.name ?? ""
        self.latestStatus = ""  // Initialize with empty, will be updated from notes
        self.avatarColor = .random()
        self.avatarSymbol = "person.circle.fill"  // Default symbol
        self.relationship = ""  // Will be determined from notes
        self.relatedNotesCount = 0  // Will be calculated from relationships
        self.addedDate = contact.createdAt ?? Date()
        self.lastMentionDate = nil
        
        updateDerivedProperties()
    }
    
    private func updateDerivedProperties() {
        // Calculate related notes count
        if let relationships = contact.noteToContactRelationships?.allObjects as? [NoteContactRelationship] {
            self.relatedNotesCount = relationships.count
            
            // Find the latest note for status
            if let latestNote = relationships
                .compactMap({ $0.note })
                .sorted(by: { ($0.updatedAt ?? Date()) > ($1.updatedAt ?? Date()) })
                .first {
                self.latestStatus = latestNote.text ?? ""
                self.lastMentionDate = latestNote.updatedAt
            }
            
            // Determine relationship from notes content
            // This is a simplified example - you might want to implement more sophisticated logic
            if let firstNote = relationships.first?.note {
                self.relationship = determineRelationship(from: firstNote.text ?? "")
            }
        }
    }
    
    private func determineRelationship(from noteText: String) -> String {
        // This is a placeholder implementation
        // You might want to use more sophisticated logic or AI to determine the relationship
        let relationships = ["Friend", "Colleague", "Family", "Business Contact"]
        return relationships.randomElement() ?? "Contact"
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: Date())
        
        if let days = components.day, days > 0 {
            return days == 1 ? "yesterday".localized : String(format: "days_ago".localized, days)
        } else if let hours = components.hour, hours > 0 {
            return String(format: "hours_ago".localized, hours)
        } else if let minutes = components.minute, minutes > 0 {
            return String(format: "minutes_ago".localized, minutes)
        } else {
            return "just_now".localized
        }
    }
    
    // MARK: - Data Operations
    func save() {
        contact.name = name
        contact.updatedAt = Date()
        
        do {
            try contact.managedObjectContext?.save()
        } catch {
            print("Error saving contact: \(error)")
        }
    }
} 