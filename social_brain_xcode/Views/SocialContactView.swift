private var filteredContacts: [Contact] {
    print("\n[SocialContactView] 🔍 Filtering contacts for tab: \(selectedTab)")
    print("[SocialContactView] 📊 Total contacts before filtering: \(contacts.count)")
    
    if isSampleMode {
        print("[SocialContactView] 🎯 In sample mode - showing all contacts")
        // Log each contact and their note count
        for contact in contacts {
            let noteCount = ContactManager.shared.getNotesCount(forContactId: contact.contactId)
            print("[SocialContactView] Contact: \(contact.name)")
            print("  - Contact ID: \(contact.contactId)")
            print("  - Note Count: \(noteCount)")
        }
        return contacts
    }
    
    // ... rest of the existing filtering code ...
} 