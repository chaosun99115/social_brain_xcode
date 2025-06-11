import SwiftUI
import CoreData
import os.log
import UIKit

// MARK: - Keyboard Dismiss Helper
private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct PromptDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let prompt: Prompt
    @State private var isContentExpanded = false
    
    // Editable state variables
    @State private var name: String = ""
    @State private var display: String = ""
    @State private var content: String = ""
    @State private var intro: String = ""
    @State private var showUpdateAlert = false
    @State private var updateError: String?
    
    // Delete functionality state
    @State private var showDeleteAlert = false
    @State private var deleteError: String?
    
    // Helper function to get type description
    private func getTypeDescription(_ type: Int16) -> String {
        switch type {
        case 0:
            return "社交话题"
        case 1:
            return "职场技巧"
        default:
            return "其他"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Name (editable, always shown)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("经验名称")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("请输入名称", text: $name)
                            .font(.body)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            // Ensure proper Chinese input support
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(false)
                    }
                    .padding(.top, 24)
                    
                    // Display (editable, always shown)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("包含问题")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("请输入显示文案", text: $display)
                            .font(.body)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            // Ensure proper Chinese input support
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(false)
                    }
                    
                    // Conditional fields
                    if prompt.type == 0 {
                        // Intro (non-editable, multiline)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("简介")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(intro)
                                .font(.body)
                        }
                    } else if prompt.type == 1 {
                        // Content (editable, multiline)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("提示词设定")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $content)
                                .font(.body)
                                .frame(minHeight: 120)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
            }
            .scrollDismissesKeyboard(.immediately)
            
            // Delete button - Fixed at bottom
            VStack(spacing: 0) {
                Divider()
                Button(action: {
                    showDeleteAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("删除此提示")
                            .foregroundColor(.red)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                }
            }
            .background(Color(.systemBackground))
        }
        .background(Color.white)
        .navigationTitle("编辑提示")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("更新") {
                    updatePrompt()
                }
                .foregroundColor(.green)
                .disabled(name.isEmpty || display.isEmpty || (prompt.type == 1 && content.isEmpty))
            }
        }
        .alert("更新提示", isPresented: $showUpdateAlert) {
            Button("确定") {
                if updateError == nil {
                    // Only dismiss if there was no error
                    dismiss()
                }
            }
        } message: {
            if let error = updateError {
                Text(error)
            } else {
                Text("提示已更新")
            }
        }
        .alert("删除提示", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deletePrompt()
            }
        } message: {
            Text("确定要删除这个提示吗？删除后该提示将不再显示在应用中。")
        }
        .onAppear {
            name = prompt.name ?? ""
            display = prompt.display ?? ""
            content = prompt.content ?? ""
            intro = prompt.intro ?? ""
        }
        .onDisappear {
            // Removed logger.logPromptDetail
        }
    }
    
    private func updatePrompt() {
        // Update the prompt with new values
        prompt.name = name
        prompt.display = display
        prompt.content = content
        prompt.updatedAt = Date()
        
        do {
            try viewContext.save()
            // Removed logger.logPromptDetail
            updateError = nil
            showUpdateAlert = true
        } catch {
            // Keep error logging for actual errors
            updateError = "更新失败：\(error.localizedDescription)"
            showUpdateAlert = true
        }
    }
    
    private func deletePrompt() {
        // Soft delete by setting isArchived to true
        prompt.isArchived = true
        prompt.updatedAt = Date()
        
        do {
            try viewContext.save()
            
            // Post notification to refresh prompt lists
            NotificationCenter.default.post(name: Notification.Name("RefreshPromptList"), object: nil)
            
            // Dismiss the view
            dismiss()
        } catch {
            deleteError = "删除失败：\(error.localizedDescription)"
            // You could show an error alert here if needed
        }
    }
}

// MARK: - Preview Provider
struct PromptDetailView_Previews: PreviewProvider {
    static var previewPrompt: Prompt {
        let context = PersistenceController.preview.container.viewContext
        let prompt = Prompt(context: context)
        prompt.id = UUID()
        prompt.name = "示例提示"
        prompt.display = "示例显示名称"
        prompt.content = "这是一个示例提示内容，用于预览界面效果。"
        prompt.type = 0  // Set type as Int16
        return prompt
    }
    
    static var previews: some View {
        NavigationView {
            PromptDetailView(prompt: previewPrompt)
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
} 