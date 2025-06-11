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
    
    /// App mode manager for filtering contacts
    @EnvironmentObject var appModeManager: AppModeManager
    
    /// All available contacts
    @State private var allContacts: [Contact] = []
    
    /// Set of selected contact IDs
    @State private var selectedContactIds: Set<UUID> = []
    
    /// Circle name
    @State private var circleName: String
    
    /// Custom background color
    private let backgroundColor = Color(red: 246/255, green: 246/255, blue: 251/255)
    
    init(circle: Circle, isPresented: Binding<Bool>, onUpdate: @escaping ([Contact]) -> Void) {
        self.circle = circle
        self._isPresented = isPresented
        self.onUpdate = onUpdate
        self._circleName = State(initialValue: circle.name ?? "")
        
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(backgroundColor)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        
        // Remove shadow/divider line
        appearance.shadowColor = .clear
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Circle name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("圈子名称")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    HStack {
                        TextField("圈子名称", text: $circleName)
                            .font(.body)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            // Ensure proper Chinese input support
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(false)
                    }
                    .background(Color.white)
                    .cornerRadius(0)
                }
                .padding(.top, 16)
                
                // Contacts list
                Text("熟人列表")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                
                if allContacts.isEmpty {
                    VStack(spacing: 0) {
                        Spacer()
                        Text("您还没有添加熟人")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                        Divider()
                            .padding(.leading, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(allContacts, id: \.contactId) { contact in
                                HStack {
                                    Text(contact.name ?? "")
                                        .foregroundColor(.primary)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                    Spacer()
                                    CheckboxView(isChecked: selectedContactIds.contains(contact.contactId ?? UUID())) {
                                        toggleContact(contact)
                                    }
                                    .padding(.trailing, 16)
                                }
                                .background(Color.white)
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(0)
                    .frame(height: min(CGFloat(allContacts.count) * 44, UIScreen.main.bounds.height * 0.6)) // Each item is 44pt high, max 60% of screen height
                }
                
                Spacer()
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("编辑圈子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        updateCircle()
                    }
                }
            }
            .onAppear {
                loadContacts()
            }
            .onChange(of: appModeManager.isSampleMode) { _ in
                // Refresh contacts when sample mode changes
                loadContacts()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Private Methods
    
    /// Loads all contacts and sets up the initial selection state
    private func loadContacts() {
        // Filter contacts based on app mode
        let fetchedContacts = contactManager.fetchContacts()
        if appModeManager.isSampleMode {
            // In sample mode, only show type=0 contacts
            allContacts = fetchedContacts.filter { $0.type == 0 }
        } else {
            // In regular mode, only show type!=0 contacts
            allContacts = fetchedContacts.filter { $0.type != 0 }
        }
        
        if let circleId = circle.circleId {
            let related = circleManager.getContactsForCircle(circleId: circleId)
            // Filter out archived contacts from the related contacts
            let nonArchivedRelated = related.filter { !$0.isArchived }
            selectedContactIds = Set(nonArchivedRelated.compactMap { $0.contactId })
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
    
    private func updateCircle() {
        // Update circle name if changed
        if circleName != circle.name {
            circle.name = circleName
        }
        
        // Update contacts
        onUpdate(selectedContactIds.compactMap { id in 
            allContacts.first(where: { $0.contactId == id }) 
        })
        isPresented = false
    }
}

/// A generic sheet view for picking multiple contacts
struct ContactMultiPickerSheet: View {
    let allContacts: [Contact]
    @Binding var selectedContactIds: Set<UUID>
    @Binding var isPresented: Bool
    var onDone: () -> Void
    
    // Initialize displayedContacts with allContacts
    @State private var displayedContacts: [Contact]
    
    init(allContacts: [Contact], selectedContactIds: Binding<Set<UUID>>, isPresented: Binding<Bool>, onDone: @escaping () -> Void) {
        self.allContacts = allContacts
        self._selectedContactIds = selectedContactIds
        self._isPresented = isPresented
        self.onDone = onDone
        // Initialize displayedContacts with allContacts
        self._displayedContacts = State(initialValue: allContacts)
    }
    
    var body: some View {
        NavigationView {
            List {
                if displayedContacts.isEmpty {
                    VStack {
                        Spacer()
                        Text("您还没有添加熟人")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.white)
                } else {
                    ForEach(displayedContacts, id: \.contactId) { contact in
                        HStack {
                            Text(contact.name ?? "")
                                .foregroundColor(.primary)
                                .padding(.vertical, 8)
                            Spacer()
                            CheckboxView(isChecked: selectedContactIds.contains(contact.contactId ?? UUID())) {
                                toggleContact(contact)
                            }
                        }
                        .contentShape(Rectangle())
                        .background(Color.white)
                        .listRowBackground(Color.white)
                    }
                }
            }
            .listStyle(PlainListStyle())
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
            .onAppear {
                // Update displayed contacts if they don't match
                if displayedContacts.count != allContacts.count {
                    displayedContacts = allContacts
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