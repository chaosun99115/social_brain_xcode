import SwiftUI
import CoreData

struct AddContactSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var contactManager = ContactManager.shared
    @Binding var refreshTrigger: Bool
    
    @State private var name: String = ""
    @State private var memo: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Add properties for edit mode
    private let contact: Contact?
    private let isEditMode: Bool
    
    init(refreshTrigger: Binding<Bool>, contact: Contact? = nil) {
        self._refreshTrigger = refreshTrigger
        self.contact = contact
        self.isEditMode = contact != nil
        
        // Initialize state with contact data if in edit mode
        if let contact = contact {
            self._name = State(initialValue: contact.name ?? "")
            // Find memo note (type=2) for this contact
            if let contactId = contact.contactId {
                let notes = ContactManager.shared.getNotesForContact(contactId: contactId)
                if let memoNote = notes.first(where: { $0.type == 2 }) {
                    self._memo = State(initialValue: memoNote.content ?? "")
                }
            }
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
                        TextField("姓名", text: $name)
                            .padding(14)
                            .background(Color(.systemBackground))
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(0)
                            .padding(.top, 24)
                        
                        // Memo Field
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $memo)
                                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                                .background(Color(.systemBackground))
                                .font(.body)
                                .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 140)
                                .cornerRadius(0)
                            if memo.isEmpty {
                                Text("备注")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(EdgeInsets(top: 16, leading: 18, bottom: 0, trailing: 0))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 0)
                }
            }
            .navigationTitle(isEditMode ? "编辑联系人" : "创建熟人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if isEditMode {
                            updateContact()
                        } else {
                            saveContact()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .accentColor(.blue)
    }
    
    private func saveContact() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        do {
            // Create new contact
            let contact = Contact(context: viewContext)
            contact.contactId = UUID()
            contact.name = trimmedName
            contact.createdAt = Date()
            contact.updatedAt = Date()
            
            // Create initial note for memo if not empty
            if !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let note = Note(context: viewContext)
                note.noteId = UUID()
                note.content = memo
                note.type = 2 // Memo type
                note.createdAt = Date()
                note.updatedAt = Date()
                
                // Create the relationship
                let relationship = NoteContactRelationship(context: viewContext)
                relationship.relationshipId = UUID()
                relationship.createdAt = Date()
                relationship.notes = note
                relationship.contacts = contact
            }
            
            try viewContext.save()
            refreshTrigger.toggle()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func updateContact() {
        guard let contact = contact else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        do {
            // Update contact
            contact.name = trimmedName
            contact.updatedAt = Date()
            
            // Update or create memo note
            if let contactId = contact.contactId {
                let notes = ContactManager.shared.getNotesForContact(contactId: contactId)
                if let memoNote = notes.first(where: { $0.type == 2 }) {
                    // Update existing memo
                    memoNote.content = memo
                    memoNote.updatedAt = Date()
                } else if !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Create new memo note
                    let note = Note(context: viewContext)
                    note.noteId = UUID()
                    note.content = memo
                    note.type = 2 // Memo type
                    note.createdAt = Date()
                    note.updatedAt = Date()
                    
                    // Create the relationship
                    let relationship = NoteContactRelationship(context: viewContext)
                    relationship.relationshipId = UUID()
                    relationship.createdAt = Date()
                    relationship.notes = note
                    relationship.contacts = contact
                }
            }
            
            try viewContext.save()
            refreshTrigger.toggle()
            dismiss()
        } catch {
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