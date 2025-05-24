import Foundation
import CoreData

struct SocialContact: Identifiable {
    let id: UUID
    let name: String
    let type: Int16
    let createdAt: Date
    let updatedAt: Date
    let recordStatus: Int16
    
    // Initialize from Core Data Contact entity
    init(from contact: NSManagedObject) {
        let contact = contact as! Contact
        self.id = contact.contactId ?? UUID()
        self.name = contact.name ?? ""
        self.type = contact.type
        self.createdAt = contact.createdAt ?? Date()
        self.updatedAt = contact.updatedAt ?? Date()
        self.recordStatus = contact.recordStatus
    }
    
    // Initialize with default values
    init(id: UUID = UUID(), name: String, type: Int16 = 0, createdAt: Date = Date(), updatedAt: Date = Date(), recordStatus: Int16 = 0) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recordStatus = recordStatus
    }
}

// MARK: - Core Data Operations
extension SocialContact {
    private static var viewContext: NSManagedObjectContext {
        CoreDataManager.shared.viewContext
    }
    
    static func fetchAll() -> [SocialContact] {
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
//        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Contact.updatedAt, ascending: false)]
        
        do {
            let contacts = try viewContext.fetch(fetchRequest)
            return contacts.map { SocialContact(from: $0) }
        } catch {
            print("Error fetching contacts: \(error)")
            return []
        }
    }
    
    static func fetch(withId id: UUID) -> SocialContact? {
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "contactId == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            guard let contact = try viewContext.fetch(fetchRequest).first else {
                return nil
            }
            return SocialContact(from: contact)
        } catch {
            print("Error fetching contact: \(error)")
            return nil
        }
    }
    
    func save() -> Bool {
        let context = Self.viewContext
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "contactId == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            let contact: Contact
            
            if let existingContact = results.first {
                contact = existingContact
            } else {
                contact = Contact(context: context)
                contact.contactId = id
                contact.createdAt = createdAt
            }
            
            contact.name = name
            contact.type = type
            contact.updatedAt = updatedAt
            contact.recordStatus = recordStatus
            
            try context.save()
            return true
        } catch {
            print("Error saving contact: \(error)")
            return false
        }
    }
    
    func delete() -> Bool {
        let context = Self.viewContext
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "contactId == %@", id as CVarArg)
        
        do {
            let contacts = try context.fetch(fetchRequest)
            contacts.forEach { context.delete($0) }
            try context.save()
            return true
        } catch {
            print("Error deleting contact: \(error)")
            return false
        }
    }
}

// MARK: - Preview Data
extension SocialContact {
    static var previewData: [SocialContact] {
        [
            SocialContact(name: "John Doe"),
            SocialContact(name: "Jane Smith"),
            SocialContact(name: "Bob Johnson")
        ]
    }
    
    static let mockContacts = [
        SocialContact(
            name: "contact_1",
            createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date(),
            updatedAt: Date(),
            recordStatus: 0
        ),
        SocialContact(
            name: "contact_2",
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            updatedAt: Date(),
            recordStatus: 0
        ),
        SocialContact(
            name: "contact_3",
            createdAt: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            updatedAt: Date(),
            recordStatus: 0
        ),
        SocialContact(
            name: "contact_4",
            createdAt: Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
            updatedAt: Date(),
            recordStatus: 0
        )
    ]
}

enum AvatarColor: String, CaseIterable {
    case blue, green, orange, purple, teal, indigo, pink, red
    
    static func random() -> AvatarColor {
        return AvatarColor.allCases.randomElement() ?? .blue
    }
} 
