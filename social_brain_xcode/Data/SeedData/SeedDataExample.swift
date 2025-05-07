import Foundation
import UIKit
import CoreData

class SeedDataExample {
    static func importSeedDataExample() async {
        // Get the managed object context from your Core Data stack
        guard let context = await (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            print("Failed to get managed object context")
            return
        }
        
        do {
            // Configure the data source (local or remote)
            SeedDataManager.shared.setDataSource(.local) // or .remote
            
            // Import the seed data
            try await SeedDataManager.shared.importSeedData(into: context)
            print("Successfully imported seed data")
        } catch {
            print("Failed to import seed data: \(error)")
        }
    }
    
    // Add a non-async wrapper for convenience
    static func importSeedData() {
        Task {
            await importSeedDataExample()
        }
    }
} 