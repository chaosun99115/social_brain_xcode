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
                }
                
                // Display field
                VStack(alignment: .leading, spacing: 8) {
                    Text("显示文案")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("请输入显示文案", text: $display)
                        .font(.body)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
        
        do {
            try viewContext.save()
            logger.debug("Successfully created new prompt: \(name)")
            dismiss()
        } catch {
            logger.error("Failed to save new prompt: \(error.localizedDescription)")
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