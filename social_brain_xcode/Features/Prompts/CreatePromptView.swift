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
                    TextField("请输入经验名称", text: $name)
                        .font(.body)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        // Ensure proper Chinese input support
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                }
                
                // Display field
                VStack(alignment: .leading, spacing: 8) {
                    Text("显示文案")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("显示文案将展示在\"人际大脑\"页面", text: $display)
                        .font(.body)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        // Ensure proper Chinese input support
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                }
                
                // Content field
                VStack(alignment: .leading, spacing: 8) {
                    Text("经验细节")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 120)
                        .overlay(
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3))
                                if content.isEmpty {
                                    Text("请详细描述经验细节，系统将基于这些细节进行思考然后回答你的问题")
                                        .font(.body)
                                        .foregroundColor(Color(.placeholderText))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                        )
                }
            }
            .padding()
        }
        .navigationTitle("新建经验")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    savePrompt()
                }
                .foregroundColor(name.isEmpty ? .gray : .green)
                .disabled(name.isEmpty || display.isEmpty || content.isEmpty)
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