//
//  social_brain_xcodeApp.swift
//  social_brain_xcode
//
//  Created by chao sun on 2025-04-04.
//

import SwiftUI
import CoreData

@main
struct social_brain_xcodeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var localizationManager = LocalizationManager()
    @StateObject private var noteManager = NoteManager.shared
    @State private var isFirstLaunch = true
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, AppDelegate.shared.persistentContainer.viewContext)
                .environmentObject(localizationManager)
                .environmentObject(noteManager)
                .onAppear {
                    if isFirstLaunch {
                        Task {
                            await importSeedDataIfNeeded()
                            isFirstLaunch = false
                        }
                    }
                }
        }
    }
    
    private func importSeedDataIfNeeded() async {
        print("Checking if seed data needs to be imported...")
        let defaults = UserDefaults.standard
        let hasImportedSeedData = defaults.bool(forKey: "hasImportedSeedData")
        print("Has imported seed data: \(hasImportedSeedData)")
        
        if !hasImportedSeedData {
            print("Starting seed data import process...")
            do {
                // Configure the data source (local or remote)
                SeedDataManager.shared.setDataSource(.local)
                print("Set data source to local")
                
                // Import the seed data
                print("Attempting to import seed data...")
                try await SeedDataManager.shared.importSeedData(into: AppDelegate.shared.persistentContainer.viewContext)
                print("Successfully imported seed data")
                
                // Mark as imported
                defaults.set(true, forKey: "hasImportedSeedData")
                print("Marked seed data as imported in UserDefaults")
            } catch {
                print("Failed to import seed data: \(error)")
                if let nsError = error as NSError? {
                    print("Error domain: \(nsError.domain)")
                    print("Error code: \(nsError.code)")
                    print("Error description: \(nsError.localizedDescription)")
                    print("Error user info: \(nsError.userInfo)")
                }
            }
        } else {
            print("Seed data already imported, skipping import process")
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
