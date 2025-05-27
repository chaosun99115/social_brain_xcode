import SwiftUI
import CoreData
import UIKit

struct CircleDetailView: View {
    let circle: Circle
    @StateObject private var circleManager = CircleManager.shared
    @State private var contacts: [Contact] = []
    @State private var isLoading = true
    @State private var showingAddContact = false
    @State private var showingEditCircleSheet = false
    @State private var showingSocialBrain = false
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var appModeManager: AppModeManager
    
    // Add a UIKit appearance modifier
    init(circle: Circle) {
        self.circle = circle
        
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.primaryBackground)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Context parameters for SocialBrain
    private var socialBrainContext: (sourceType: String, sourceAction: String, sourceId: String) {
        return (
            sourceType: "circle",
            sourceAction: "general",
            sourceId: circle.circleId?.uuidString ?? ""
        )
    }
    
    var filteredContacts: [Contact] {
        contacts
    }
    
    var body: some View {
        ZStack {
            Color.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Contacts Section
                        VStack(alignment: .leading, spacing: 12) {
                            if filteredContacts.isEmpty {
                                Text("No contacts in this circle")
                                    .font(.subheadline)
                                    .foregroundColor(.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(Array(filteredContacts.enumerated()), id: \.element.contactId) { idx, contact in
                                    NavigationLink(destination: SocialContactDetailView(contact: contact)) {
                                        HStack(spacing: 16) {
                                            // Contact Info
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(contact.name ?? "")
                                                    .font(.system(size: 17))
                                                    .foregroundColor(.primaryText)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondaryText)
                                        }
                                        .contentShape(Rectangle())  // Makes entire row tappable
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 20)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Divider()
                                        .padding(.leading, 20)
                                        .padding(.vertical, 1)
                                }
                                .background(Color.cardBackground)
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical)
                    Spacer().frame(height: 40)
                }
                .background(Color.primaryBackground)
                
                // Fixed bottom toolbar that respects safe areas
                VStack(spacing: 0) {
                    Divider()
                    
                    // Bottom toolbar content
                    HStack(spacing: 0) {
                        // AI Insights button
                        Button(action: {
                            showingSocialBrain = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20))
                                Text("关系备忘录")
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 44)
                    .padding(.bottom, safeAreaPadding)
                }
                .background(
                    VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                        .ignoresSafeArea()
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("圈子熟人")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingEditCircleSheet = true
                }) {
                    Text("编辑")
                        .font(.system(size: 17))
                        .foregroundColor(.accentColor)
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
        .sheet(isPresented: $showingSocialBrain) {
            SocialBrainView(
                sourceType: socialBrainContext.sourceType,
                sourceAction: socialBrainContext.sourceAction,
                sourceId: socialBrainContext.sourceId
            )
            .environmentObject(appModeManager)
            .onAppear {
                print("[CircleDetailView] Opening SocialBrainView with context: type=\(socialBrainContext.sourceType), action=\(socialBrainContext.sourceAction), id=\(socialBrainContext.sourceId)")
            }
        }
        .sheet(isPresented: $showingEditCircleSheet) {
            EditCircleContactsSheet(circle: circle, isPresented: $showingEditCircleSheet) { updatedContacts in
                self.contacts = updatedContacts
            }
        }
        .task {
            await loadCircleData()
        }
        .onAppear {
            // Hide the tab bar
            hideTabBar(true)
        }
        .onDisappear {
            // Show the tab bar again when leaving this view
            hideTabBar(false)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    private func loadCircleData() async {
        guard let circleId = circle.circleId else { return }
        
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        // Load contacts
        let loadedContacts = circleManager.getContactsForCircle(circleId: circleId)
        
        await MainActor.run {
            self.contacts = loadedContacts
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
    
    // Dynamic safe area padding for different devices
    private var safeAreaPadding: CGFloat {
        // Get the bottom safe area inset
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
            
        let bottomInset = keyWindow?.safeAreaInsets.bottom ?? 0
        
        // Add padding based on whether device has home indicator
        return bottomInset > 0 ? bottomInset + 8 : 8
    }
    
    // UIViewRepresentable wrapper for UIVisualEffectView to use blur effects
    struct VisualEffectView: UIViewRepresentable {
        var effect: UIVisualEffect?
        
        func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
            UIVisualEffectView()
        }
        
        func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
            uiView.effect = effect
        }
    }
    
    // Function to hide/show the tab bar
    private func hideTabBar(_ hidden: Bool) {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
        
        if let keyWindow = keyWindow {
            keyWindow.rootViewController?.children.forEach { child in
                // Find the UITabBarController and hide its tabBar
                if let tabBarController = child as? UITabBarController {
                    tabBarController.tabBar.isHidden = hidden
                }
            }
        }
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
            type: 0,
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

// Add new supporting views
struct CircleInsightRow: View {
    let insight: CircleInsight
    let isLast: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                SwiftUI.Circle()
                    .foregroundColor(Color.tertiaryText)
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(insight.content ?? "")
                        .font(.system(size: 16))
                        .foregroundColor(.primaryText)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            if !isLast {
                Divider()
                    .padding(.leading, 22)
                    .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

struct EditCircleContactsSheet: View {
    let circle: Circle
    @Binding var isPresented: Bool
    var onUpdate: ([Contact]) -> Void
    @StateObject private var contactManager = ContactManager.shared
    @StateObject private var circleManager = CircleManager.shared
    @State private var allContacts: [Contact] = []
    @State private var selectedContactIds: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(allContacts, id: \.contactId) { contact in
                    HStack {
                    Text(contact.name ?? "")
                        Spacer()
                        CheckboxView(isChecked: selectedContactIds.contains(contact.contactId ?? UUID())) {
                            toggleContact(contact)
                        }
                    }
                }
            }
            .navigationTitle("选择圈子熟人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onUpdate(selectedContactIds.compactMap { id in allContacts.first(where: { $0.contactId == id }) })
                        isPresented = false
                    }
                }
            }
            .onAppear {
                loadContacts()
            }
        }
    }
    
    private func loadContacts() {
        allContacts = contactManager.fetchContacts()
        if let circleId = circle.circleId {
            let related = circleManager.getContactsForCircle(circleId: circleId)
            selectedContactIds = Set(related.compactMap { $0.contactId })
        }
    }
    
    private func toggleContact(_ contact: Contact) {
        guard let contactId = contact.contactId, let circleId = circle.circleId else { return }
        if selectedContactIds.contains(contactId) {
            // Remove
            if circleManager.removeContactFromCircle(circleId: circleId, contactId: contactId) {
                selectedContactIds.remove(contactId)
            }
        } else {
            // Add
            if circleManager.addContactToCircle(circleId: circleId, contactId: contactId) {
                selectedContactIds.insert(contactId)
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