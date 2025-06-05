import SwiftUI
import CoreData
import os.log
import UIKit

// MARK: - Logging Extension
private extension Logger {
    func logPromptDetail(_ prompt: Prompt, action: String) {
        let name = prompt.name ?? "unnamed"
        let display = prompt.display ?? "nil"
        let type = prompt.type  // type is Int16
        let identifier = prompt.identifier ?? 0
        let contentLength = prompt.content?.count ?? 0
        
        switch action {
        case "dismiss":
            debug("Navigating back from prompt: \(name) (ID: \(identifier))")
        case "appear":
            debug("""
                PromptDetailView appeared:
                - ID: \(identifier)
                - Name: \(name)
                - Display: \(display)
                - Type: \(type)
                - Content Length: \(contentLength)
                """)
        case "update":
            debug("""
                Updating prompt:
                - ID: \(identifier)
                - Name: \(name)
                - Display: \(display)
                - Type: \(type)
                - Content Length: \(contentLength)
                """)
        default:
            debug("Unknown action: \(action) for prompt: \(name) (ID: \(identifier))")
        }
    }
}

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
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "PromptDetailView")
    
    // Editable state variables
    @State private var name: String = ""
    @State private var display: String = ""
    @State private var content: String = ""
    @State private var intro: String = ""
    @State private var showUpdateAlert = false
    @State private var updateError: String?
    
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
                }
                // Display (editable, always shown)
                VStack(alignment: .leading, spacing: 8) {
                    Text("显示文案")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("请输入显示文案", text: $display)
                        .font(.body)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
            }
            .padding()
        }
        .navigationTitle("编辑提示")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("更新") {
                    updatePrompt()
                }
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
        .background(Color.clear)
        .dismissKeyboardOnTap()
        .onAppear {
            logger.logPromptDetail(prompt, action: "appear")
            // Initialize state variables with prompt values
            name = prompt.name ?? ""
            display = prompt.display ?? ""
            content = prompt.content ?? ""
            intro = prompt.intro ?? ""
        }
        .onDisappear {
            logger.logPromptDetail(prompt, action: "dismiss")
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
            logger.logPromptDetail(prompt, action: "update")
            updateError = nil
            showUpdateAlert = true
        } catch {
            logger.error("Failed to update prompt: \(error.localizedDescription)")
            updateError = "更新失败：\(error.localizedDescription)"
            showUpdateAlert = true
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