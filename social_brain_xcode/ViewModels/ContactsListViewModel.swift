import Foundation
import CoreData
import Combine

class ContactsListViewModel: ObservableObject {
    @Published private(set) var contacts: [Contact] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchContacts()
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                self?.fetchContacts()
            }
            .store(in: &cancellables)
    }
    
    func fetchContacts() {
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Contact.updatedAt, ascending: false)]
        
        do {
            self.contacts = try CoreDataManager.shared.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching contacts: \(error)")
        }
    }
    
    func addContact(name: String) {
        let context = CoreDataManager.shared.viewContext
        let contact = Contact(context: context)
        contact.contactId = UUID()
        contact.name = name
        contact.createdAt = Date()
        contact.updatedAt = Date()
        contact.recordStatus = 0 // unsynced
        
        do {
            try context.save()
            fetchContacts()
        } catch {
            print("Error adding contact: \(error)")
        }
    }
    
    func deleteContact(at indexSet: IndexSet) {
        let context = CoreDataManager.shared.viewContext
        
        indexSet.forEach { index in
            let contact = contacts[index]
            context.delete(contact)
        }
        
        do {
            try context.save()
            fetchContacts()
        } catch {
            print("Error saving after delete: \(error)")
        }
    }
} 