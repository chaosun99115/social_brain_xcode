import UIKit
import CoreData

class AppDelegate: NSObject, UIApplicationDelegate {
    static let shared = AppDelegate()
    
    private override init() {
        super.init()
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        print("Initializing Core Data stack...")
        
        // Try to find the model with different extensions
        let modelName = "social_brain_xcode"
        
        // Create the container with the model name
        let container = NSPersistentContainer(name: modelName)
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Failed to load Core Data stack: \(error)")
                fatalError("Failed to load Core Data stack: \(error)")
            }
            print("Successfully loaded persistent store: \(description)")
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("Application did finish launching")
        return true
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("Successfully saved Core Data context")
            } catch {
                print("Failed to save Core Data context: \(error)")
            }
        }
    }
} 