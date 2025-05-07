//
//  social_brain_xcodeApp.swift
//  social_brain_xcode
//
//  Created by chao sun on 2025-04-04.
//

import SwiftUI

class LocalizationManager: ObservableObject {
    @Published var currentLanguage = Locale.preferredLanguages.first?.contains("zh") == true ? "zh" : "en"
    
    // Return localized string based on the currentLanguage
    func localizedString(for key: String) -> String {
        let bundle = Bundle.main
        let language = currentLanguage
        
        if let path = bundle.path(forResource: language, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: languageBundle, comment: "")
        }
        
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}

@main
struct social_brain_xcodeApp: App {
    @StateObject private var localizationManager = LocalizationManager()
    @StateObject private var noteManager = NoteManager.shared
    let persistenceController = PersistenceController.shared
    
    init() {
        // Configure AI service
        AIConfig.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(localizationManager)
                .environmentObject(noteManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
