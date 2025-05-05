import SwiftUI
import CoreData

struct SocialContactView: View {
    @State private var searchText = ""
    @EnvironmentObject var localizationManager: LocalizationManager
    @StateObject private var contactManager = ContactManager.shared
    @State private var contacts: [Contact] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil
    
    // Fetch contacts from CoreData (initial load)
    private func loadContacts() async {
        // Only set isLoading for initial load
        if !isRefreshing {
            await MainActor.run { isLoading = true }
        }
        errorMessage = nil
        defer {
            Task { @MainActor in
                isLoading = false
                isRefreshing = false
            }
        }
        do {
            let fetchedContacts = await MainActor.run {
                contactManager.fetchContacts()
            }
            // Validate relationships before updating UI
            let validContacts = fetchedContacts.filter { contact in
                do {
                    try contactManager.validateContactRelationships(contact)
                    return true
                } catch {
                    print("Invalid relationships for contact: \(contact.name ?? "Unknown")")
                    return false
                }
            }
            await MainActor.run {
                self.contacts = validContacts
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load contacts: \(error.localizedDescription)"
            }
        }
    }
    
    // Pull-to-refresh
    private func refreshContacts() async {
        await MainActor.run { isRefreshing = true }
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        // Add a small delay to ensure the refresh control is in the correct state
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        await loadContacts()
    }
    
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
            ZStack {
                Color.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                    } else if let error = errorMessage {
                        errorView(message: error)
                    } else if filteredContacts.isEmpty {
                        emptySearchView
                    } else {
                        contactListView
                    }
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            // Add contact action
                        }) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 22, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.primaryAction)
                                .clipShape(SwiftUI.Circle())
                                .shadow(color: Color.primaryText.opacity(0.2), radius: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
                // Show overlay spinner only during refresh (not initial load)
                if isRefreshing && !isLoading {
                    Color.primaryBackground.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("联系人")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "search_contacts".localized)
            .refreshable {
                await refreshContacts()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await loadContacts()
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color.tertiaryText)
            
            Text(message)
                .font(.headline)
                .foregroundColor(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                Task {
                    await loadContacts()
                }
            }
            .padding()
            .background(Color.primaryAction)
            .foregroundColor(.white)
            .cornerRadius(8)
                
            Spacer()
        }
    }
    
    private var emptySearchView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color.tertiaryText)
            
            Text("no_contacts".localized)
                .font(.headline)
                .foregroundColor(Color.secondaryText)
                
            Text("add_contact".localized)
                .font(.subheadline)
                .foregroundColor(Color.tertiaryText)
                
            Spacer()
        }
    }
    
    private var contactListView: some View {
        List {
            ForEach(filteredContacts, id: \.contactId) { contact in
                NavigationLink(destination: SocialContactDetailView(contact: contact)) {
                    ContactCardView(contact: contact)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.visible)
                .listRowBackground(Color.cardBackground)
            }
        }
        .listStyle(.plain)
    }
}

struct ContactCardView: View {
    let contact: Contact
    @StateObject private var contactManager = ContactManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.name ?? "Unnamed Contact")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primaryText)
            
            HStack {
                Text(formatDate(contact.createdAt ?? Date()))
                Text("|")
                Text("\(getNotesCount()) " + "note".localized)
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    
    private func getNotesCount() -> Int {
        guard let contactId = contact.contactId else { return 0 }
        return contactManager.getNotesCount(forContactId: contactId)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Preview
struct SocialContactView_Previews: PreviewProvider {
    static var previews: some View {
        SocialContactView()
            .environment(\.colorScheme, .light)
            .environmentObject(LocalizationManager())
        
        SocialContactView()
            .environment(\.colorScheme, .dark)
            .environmentObject(LocalizationManager())
    }
}
