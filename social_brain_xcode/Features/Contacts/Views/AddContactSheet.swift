import SwiftUI
import CoreData

// Custom input field that mimics Apple's Contacts app style
struct ContactInputField: View {
    let placeholder: String
    @Binding var text: String
    let isMultiline: Bool
    let defaultHeight: CGFloat?
    
    // Constants for sizing
    private let minHeight: CGFloat = 44
    private let maxHeight: CGFloat = 200
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 12
    
    init(placeholder: String, text: Binding<String>, isMultiline: Bool, defaultHeight: CGFloat? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.isMultiline = isMultiline
        self.defaultHeight = defaultHeight
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color(.systemBackground)
                .cornerRadius(0)
            
            VStack(alignment: .leading, spacing: 0) {
                // Fixed label
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.top, verticalPadding)
                    .padding(.leading, horizontalPadding)
                
                // Text input area
                if isMultiline {
                    TextEditor(text: $text)
                        .font(.body)
                        .frame(minHeight: defaultHeight ?? minHeight, maxHeight: maxHeight)
                        .padding(.horizontal, horizontalPadding - 4) // Compensate for TextEditor's built-in padding
                        .padding(.vertical, 4)
                        .background(Color.clear)
                } else {
                    TextField("", text: $text)
                        .font(.body)
                        .frame(height: minHeight)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 4)
                        .background(Color.clear)
                }
            }
        }
    }
}

struct AddContactSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var contactManager = ContactManager.shared
    @Binding var refreshTrigger: Bool
    
    @State private var name: String = ""
    @State private var memo: String = ""
    @State private var tel: String = ""
    @State private var birthday: Date? = nil
    @State private var showingBirthdayPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Add properties for edit mode
    private let contact: Contact?
    private let isEditMode: Bool
    
    // Add state for keyboard focus
    @FocusState private var focusedField: Field?
    
    // Add state for temporary date selection
    @State private var tempBirthday: Date = {
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        return calendar.date(byAdding: .year, value: -30, to: startOfToday) ?? startOfToday
    }()
    
    // Define focusable fields
    private enum Field {
        case name, tel, memo
    }
    
    // Add a formatter for consistent date display
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    init(refreshTrigger: Binding<Bool>, contact: Contact? = nil) {
        self._refreshTrigger = refreshTrigger
        self.contact = contact
        self.isEditMode = contact != nil
        
        // Initialize state with contact data if in edit mode
        if let contact = contact {
            self._name = State(initialValue: contact.name ?? "")
            self._tel = State(initialValue: contact.tel ?? "")
            self._memo = State(initialValue: contact.memo ?? "")
            self._birthday = State(initialValue: contact.birthday)
        }
        
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemGroupedBackground
        appearance.shadowColor = .clear // Remove the shadow
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Name Field
                        ContactInputField(
                            placeholder: "姓名",
                            text: $name,
                            isMultiline: false
                        )
                        .focused($focusedField, equals: .name)
                        .padding(.top, 24)
                        
                        // Telephone Field
                        ContactInputField(
                            placeholder: "电话",
                            text: $tel,
                            isMultiline: false
                        )
                        .focused($focusedField, equals: .tel)
                        .keyboardType(.phonePad)
                        
                        // Birthday Field
                        Button(action: {
                            focusedField = nil // Dismiss keyboard before showing date picker
                            let calendar = Calendar.current
                            let today = calendar.startOfDay(for: Date())
                            let thirtyYearsAgo = calendar.date(byAdding: .year, value: -30, to: today) ?? today
                            tempBirthday = birthday ?? thirtyYearsAgo
                            showingBirthdayPicker = true
                        }) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("生日")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                    .padding(.top, 12)
                                    .padding(.leading, 16)
                                
                                HStack {
                                    if let birthday = birthday {
                                        Text(dateFormatter.string(from: birthday))
                                            .foregroundColor(.primary)
                                            .font(.body)
                                    } else {
                                        Text("")
                                            .foregroundColor(.primary)
                                            .font(.body)
                                    }
                                    Spacer()
                                    Image(systemName: "calendar")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(height: 44)
                            }
                            .background(Color(.systemBackground))
                        }
                        
                        // Memo Field
                        ContactInputField(
                            placeholder: "备注",
                            text: $memo,
                            isMultiline: true,
                            defaultHeight: 88
                        )
                        .focused($focusedField, equals: .memo)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 0)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle(isEditMode ? "编辑联系人" : "创建熟人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        focusedField = nil // Dismiss keyboard before dismissing sheet
                        dismiss()
                    }
                    .foregroundColor(.green)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        focusedField = nil // Dismiss keyboard before saving
                        if isEditMode {
                            updateContact()
                        } else {
                            saveContact()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .green)
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingBirthdayPicker) {
                NavigationView {
                    VStack(spacing: 0) {
                        let calendar = Calendar.current
                        let today = calendar.startOfDay(for: Date())
                        DatePicker(
                            "生日",
                            selection: $tempBirthday,
                            in: ...today,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 200)
                        .padding(.horizontal)
                        .onChange(of: tempBirthday) { newValue in
                            if newValue > today {
                                tempBirthday = today
                            }
                        }
                        
                        Spacer()
                    }
                    .navigationTitle("生日")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("清除") {
                                birthday = nil
                                showingBirthdayPicker = false
                            }
                            .foregroundColor(.red)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") {
                                birthday = tempBirthday
                                showingBirthdayPicker = false
                            }
                            .foregroundColor(.green)
                        }
                    }
                }
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                .background(Color(.systemGroupedBackground))
            }
        }
        .accentColor(.green)
    }
    
    private func saveContact() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { 
            print("[DEBUG] saveContact: Name is empty, aborting save")
            return 
        }
        
        do {
            print("[DEBUG] saveContact: Starting to save new contact with name: \(trimmedName)")
            // Create new contact
            let contact = Contact(context: viewContext)
            contact.contactId = UUID()
            contact.name = trimmedName
            contact.tel = tel.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[DEBUG] saveContact: Saving birthday: \(String(describing: birthday))")
            contact.birthday = birthday
            contact.createdAt = Date()
            contact.updatedAt = Date()
            
            try viewContext.save()
            print("[DEBUG] saveContact: Successfully saved new contact with ID: \(String(describing: contact.contactId))")
            refreshTrigger.toggle()
            dismiss()
        } catch {
            print("[DEBUG] saveContact: Error saving contact: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func updateContact() {
        guard let contact = contact else { 
            print("[DEBUG] updateContact: No contact provided for update")
            return 
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { 
            print("[DEBUG] updateContact: Name is empty, aborting update")
            return 
        }
        
        do {
            print("[DEBUG] updateContact: Starting to update contact with ID: \(String(describing: contact.contactId))")
            // Update contact
            contact.name = trimmedName
            contact.tel = tel.trimmingCharacters(in: .whitespacesAndNewlines)
            contact.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)  // Update memo directly
            print("[DEBUG] updateContact: Updating birthday: \(String(describing: birthday))")
            contact.birthday = birthday
            contact.updatedAt = Date()
            
            try viewContext.save()
            print("[DEBUG] updateContact: Successfully updated contact with ID: \(String(describing: contact.contactId))")
            refreshTrigger.toggle()
            dismiss()
        } catch {
            print("[DEBUG] updateContact: Error updating contact: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct AddContactSheet_Previews: PreviewProvider {
    static var previews: some View {
        AddContactSheet(refreshTrigger: .constant(false))
            .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
    }
} 