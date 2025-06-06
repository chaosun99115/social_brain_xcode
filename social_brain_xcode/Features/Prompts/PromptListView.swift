import SwiftUI
import CoreData
import os.log

/// Represents the available prompt display modes
enum PromptMode: String, CaseIterable {
    case regular = "常规"
    case changedJob = "换工作"
    case indieDev = "独立开发"
    
    var promptIdentifier: Int {
        switch self {
        case .regular: return 1
        case .changedJob: return 111
        case .indieDev: return 121
        }
    }
}

struct PromptListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "PromptListView")
    
    let mode: PromptMode
    @FetchRequest private var prompts: FetchedResults<Prompt>
    
    init(mode: PromptMode = .regular) {
        self.mode = mode
        // Initialize fetch request with the specified mode and sort descriptors
        _prompts = FetchRequest<Prompt>(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \Prompt.order, ascending: true),
                NSSortDescriptor(keyPath: \Prompt.updatedAt, ascending: false)
            ],
            predicate: NSPredicate(format: "identifier == %d", mode.promptIdentifier),
            animation: .default
        )
    }
    
    var body: some View {
        List {
            ForEach(prompts, id: \.id) { prompt in
                NavigationLink(destination: PromptDetailView(prompt: prompt)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prompt.name ?? "")
                            .font(.body)
                        if let updatedAt = prompt.updatedAt {
                            Text("更新于: \(updatedAt.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: CreatePromptView()) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            logger.debug("PromptListView appeared with \(prompts.count) prompts for mode \(mode.rawValue)")
            PromptService.shared.debugPrintAllPrompts(in: viewContext)
        }
    }
}

// MARK: - Preview Provider
struct PromptListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            Group {
                PromptListView(mode: .regular)
                PromptListView(mode: .changedJob)
                PromptListView(mode: .indieDev)
            }
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
} 