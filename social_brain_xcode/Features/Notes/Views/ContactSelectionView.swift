import SwiftUI

struct ContactSelectionView: View {
    @Environment(\.dismiss) private var dismiss
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
                        print("\n[ContactSelectionView] 🔍 Contact selected:")
                        print("[ContactSelectionView] - Name: \(contact.name ?? "nil")")
                        print("[ContactSelectionView] - ID: \(contact.contactId?.uuidString ?? "nil")")
                        onSelect(contact)
                        dismiss()
                    }) {
                        HStack {
                            Text(contact.name ?? "")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("选择熟人")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索联系人")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        print("[ContactSelectionView] ⬅️ Back button tapped")
                        dismiss()
                    }
                }
            }
        }
        .task {
            print("\n[ContactSelectionView] 📱 View appeared, fetching contacts...")
            contacts = contactManager.fetchContacts()
            print("[ContactSelectionView] 📊 Fetched \(contacts.count) contacts")
            for (index, contact) in contacts.enumerated() {
                print("[ContactSelectionView] Contact \(index + 1):")
                print("  - Name: \(contact.name ?? "nil")")
                print("  - ID: \(contact.contactId?.uuidString ?? "nil")")
            }
        }
    }
} 