import SwiftUI
import CoreData
import os.log
import UIKit

/// A view modifier that dismisses the keyboard when tapping outside
struct DismissKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                hideKeyboard()
            }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardModifier())
    }
}

/// A view for creating new prompts in the app
struct CreatePromptView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var display: String = ""
    @State private var content: String = ""
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "CreatePromptView")
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Name field
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
                
                // Display field
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
                
                // Content field
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
            .padding()
        }
        .navigationTitle("新建提示")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    savePrompt()
                }
                .foregroundColor(.green)
                .disabled(name.isEmpty || display.isEmpty || content.isEmpty)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("测试") {
                    testPromptCreation()
                }
                .foregroundColor(.blue)
            }
        }
        .background(Color.clear)
        .dismissKeyboardOnTap()
    }
    
    /// Saves the new prompt to Core Data
    private func savePrompt() {
        let newPrompt = Prompt(context: viewContext)
        newPrompt.id = UUID()
        newPrompt.name = name
        newPrompt.display = display
        newPrompt.content = content
        newPrompt.identifier = 999
        newPrompt.type = 1
        newPrompt.createdAt = Date()
        newPrompt.updatedAt = Date()
        newPrompt.order = 0
        newPrompt.recordStatus = 0
        newPrompt.intro = "" // Set empty string for intro field
        newPrompt.isArchived = false // Set isArchived to false for new prompts
        
        do {
            try viewContext.save()
            logger.debug("Successfully created new prompt: \(name)")
            
            // Verify the prompt was actually saved by fetching it back
            let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "identifier == 999")
            let savedPrompts = try viewContext.fetch(fetchRequest)
            logger.debug("Verification: Found \(savedPrompts.count) prompts with identifier 999 after saving")
            
            // Post notification to refresh prompt lists
            NotificationCenter.default.post(name: Notification.Name("RefreshPromptList"), object: nil)
            
            dismiss()
        } catch {
            logger.error("Failed to save new prompt: \(error.localizedDescription)")
            // You might want to show an alert to the user here
        }
    }
    
    /// Test method to verify prompt creation and retrieval
    private func testPromptCreation() {
        // Create a test prompt
        let testPrompt = Prompt(context: viewContext)
        testPrompt.id = UUID()
        testPrompt.name = "Test Prompt \(Date())"
        testPrompt.display = "Test Display"
        testPrompt.content = "Test Content"
        testPrompt.identifier = 999
        testPrompt.type = 1
        testPrompt.createdAt = Date()
        testPrompt.updatedAt = Date()
        testPrompt.order = 0
        testPrompt.recordStatus = 0
        testPrompt.intro = ""
        testPrompt.isArchived = false // Set isArchived to false for test prompts
        
        do {
            try viewContext.save()
            
            // Verify the prompt was saved
            let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "identifier == 999")
            let savedPrompts = try viewContext.fetch(fetchRequest)
            
            // Test the PromptConfigurationManager
            let promptManager = PromptConfigurationManager.shared
            let testPrompts = promptManager.getPromptsForSourceType("general", sampleMode: nil, context: viewContext)
            
            // Post notification to refresh
            NotificationCenter.default.post(name: Notification.Name("RefreshPromptList"), object: nil)
            
        } catch {
            logger.error("🔧 CreatePromptView: Test failed - \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview Provider
struct CreatePromptView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CreatePromptView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
} 