import SwiftUI
import CoreData

struct ContactInsightDebugView: View {
    @StateObject private var insightManager = ContactInsightManager.shared
    @State private var insights: [ContactInsight] = []
    @State private var showingCreateSheet = false
    @State private var showingEditSheet = false
    @State private var selectedInsight: ContactInsight?
    
    // Form fields for create/edit
    @State private var type = ""
    @State private var category = ""
    @State private var content = ""
    @State private var order: Int16 = 0
    @State private var selectedContacts: Set<UUID> = []
    
    var body: some View {
        List {
            Section {
                Button("Create New Insight") {
                    showingCreateSheet = true
                }
            }
            
            Section("Existing Insights") {
                ForEach(insights, id: \.insightId) { insight in
                    InsightRow(insight: insight)
                        .onTapGesture {
                            selectedInsight = insight
                            showingEditSheet = true
                        }
                }
            }
        }
        .navigationTitle("Contact Insights Debug")
        .onAppear {
            loadInsights()
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationView {
                InsightFormView(
                    type: $type,
                    category: $category,
                    content: $content,
                    order: $order,
                    selectedContacts: $selectedContacts,
                    onSave: createInsight
                )
                .navigationTitle("Create Insight")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingCreateSheet = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: {
            selectedInsight = nil
        }) {
            if let insight = selectedInsight {
                NavigationView {
                    InsightFormView(
                        type: Binding(
                            get: { insight.type ?? "" },
                            set: { type = $0 }
                        ),
                        category: Binding(
                            get: { insight.category ?? "" },
                            set: { category = $0 }
                        ),
                        content: Binding(
                            get: { insight.content ?? "" },
                            set: { content = $0 }
                        ),
                        order: Binding(
                            get: { Int16(insight.order ?? "0") ?? 0 },
                            set: { order = $0 }
                        ),
                        selectedContacts: $selectedContacts,
                        onSave: {
                            updateInsight(insight)
                        }
                    )
                    .navigationTitle("Edit Insight")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingEditSheet = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadInsights() {
        insights = insightManager.fetchInsights()
    }
    
    private func createInsight() {
        guard let insight = insightManager.createInsight(
            type: type,
            category: category,
            content: content,
            order: order
        ) else { return }
        
        // Add selected contacts
        for contactId in selectedContacts {
            print("[DEBUG] Linking contactId to insight: \(contactId)")
            _ = insightManager.addContactToInsight(
                insightId: insight.insightId!,
                contactId: contactId
            )
        }
        
        showingCreateSheet = false
        loadInsights()
    }
    
    private func updateInsight(_ insight: ContactInsight) {
        guard let insightId = insight.insightId else { return }
        
        _ = insightManager.updateInsight(
            insightId: insightId,
            type: type,
            category: category,
            content: content,
            order: order
        )
        
        // Update contacts
        let currentContacts = Set(insightManager.getContactsForInsight(insightId: insightId).compactMap { $0.contactId })
        
        // Remove contacts that are no longer selected
        for contactId in currentContacts {
            if !selectedContacts.contains(contactId) {
                print("[DEBUG] Removing link: contactId=\(contactId)")
                _ = insightManager.removeContactFromInsight(
                    insightId: insightId,
                    contactId: contactId
                )
            }
        }
        
        // Add newly selected contacts
        for contactId in selectedContacts {
            if !currentContacts.contains(contactId) {
                print("[DEBUG] Adding link: contactId=\(contactId)")
                _ = insightManager.addContactToInsight(
                    insightId: insightId,
                    contactId: contactId
                )
            }
        }
        
        showingEditSheet = false
        loadInsights()
    }
}

struct InsightRow: View {
    let insight: ContactInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.type ?? "Unknown Type")
                    .font(.headline)
                Spacer()
                Text("Order: \(insight.order ?? "0")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(insight.category ?? "No Category")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(insight.content ?? "No Content")
                .font(.body)
                .lineLimit(2)
            
            if let contacts = insight.contacts as? Set<InsightContactRelationship>,
               !contacts.isEmpty {
                Text("Contacts: \(contacts.compactMap { $0.contacts?.name }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Created: \(insight.createdAt?.formatted() ?? "Unknown")")
                Spacer()
                Text("Updated: \(insight.updatedAt?.formatted() ?? "Unknown")")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct InsightFormView: View {
    @Binding var type: String
    @Binding var category: String
    @Binding var content: String
    @Binding var order: Int16
    @Binding var selectedContacts: Set<UUID>
    let onSave: () -> Void
    
    @StateObject private var contactManager = ContactManager.shared
    @State private var contacts: [Contact] = []
    
    var body: some View {
        Form {
            Section("Insight Details") {
                TextField("Type", text: $type)
                TextField("Category", text: $category)
                TextField("Content", text: $content)
                Stepper("Order: \(order)", value: $order, in: 0...100)
            }
            
            Section("Related Contacts") {
                ForEach(contacts, id: \.contactId) { contact in
                    if let contactId = contact.contactId {
                        let isOnBinding = Binding<Bool>(
                            get: { selectedContacts.contains(contactId) },
                            set: { isSelected in
                                if isSelected {
                                    selectedContacts.insert(contactId)
                                } else {
                                    selectedContacts.remove(contactId)
                                }
                            }
                        )
                        Toggle(contact.name ?? "Unknown", isOn: isOnBinding)
                    }
                }
            }
            
            Section {
                Button("Save") {
                    onSave()
                }
            }
        }
        .onAppear {
            contacts = contactManager.fetchContacts()
        }
    }
} 