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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    // Name Field
                    TextField("姓名", text: $name)
                        .padding(14)
                        .background(Color(.systemBackground))
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    
                    // Memo Field
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $memo)
                            .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                            .background(Color(.systemBackground))
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 140)
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
            .navigationTitle("新建联系人")
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
                        saveContact()
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
}

struct AddContactSheet_Previews: PreviewProvider {
    static var previews: some View {
        AddContactSheet(refreshTrigger: .constant(false))
            .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
    }
} 