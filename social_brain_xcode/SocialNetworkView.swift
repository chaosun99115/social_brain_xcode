import SwiftUI

struct SocialNetworkView: View {
    @State private var searchText = ""
    
    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return Contact.mockContacts
        }
        return Contact.mockContacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText) ||
            contact.latestStatus.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    List(filteredContacts) { contact in
                        VStack(spacing: 0) {
                            ContactCardView(contact: contact)
                            if contact.id != filteredContacts.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            // Add contact action
                        }) {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Social Network")
            .searchable(text: $searchText, prompt: "Search")
        }
    }
}

struct TabBarButton: View {
    let image: String
    let text: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: image)
                .font(.system(size: 24))
            Text(text)
                .font(.system(size: 12))
        }
        .foregroundColor(isSelected ? .blue : .gray)
        .frame(maxWidth: .infinity)
    }
}

struct ContactCardView: View {
    let contact: Contact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(contact.name)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                Text(contact.timeDescription)
                Text("|")
                    .foregroundColor(.gray)
                Text("\(contact.relatedNotesCount) related notes")
            }
            .font(.subheadline)
            .foregroundColor(.gray)
            
            if !contact.latestStatus.isEmpty {
                Text(contact.latestStatus)
                    .font(.body)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }
}

// Preview
struct SocialNetworkView_Previews: PreviewProvider {
    static var previews: some View {
        SocialNetworkView()
    }
} 