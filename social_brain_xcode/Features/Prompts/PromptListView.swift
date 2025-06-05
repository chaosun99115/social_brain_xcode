import SwiftUI
import CoreData
import os.log

struct PromptListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "PromptListView")
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Prompt.name, ascending: true)],
        animation: .default)
    private var prompts: FetchedResults<Prompt>
    
    var body: some View {
        List {
            ForEach(prompts, id: \.id) { prompt in
                NavigationLink(destination: PromptDetailView(prompt: prompt)) {
                    Text(prompt.name ?? "")
                        .font(.body)
                        .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("社交经验库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: CreatePromptView()) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            logger.debug("PromptListView appeared with \(prompts.count) prompts")
            PromptService.shared.debugPrintAllPrompts(in: viewContext)
        }
    }
}

// MARK: - Preview Provider
struct PromptListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PromptListView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
} 