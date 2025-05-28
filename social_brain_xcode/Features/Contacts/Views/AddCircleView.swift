import SwiftUI
import CoreData

struct AddCircleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var circleManager = CircleManager.shared
    @StateObject private var contactManager = ContactManager.shared
    @EnvironmentObject var appModeManager: AppModeManager
    
    // Form fields
    @State private var circleName = ""
    @State private var selectedContacts: Set<UUID> = []
    @State private var showingContactPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // New: All contacts for picker
    @State private var allContacts: [Contact] = []
    
    // Validation states
    @State private var isNameValid = false
    @State private var showingErrorAlert = false
    
    // Custom background color
    private let backgroundColor = Color(red: 246/255, green: 246/255, blue: 251/255)
    
    init() {
        print("DEBUG: AddCircleView initialized")
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(backgroundColor)
        appearance.shadowColor = .clear // Removes the separator line
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // 圈子名称输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("圈子名称")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    HStack {
                        TextField("圈子名称", text: $circleName)
                            .font(.body)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                    }
                    .background(Color.white)
                    .cornerRadius(0)
                }
                .padding(.top, 16)
                .onChange(of: circleName) { newValue in
                    isNameValid = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                
                // 添加熟人按钮
                Button(action: {
                    showingContactPicker = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .foregroundColor(Color.blue)
                        Text("添加熟人")
                            .foregroundColor(Color.blue)
                            .font(.system(size: 17, weight: .regular))
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 4)
                
                Spacer()
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("新建联系人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
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
                let contactsToShow = allContacts
                let _ = print("DEBUG: Sheet presentation triggered")
                let _ = print("DEBUG: Current app mode - isSampleMode: \(appModeManager.isSampleMode)")
                let _ = print("DEBUG: Current contacts count: \(allContacts.count)")
                let _ = print("DEBUG: Created local copy of contacts with count: \(contactsToShow.count)")
                
                ContactMultiPickerSheet(
                    allContacts: contactsToShow,
                    selectedContactIds: $selectedContacts,
                    isPresented: $showingContactPicker,
                    onDone: {
                        print("DEBUG: ContactMultiPickerSheet onDone called")
                        print("DEBUG: Selected contacts count: \(selectedContacts.count)")
                        print("DEBUG: Selected contact IDs: \(selectedContacts)")
                    }
                )
                .onAppear {
                    print("DEBUG: ContactMultiPickerSheet appeared")
                    print("DEBUG: Sheet contacts count: \(contactsToShow.count)")
                    print("DEBUG: First contact in sheet - Name: \(contactsToShow.first?.name ?? "none"), Type: \(contactsToShow.first?.type ?? -1)")
                    print("DEBUG: All contacts in sheet:")
                    for contact in contactsToShow {
                        print("  - Name: \(contact.name ?? "unnamed"), Type: \(contact.type), ID: \(contact.contactId?.uuidString ?? "nil")")
                    }
                }
            }
            .onChange(of: showingContactPicker) { isShowing in
                if isShowing {
                    print("DEBUG: Sheet will show - current contacts count: \(allContacts.count)")
                    // Ensure contacts are loaded before showing sheet
                    Task {
                        await loadContacts()
                    }
                }
            }
            .onAppear {
                print("DEBUG: AddCircleView appeared")
                print("DEBUG: Initial app mode - isSampleMode: \(appModeManager.isSampleMode)")
            }
            .onChange(of: appModeManager.isSampleMode) { newValue in
                print("DEBUG: App mode changed - isSampleMode: \(newValue)")
                Task {
                    await loadContacts()
                }
            }
            .task {
                print("DEBUG: AddCircleView task started")
                await loadContacts()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onDisappear {
            // Reset navigation bar appearance when view disappears
            let defaultAppearance = UINavigationBarAppearance()
            UINavigationBar.appearance().standardAppearance = defaultAppearance
            UINavigationBar.appearance().compactAppearance = defaultAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = defaultAppearance
        }
    }
    
    private func loadContacts() async {
        print("\nDEBUG: ===== Starting contact load process =====")
        print("DEBUG: Current app mode - isSampleMode: \(appModeManager.isSampleMode)")
        
        let fetchedContacts = contactManager.fetchContacts()
        print("DEBUG: Raw fetched contacts count: \(fetchedContacts.count)")
        print("DEBUG: Raw contacts details:")
        for contact in fetchedContacts {
            print("  - Name: \(contact.name ?? "unnamed"), Type: \(contact.type), ID: \(contact.contactId?.uuidString ?? "nil")")
        }
        
        // Filter contacts based on app mode
        let filteredContacts: [Contact]
        if appModeManager.isSampleMode {
            print("DEBUG: Filtering for sample mode (type = 0)")
            filteredContacts = fetchedContacts.filter { contact in
                let isTypeZero = contact.type == 0
                print("  - Contact \(contact.name ?? "unnamed") - Type: \(contact.type), Is Type Zero: \(isTypeZero)")
                return isTypeZero
            }
        } else {
            print("DEBUG: Normal mode - using all contacts")
            filteredContacts = fetchedContacts
        }
        
        print("DEBUG: Filtered contacts count: \(filteredContacts.count)")
        print("DEBUG: Filtered contacts details:")
        for contact in filteredContacts {
            print("  - Name: \(contact.name ?? "unnamed"), Type: \(contact.type), ID: \(contact.contactId?.uuidString ?? "nil")")
        }
        
        // Update contacts on main thread
        await MainActor.run {
            self.allContacts = filteredContacts
            print("DEBUG: Updated allContacts state")
            print("DEBUG: Final allContacts count: \(self.allContacts.count)")
            print("DEBUG: ===== Contact load process completed =====\n")
        }
    }
    
    private func createCircle() {
        print("\nDEBUG: ===== Starting circle creation =====")
        print("DEBUG: Circle name: \(circleName)")
        print("DEBUG: Selected contacts count: \(selectedContacts.count)")
        print("DEBUG: Selected contact IDs: \(selectedContacts)")
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

// Preview provider
struct AddCircleView_Previews: PreviewProvider {
    static var previews: some View {
        AddCircleView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 