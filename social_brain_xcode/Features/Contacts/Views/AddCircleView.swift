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
    
    // New: All contacts for picker
    @State private var allContacts: [Contact] = []
    
    // Validation states
    @State private var isNameValid = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // 圈子名称输入框
                HStack {
                    TextField("圈子名称", text: $circleName)
                        .font(.body)
                        .padding(.vertical, 10) // Adjust as needed for font size
                        .padding(.horizontal, 12)
                }
                .background(Color.white)
                .cornerRadius(10)
                .padding(.top, 16)
                .padding(.horizontal, 16)
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
            .background(Color(red: 246/255, green: 246/255, blue: 251/255).ignoresSafeArea())
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
            .sheet(isPresented: $showingContactPicker, onDismiss: {
                // No-op
            }) {
                ContactMultiPickerSheet(
                    allContacts: allContacts,
                    selectedContactIds: $selectedContacts,
                    isPresented: $showingContactPicker,
                    onDone: {}
                )
            }
            .onAppear {
                allContacts = ContactManager.shared.fetchContacts()
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

// Preview provider
struct AddCircleView_Previews: PreviewProvider {
    static var previews: some View {
        AddCircleView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 