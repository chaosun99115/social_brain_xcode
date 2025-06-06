import SwiftUI

@main
struct social_brain_xcodeApp: App {
    @StateObject private var appModeManager = AppModeManager()
    
    init() {
        // Force re-ingest prompts on app start
        Task {
            await PromptConfigurationManager.shared.forceReingestDefaultPrompts()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModeManager)
        }
    }
} 