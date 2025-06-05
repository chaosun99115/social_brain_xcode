import SwiftUI
import os.log

// MARK: - Logging Extension
private extension Logger {
    func logPromptDetail(_ prompt: Prompt, action: String) {
        let name = prompt.name ?? "unnamed"
        let display = prompt.display ?? "nil"
        let type = prompt.type ?? "nil"
        let contentLength = prompt.content?.count ?? 0
        
        switch action {
        case "dismiss":
            debug("Navigating back from prompt: \(name)")
        case "appear":
            debug("""
                PromptDetailView appeared:
                - Name: \(name)
                - Display: \(display)
                - Type: \(type)
                - Content Length: \(contentLength)
                """)
        default:
            debug("Unknown action: \(action) for prompt: \(name)")
        }
    }
}

struct PromptDetailView: View {
    let prompt: Prompt
    @State private var isContentExpanded = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "PromptDetailView")
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Display Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("显示名称")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(prompt.display ?? "")
                        .font(.headline)
                }
                .padding(.horizontal)
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text("内容")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    DisclosureGroup(
                        isExpanded: $isContentExpanded,
                        content: {
                            Text(prompt.content ?? "")
                                .font(.body)
                                .padding(.top, 8)
                        },
                        label: {
                            Text(isContentExpanded ? "收起内容" : "展开内容")
                                .font(.headline)
                        }
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(prompt.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            logger.logPromptDetail(prompt, action: "appear")
        }
        .onDisappear {
            logger.logPromptDetail(prompt, action: "dismiss")
        }
    }
}

struct PromptDetailView_Previews: PreviewProvider {
    static var previewPrompt: Prompt {
        let context = PersistenceController.preview.container.viewContext
        let prompt = Prompt(context: context)
        prompt.id = UUID()
        prompt.name = "示例提示"
        prompt.display = "示例显示名称"
        prompt.content = "这是一个示例提示内容，用于预览界面效果。"
        prompt.type = "示例类型"
        return prompt
    }
    
    static var previews: some View {
        NavigationView {
            PromptDetailView(prompt: previewPrompt)
        }
    }
} 