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
    @State private var keyboardHeight: CGFloat = 0
    
    // New: All contacts for picker
    @State private var allContacts: [Contact] = []
    
    // Validation states
    @State private var isNameValid = false
    @State private var showingErrorAlert = false
    
    // Custom background color
    private let backgroundColor = Color(red: 246/255, green: 246/255, blue: 251/255)
    
    init() {
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 圈子名称输入框
                    VStack(alignment: .leading, spacing: 8) {
                        Text("圈子名称")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        
                        HStack {
                            CircleTextField(text: $circleName)
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
                    
                    // Selected Contacts Section
                    if !selectedContacts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("已选择的联系人")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedContacts.compactMap { id in
                                        allContacts.first { $0.contactId == id }
                                    }, id: \.contactId) { contact in
                                        HStack(spacing: 4) {
                                            Text(contact.name ?? "")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            
                                            Button(action: {
                                                selectedContacts.remove(contact.contactId!)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 16))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white)
                                        .cornerRadius(16)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // 添加熟人按钮
                    Button(action: {
                        showingContactPicker = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .foregroundColor(Color.green)
                            Text("添加熟人")
                                .foregroundColor(Color.green)
                                .font(.system(size: 17, weight: .regular))
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 4)
                    
                    Spacer(minLength: keyboardHeight)
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("创建圈子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        createCircle()
                    }
                    .disabled(!isNameValid || isLoading)
                    .foregroundColor(isNameValid ? .green : .secondary)
                }
            }
            .alert("错误", isPresented: $showingErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "创建圈子时发生错误")
            }
            .sheet(isPresented: $showingContactPicker) {
                let contactsToShow = allContacts
                ContactMultiPickerSheet(
                    allContacts: contactsToShow,
                    selectedContactIds: $selectedContacts,
                    isPresented: $showingContactPicker,
                    onDone: { }
                )
            }
            .onChange(of: showingContactPicker) { isShowing in
                if isShowing {
                    // Ensure contacts are loaded before showing sheet
                    Task {
                        await loadContacts()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadContacts()
                }
                setupKeyboardObservers()
            }
            .onDisappear {
                removeKeyboardObservers()
            }
            .onChange(of: appModeManager.isSampleMode) { newValue in
                Task {
                    await loadContacts()
                }
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
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadContacts() async {
        let fetchedContacts = contactManager.fetchContacts()
        
        // Filter contacts based on app mode
        let filteredContacts: [Contact]
        if appModeManager.isSampleMode {
            filteredContacts = fetchedContacts.filter { $0.type == 0 }  // Show type=0 contacts in sample mode
        } else {
            filteredContacts = fetchedContacts.filter { $0.type == 1 }  // Show type=1 contacts in regular mode
        }
        
        // Update contacts on main thread
        await MainActor.run {
            self.allContacts = filteredContacts
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

// Custom UITextField wrapper optimized for Chinese input in circle creation
struct CircleTextField: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: 17)
        textField.backgroundColor = .white
        textField.delegate = context.coordinator
        textField.text = text
        textField.placeholder = "圈子名称"
        
        // Configure for optimal Chinese input support
        textField.autocorrectionType = .yes
        textField.smartDashesType = .yes
        textField.smartQuotesType = .yes
        textField.smartInsertDeleteType = .yes
        
        // Set proper keyboard handling
        textField.keyboardType = .default
        textField.returnKeyType = .default
        textField.enablesReturnKeyAutomatically = true
        
        // Disable input assistant view to prevent interference
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CircleTextField
        
        init(_ parent: CircleTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Allow all changes to ensure proper Chinese input
            return true
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