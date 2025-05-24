//
//  social_brain_xcodeApp.swift
//  social_brain_xcode
//
//  Created by chao sun on 2025-04-04.
//

import SwiftUI
import CoreData

class AppModeManager: ObservableObject {
    @Published var isSampleMode: Bool = false
    @Published var sampleModeType: String? = nil
}

@main
struct social_brain_xcodeApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var noteManager = NoteManager.shared
    @StateObject private var appModeManager = AppModeManager()
    
    init() {
        AIConfig.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(noteManager)
                .environmentObject(appModeManager)
        }
    }
}
