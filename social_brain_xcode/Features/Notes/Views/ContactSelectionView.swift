import SwiftUI

struct ContactSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appModeManager: AppModeManager
    @StateObject private var contactManager = ContactManager.shared
    @State private var contacts: [Contact] = []
    @State private var searchText = ""
    let onSelect: (Contact) -> Void
    
    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            guard let name = contact.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredContacts, id: \.contactId) { contact in
                    Button(action: {
                        onSelect(contact)
                        dismiss()
                    }) {
                        HStack {
                            Text(contact.name ?? "")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("选择熟人")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索联系人")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            // Filter contacts based on app mode
            if appModeManager.isSampleMode {
                // In sample mode, only show type=0 contacts
                contacts = contactManager.fetchContacts(byType: 0)
            } else {
                // In regular mode, only show type!=0 contacts
                let allContacts = contactManager.fetchContacts()
                contacts = allContacts.filter { $0.type != 0 }
            }
        }
        .onChange(of: appModeManager.isSampleMode) { _ in
            // Refresh contacts when sample mode changes
            if appModeManager.isSampleMode {
                contacts = contactManager.fetchContacts(byType: 0)
            } else {
                let allContacts = contactManager.fetchContacts()
                contacts = allContacts.filter { $0.type != 0 }
            }
        }
    }
} 