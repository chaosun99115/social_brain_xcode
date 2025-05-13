import SwiftUI
import CoreData

struct CircleDetailView: View {
    let circle: Circle
    @StateObject private var circleManager = CircleManager.shared
    @State private var contacts: [Contact] = []
    @State private var insights: [CircleInsight] = []
    @State private var isLoading = true
    @State private var showingAddContact = false
    @State private var showingAddInsight = false
    @State private var searchText = ""
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Circle Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(circle.name ?? "Unnamed Circle")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    HStack {
                        Text("Created")
                        Text(formatDate(circle.createdAt ?? Date()))
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                }
                .padding(.horizontal)
                
                // Circle Insights
                if !insights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Insights")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(insights, id: \.insightId) { insight in
                                    InsightCardView(insight: insight)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Contacts Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Contacts")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddContact = true
                        }) {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.primaryAction)
                        }
                    }
                    .padding(.horizontal)
                    
                    if filteredContacts.isEmpty {
                        Text("No contacts in this circle")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(filteredContacts, id: \.contactId) { contact in
                            NavigationLink(destination: SocialContactDetailView(contact: contact)) {
                                ContactCardView(contact: contact)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search contacts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingAddInsight = true
                    }) {
                        Label("Add Insight", systemImage: "lightbulb")
                    }
                    
                    Button(role: .destructive, action: {
                        deleteCircle()
                    }) {
                        Label("Delete Circle", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactToCircleView(circle: circle) { contact in
                if let contact = contact {
                    contacts.append(contact)
                }
            }
        }
        .sheet(isPresented: $showingAddInsight) {
            AddInsightToCircleView(circle: circle) { insight in
                if let insight = insight {
                    insights.append(insight)
                }
            }
        }
        .task {
            await loadCircleData()
        }
    }
    
    private func loadCircleData() async {
        guard let circleId = circle.circleId else { return }
        
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        // Load contacts and insights
        let loadedContacts = circleManager.getContactsForCircle(circleId: circleId)
        let loadedInsights = circleManager.getInsightsForCircle(circleId: circleId)
        
        await MainActor.run {
            self.contacts = loadedContacts
            self.insights = loadedInsights
        }
    }
    
    private func deleteCircle() {
        guard let circleId = circle.circleId else { return }
        
        if circleManager.deleteCircle(circleId: circleId) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct InsightCardView: View {
    let insight: CircleInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(insight.category ?? "General")
                .font(.caption)
                .foregroundColor(.secondaryText)
            
            Text(insight.content ?? "")
                .font(.body)
                .foregroundColor(.primaryText)
                .lineLimit(3)
            
            if let subCategory = insight.subCategory, !subCategory.isEmpty {
                Text(subCategory)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .frame(width: 280)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct AddContactToCircleView: View {
    let circle: Circle
    let onAdd: (Contact?) -> Void
    
    @StateObject private var contactManager = ContactManager.shared
    @StateObject private var circleManager = CircleManager.shared
    @State private var contacts: [Contact] = []
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
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
                        addContactToCircle(contact)
                    }) {
                        ContactCardView(contact: contact)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            contacts = contactManager.fetchContacts()
        }
    }
    
    private func addContactToCircle(_ contact: Contact) {
        guard let circleId = circle.circleId,
              let contactId = contact.contactId else { return }
        
        if circleManager.addContactToCircle(circleId: circleId, contactId: contactId) {
            onAdd(contact)
            dismiss()
        }
    }
}

struct AddInsightToCircleView: View {
    let circle: Circle
    let onAdd: (CircleInsight?) -> Void
    
    @StateObject private var circleManager = CircleManager.shared
    @State private var insightText = ""
    @State private var category = "General"
    @State private var subCategory = ""
    @Environment(\.dismiss) private var dismiss
    
    let categories = ["General", "Team", "Project", "Personal"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Insight Details")) {
                    TextField("Category", text: $category)
                    TextField("Sub-category (optional)", text: $subCategory)
                    TextEditor(text: $insightText)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Insight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveInsight()
                    }
                    .disabled(insightText.isEmpty)
                }
            }
        }
    }
    
    private func saveInsight() {
        guard let circleId = circle.circleId else { return }
        
        if let insight = CircleInsightManager.shared.createInsight(
            type: "memo",
            category: category,
            subCategory: subCategory,
            content: insightText
        ) {
            if circleManager.addInsightToCircle(circleId: circleId, insightId: insight.insightId!) {
                onAdd(insight)
                dismiss()
            }
        }
    }
}

// Preview
struct CircleDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let circle = Circle(context: context)
        circle.circleId = UUID()
        circle.name = "Preview Circle"
        circle.createdAt = Date()
        
        return NavigationView {
            CircleDetailView(circle: circle)
                .environment(\.managedObjectContext, context)
        }
    }
} 