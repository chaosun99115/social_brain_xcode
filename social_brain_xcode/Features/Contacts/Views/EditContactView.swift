import SwiftUI
import CoreData

struct EditContactView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var contactManager = ContactManager.shared
    
    let contact: Contact
    @Binding var refreshTrigger: Bool
    
    @State private var name: String
    @State private var memo: String
    @State private var tel: String
    @State private var birthday: Date?
    @State private var showingBirthdayPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Add state for keyboard focus
    @FocusState private var focusedField: Field?
    
    // Add state for temporary date selection
    @State private var tempBirthday: Date
    
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
    
    init(contact: Contact, refreshTrigger: Binding<Bool>) {
        self.contact = contact
        self._refreshTrigger = refreshTrigger
        
        // Initialize state with contact data
        self._name = State(initialValue: contact.name ?? "")
        self._tel = State(initialValue: contact.tel ?? "")
        self._memo = State(initialValue: contact.memo ?? "")
        self._birthday = State(initialValue: contact.birthday)
        
        // Initialize tempBirthday
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        self._tempBirthday = State(initialValue: contact.birthday ?? calendar.date(byAdding: .year, value: -30, to: today) ?? today)
    }
    
    var body: some View {
        NavigationView {
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
                        focusedField = nil
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
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 0)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("编辑联系人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        focusedField = nil
                        dismiss()
                    }
                    .foregroundColor(.green)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        focusedField = nil
                        updateContact()
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
        .navigationViewStyle(.stack)
        .accentColor(.green)
    }
    
    private func updateContact() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        do {
            contact.name = trimmedName
            contact.tel = tel.trimmingCharacters(in: .whitespacesAndNewlines)
            contact.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
            contact.birthday = birthday
            contact.updatedAt = Date()
            
            try viewContext.save()
            refreshTrigger.toggle()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct EditContactView_Previews: PreviewProvider {
    static var previews: some View {
        let previewContext = CoreDataManager.shared.viewContext
        let contact = Contact(context: previewContext)
        contact.name = "Preview Contact"
        contact.contactId = UUID()
        contact.createdAt = Date()
        
        return EditContactView(contact: contact, refreshTrigger: .constant(false))
            .environment(\.managedObjectContext, previewContext)
    }
} 