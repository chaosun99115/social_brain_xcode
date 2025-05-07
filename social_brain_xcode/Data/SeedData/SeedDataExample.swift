import Foundation
import UIKit
import CoreData

class SeedDataExample {
    static func importSeedDataExample() {
        Task {
            do {
                try await SeedDataManager.shared.importSeedData(into: PersistenceController.shared.container.viewContext)
                print("[SeedDataExample] Seed data import completed successfully.")
                // Force UI refresh
                NotificationCenter.default.post(name: Notification.Name("RefreshNotesList"), object: nil)
            } catch {
                print("[SeedDataExample] Failed to import seed data: \(error)")
            }
        }
    }
    
    // Add a non-async wrapper for convenience
    static func importSeedData() {
        Task {
            await importSeedDataExample()
        }
    }
} 