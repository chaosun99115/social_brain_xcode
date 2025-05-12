//
//  social_brain_xcodeApp.swift
//  social_brain_xcode
//
//  Created by chao sun on 2025-04-04.
//

import SwiftUI
import CoreData

class AppModeManager: ObservableObject {
    @Published var isSampleMode: Bool = false {
        didSet {
            print("[AppModeManager] isSampleMode changed to \(isSampleMode)")
        }
    }
    @Published var sampleModeType: String? = nil {
        didSet {
            print("[AppModeManager] sampleModeType changed to \(String(describing: sampleModeType))")
        }
    }
}

@main
struct social_brain_xcodeApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var localizationManager = LocalizationManager()
    @StateObject private var noteManager = NoteManager.shared
    @StateObject private var appModeManager = AppModeManager()
    
    init() {
        AIConfig.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(localizationManager)
                .environmentObject(noteManager)
                .environmentObject(appModeManager)
        }
    }
}

// MARK: - Localization Manager
class LocalizationManager: ObservableObject {
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
        }
    }
    
    init() {
        self.currentLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
    }
    
    func setLanguage(_ language: String) {
        currentLanguage = language
    }
}
