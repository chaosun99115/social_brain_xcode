import SwiftUI
import CoreData

struct AddCircleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var circleManager = CircleManager.shared
    
    // Form fields
    @State private var circleName = ""
    @State private var selectedContacts: Set<UUID> = []
    @State private var showingContactPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Validation states
    @State private var isNameValid = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("圈子名称", text: $circleName)
                        .onChange(of: circleName) { newValue in
                            isNameValid = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                }
                
                Section(header: Text("圈子成员")) {
                    Button(action: {
                        showingContactPicker = true
                    }) {
                        HStack {
                            Text("选择成员")
                            Spacer()
                            Text("\(selectedContacts.count) 人")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("新建圈子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("创建") {
                        createCircle()
                    }
                    .disabled(!isNameValid || isLoading)
                }
            }
            .alert("错误", isPresented: $showingErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "创建圈子时发生错误")
            }
            .sheet(isPresented: $showingContactPicker) {
                CircleContactPickerView(selectedContacts: $selectedContacts)
            }
        }
    }
    
    private func createCircle() {
        guard isNameValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Create circle
        let trimmedName = circleName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                if let circle = circleManager.createCircle(name: trimmedName, type: 1) {
                    // Add selected contacts to the circle
                    if let circleId = circle.circleId {
                        for contactId in selectedContacts {
                            _ = circleManager.addContactToCircle(circleId: circleId, contactId: contactId)
                        }
                    }
                    
                    await MainActor.run {
                        isLoading = false
                        dismiss()
                    }
                } else {
                    throw NSError(domain: "CircleCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "创建圈子失败"])
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
}

// Contact picker view for selecting circle members
struct CircleContactPickerView: View {
    @Binding var selectedContacts: Set<UUID>
    @Environment(\.dismiss) private var dismiss
    @StateObject private var contactManager = ContactManager.shared
    @State private var contacts: [Contact] = []
    @State private var searchText = ""
    
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
                    HStack {
                        if let name = contact.name {
                            Text(name)
                        }
                        Spacer()
                        if let contactId = contact.contactId {
                            CheckboxView(isChecked: selectedContacts.contains(contactId)) {
                                toggleContact(contactId)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择成员")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索联系人")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            contacts = contactManager.fetchContacts()
        }
    }
    
    private func toggleContact(_ contactId: UUID) {
        if selectedContacts.contains(contactId) {
            selectedContacts.remove(contactId)
        } else {
            selectedContacts.insert(contactId)
        }
    }
}

// Preview provider
struct AddCircleView_Previews: PreviewProvider {
    static var previews: some View {
        AddCircleView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 