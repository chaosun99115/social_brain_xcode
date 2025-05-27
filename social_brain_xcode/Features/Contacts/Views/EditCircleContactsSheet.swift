import SwiftUI
import CoreData

/// A sheet view for managing contacts within a circle
/// This view allows users to add or remove contacts from a circle through a list interface
struct EditCircleContactsSheet: View {
    // MARK: - Properties
    
    /// The circle being edited
    let circle: Circle
    
    /// Binding to control the presentation state of the sheet
    @Binding var isPresented: Bool
    
    /// Callback function that is called when contacts are updated
    var onUpdate: ([Contact]) -> Void
    
    /// Contact manager for handling contact operations
    @StateObject private var contactManager = ContactManager.shared
    
    /// Circle manager for handling circle operations
    @StateObject private var circleManager = CircleManager.shared
    
    /// All available contacts
    @State private var allContacts: [Contact] = []
    
    /// Set of selected contact IDs
    @State private var selectedContactIds: Set<UUID> = []
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                ForEach(allContacts, id: \ .contactId) { contact in
                    HStack {
                        Text(contact.name ?? "")
                            .foregroundColor(.primary)
                        Spacer()
                        CheckboxView(isChecked: selectedContactIds.contains(contact.contactId ?? UUID())) {
                            toggleContact(contact)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
            .navigationTitle("选择圈子熟人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onUpdate(selectedContactIds.compactMap { id in 
                            allContacts.first(where: { $0.contactId == id }) 
                        })
                        isPresented = false
                    }
                    .foregroundColor(.accentColor)
                }
            }
            .onAppear {
                loadContacts()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Loads all contacts and sets up the initial selection state
    private func loadContacts() {
        allContacts = contactManager.fetchContacts()
        if let circleId = circle.circleId {
            let related = circleManager.getContactsForCircle(circleId: circleId)
            selectedContactIds = Set(related.compactMap { $0.contactId })
        }
    }
    
    /// Toggles a contact's membership in the circle
    /// - Parameter contact: The contact to toggle
    private func toggleContact(_ contact: Contact) {
        guard let contactId = contact.contactId,
              let circleId = circle.circleId else { return }
        
        if selectedContactIds.contains(contactId) {
            // Remove contact from circle
            if circleManager.removeContactFromCircle(circleId: circleId, contactId: contactId) {
                selectedContactIds.remove(contactId)
            }
        } else {
            // Add contact to circle
            if circleManager.addContactToCircle(circleId: circleId, contactId: contactId) {
                selectedContactIds.insert(contactId)
            }
        }
    }
}

/// A generic sheet view for picking multiple contacts
struct ContactMultiPickerSheet: View {
    let allContacts: [Contact]
    @Binding var selectedContactIds: Set<UUID>
    @Binding var isPresented: Bool
    var onDone: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(allContacts, id: \ .contactId) { contact in
                    HStack {
                        Text(contact.name ?? "")
                        Spacer()
                        CheckboxView(isChecked: selectedContactIds.contains(contact.contactId ?? UUID())) {
                            toggleContact(contact)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
            .navigationTitle("选择熟人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                        onDone()
                    }
                }
            }
        }
    }
    
    private func toggleContact(_ contact: Contact) {
        guard let contactId = contact.contactId else { return }
        if selectedContactIds.contains(contactId) {
            selectedContactIds.remove(contactId)
        } else {
            selectedContactIds.insert(contactId)
        }
    }
}

// MARK: - Preview Provider

struct ContactMultiPickerSheet_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let contact1 = Contact(context: context)
        contact1.contactId = UUID()
        contact1.name = "Alice"
        let contact2 = Contact(context: context)
        contact2.contactId = UUID()
        contact2.name = "Bob"
        let allContacts = [contact1, contact2]
        return ContactMultiPickerSheet(
            allContacts: allContacts,
            selectedContactIds: .constant([contact1.contactId!]),
            isPresented: .constant(true),
            onDone: {}
        )
        .environment(\ .managedObjectContext, context)
    }
} 