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
    
    // MARK: - New Methods for Scenario Management
    
    /// Switch to a specific scenario while preserving user data
    static func switchToScenario(_ scenario: SeedDataScenario) {
        Task {
            do {
                try await SeedDataManager.shared.switchToScenario(scenario, in: PersistenceController.shared.container.viewContext)
                print("[SeedDataExample] Successfully switched to scenario: \(scenario.rawValue)")
                // Force UI refresh
                NotificationCenter.default.post(name: Notification.Name("RefreshNotesList"), object: nil)
            } catch {
                print("[SeedDataExample] Failed to switch scenario: \(error)")
            }
        }
    }
    
    /// Remove sample data while keeping user data
    static func removeSampleData() {
        Task {
            do {
                try SeedDataManager.shared.removeSampleData(from: PersistenceController.shared.container.viewContext)
                print("[SeedDataExample] Successfully removed sample data")
                // Force UI refresh
                NotificationCenter.default.post(name: Notification.Name("RefreshNotesList"), object: nil)
            } catch {
                print("[SeedDataExample] Failed to remove sample data: \(error)")
            }
        }
    }
    
    /// Check if sample data exists
    static func hasSampleData() -> Bool {
        do {
            return try SeedDataManager.shared.hasSampleData(in: PersistenceController.shared.container.viewContext)
        } catch {
            print("[SeedDataExample] Error checking sample data: \(error)")
            return false
        }
    }
    
    /// Check if user data exists
    static func hasUserData() -> Bool {
        do {
            return try SeedDataManager.shared.hasUserData(in: PersistenceController.shared.container.viewContext)
        } catch {
            print("[SeedDataExample] Error checking user data: \(error)")
            return false
        }
    }
    
    /// Get current scenario (if any)
    static func getCurrentScenario() -> SeedDataScenario? {
        do {
            return try SeedDataManager.shared.getCurrentScenario(in: PersistenceController.shared.container.viewContext)
        } catch {
            print("[SeedDataExample] Error getting current scenario: \(error)")
            return nil
        }
    }
    
    /// Print data statistics
    static func printDataStatistics() {
        Task {
            do {
                let context = PersistenceController.shared.container.viewContext
                
                // Get all data
                let allContacts = try SeedDataManager.shared.fetchAllContacts(in: context)
                let allNotes = try SeedDataManager.shared.fetchAllNotes(in: context)
                let allCircles = try SeedDataManager.shared.fetchAllCircles(in: context)
                
                // Get sample data
                let sampleData = try SeedDataManager.shared.fetchSampleData(in: context)
                
                // Get user data
                let userData = try SeedDataManager.shared.fetchUserData(in: context)
                
                print("\n[SeedDataExample] 📊 Data Statistics:")
                print("📱 Total Contacts: \(allContacts.count)")
                print("📝 Total Notes: \(allNotes.count)")
                print("🔵 Total Circles: \(allCircles.count)")
                print("")
                print("📚 Sample Data (type == 0):")
                print("   - Contacts: \(sampleData.contacts.count)")
                print("   - Notes: \(sampleData.notes.count)")
                print("   - Circles: \(sampleData.circles.count)")
                print("")
                print("👤 User Data (type != 0):")
                print("   - Contacts: \(userData.contacts.count)")
                print("   - Notes: \(userData.notes.count)")
                print("   - Circles: \(userData.circles.count)")
                print("")
                
                if let currentScenario = getCurrentScenario() {
                    print("🎯 Current Scenario: \(currentScenario.rawValue)")
                } else {
                    print("🎯 Current Scenario: None")
                }
                
            } catch {
                print("[SeedDataExample] Error getting data statistics: \(error)")
            }
        }
    }
} 