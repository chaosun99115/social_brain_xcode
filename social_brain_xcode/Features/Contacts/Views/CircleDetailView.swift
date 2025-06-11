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
    @State private var showingDeleteConfirmation = false
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
            Color.primaryBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                } else if filteredContacts.isEmpty {
                    emptyContactsView
                } else {
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
        }
        .overlay(
            VStack(spacing: 0) {
                Divider()
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("删除圈子")
                            .foregroundColor(.red)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                }
            }
            .background(Color(.systemBackground)),
            alignment: .bottom
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("圈子熟人")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingEditCircleSheet = true
                }) {
                    Text("编辑")
                        .font(.system(size: 17))
                        .foregroundColor(.green)
                }
            }
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactToCircleView(circle: circle) { contact in
                if let contact = contact, !contact.isArchived {
                    contacts.append(contact)
                }
            }
            .environmentObject(appModeManager)
        }
        .sheet(isPresented: $showingSocialBrain) {
            SocialBrainSheetView(
                sourceType: socialBrainContext.sourceType,
                sourceAction: socialBrainContext.sourceAction,
                sourceId: socialBrainContext.sourceId
            )
            .environmentObject(appModeManager)
        }
        .sheet(isPresented: $showingEditCircleSheet) {
            EditCircleContactsSheet(circle: circle, isPresented: $showingEditCircleSheet) { updatedContacts in
                // Filter out archived contacts from the updated list
                let nonArchivedContacts = updatedContacts.filter { !$0.isArchived }
                self.contacts = nonArchivedContacts
            }
            .environmentObject(appModeManager)
        }
        .alert("确认删除圈子", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {
                showingDeleteConfirmation = false
            }
            Button("删除", role: .destructive) {
                deleteCircle()
            }
        } message: {
            Text("确认删除圈子吗？此操作无法撤销。")
        }
        .task {
            await loadCircleData()
        }
        .onAppear {
            Task {
                await loadCircleData()
            }
            // Hide the tab bar
            hideTabBar(true)
            
            // Setup notification observers for iCloud sync
            setupNotificationObservers()
        }
        .onDisappear {
            // Show the tab bar again when leaving this view
            hideTabBar(false)
            
            // Cleanup notification observers
            cleanupNotificationObservers()
        }
    }
    
    private var emptyContactsView: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Text("这个圈子还没有熟人")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("点击编辑按钮添加熟人")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }
    
    private func loadCircleData() async {
        guard let circleId = circle.circleId else { return }
        
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        // Load contacts and filter out archived ones
        let loadedContacts = circleManager.getContactsForCircle(circleId: circleId)
        let nonArchivedContacts = loadedContacts.filter { !$0.isArchived }
        
        await MainActor.run {
            self.contacts = nonArchivedContacts
        }
    }
    
    private func deleteCircle() {
        guard let circleId = circle.circleId else { return }
        
        if circleManager.archiveCircle(circleId: circleId) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Add helper function to get tab bar height
    private func getTabBarHeight() -> CGFloat {
        let standardTabBarHeight: CGFloat = 49
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
        
        let bottomInset = keyWindow?.safeAreaInsets.bottom ?? 0
        return standardTabBarHeight + bottomInset
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
                if let tabBarController = child as? UITabBarController {
                    tabBarController.tabBar.isHidden = hidden
                }
            }
        }
    }
    
    private func setupNotificationObservers() {
        // Add observer for iCloud sync refresh notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshContactsList"),
            object: nil,
            queue: .main
        ) { _ in
            // Refresh circle data when iCloud sync completes
            Task {
                await self.loadCircleData()
            }
        }
        
        // Add observer for circles refresh notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshCirclesList"),
            object: nil,
            queue: .main
        ) { _ in
            // Refresh circle data when iCloud sync completes
            Task {
                await self.loadCircleData()
            }
        }
    }
    
    private func cleanupNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("RefreshContactsList"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("RefreshCirclesList"), object: nil)
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
    @EnvironmentObject var appModeManager: AppModeManager
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
            // Filter contacts based on app mode and exclude archived contacts
            let fetchedContacts = contactManager.fetchContacts()
            let nonArchivedContacts = fetchedContacts.filter { !$0.isArchived }
            
            if appModeManager.isSampleMode {
                // In sample mode, only show type=0 contacts
                contacts = nonArchivedContacts.filter { $0.type == 0 }
            } else {
                // In regular mode, only show type!=0 contacts
                contacts = nonArchivedContacts.filter { $0.type != 0 }
            }
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