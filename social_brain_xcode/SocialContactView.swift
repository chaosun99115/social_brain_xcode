import SwiftUI

// Mock data structure
struct MockContact: Identifiable {
    let id = UUID()
    let name: String
    let createdAt: Date
    let notesCount: Int
}

struct SocialContactView: View {
    @State private var searchText = ""
    @EnvironmentObject var localizationManager: LocalizationManager
    
    // Mock data
    let mockContacts = [
        MockContact(name: "John Doe", createdAt: Date().addingTimeInterval(-86400), notesCount: 3),
        MockContact(name: "Jane Smith", createdAt: Date().addingTimeInterval(-172800), notesCount: 5),
        MockContact(name: "Mike Johnson", createdAt: Date().addingTimeInterval(-259200), notesCount: 2)
    ]
    
    var filteredContacts: [MockContact] {
        if searchText.isEmpty {
            return mockContacts
        }
        return mockContacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if filteredContacts.isEmpty {
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
                                .clipShape(Circle())
                                .shadow(color: Color.primaryText.opacity(0.2), radius: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("social_contacts".localized)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "search_contacts".localized)
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
            ForEach(filteredContacts) { contact in
                NavigationLink(destination: ContactDetailView(contact: contact)) {
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

struct ContactDetailView: View {
    let contact: MockContact
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var localizationManager: LocalizationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Contact Details
                    contactInfoView
                    
                    Divider()
                    
                    // Related Notes Summary
                    relatedNotesView
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("contact_details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Edit contact
                    } label: {
                        Text("edit".localized)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("done".localized)
                    }
                }
            }
        }
    }
    
    private var contactInfoView: some View {
        VStack(spacing: 10) {
            Text(contact.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text("Added: \(formatDate(contact.createdAt))")
                .font(.subheadline)
                .foregroundColor(.tertiaryText)
        }
    }
    
    private var relatedNotesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Related Notes")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if contact.notesCount > 0 {
                    Text("\(contact.notesCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.primaryAction.opacity(0.15))
                        )
                        .foregroundColor(Color.primaryAction)
                }
            }
            
            if contact.notesCount == 0 {
                Text("No notes related to this contact")
                    .font(.subheadline)
                    .foregroundColor(.tertiaryText)
                    .padding(.vertical, 10)
            } else {
                Button(action: {
                    // View all notes action
                }) {
                    Text("View all notes")
                        .font(.subheadline)
                        .foregroundColor(.primaryAction)
                        .padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ContactCardView: View {
    let contact: MockContact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.name)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primaryText)
            
            HStack {
                Text(formatDate(contact.createdAt))
                Text("|")
                Text("\(contact.notesCount) " + "note".localized)
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
