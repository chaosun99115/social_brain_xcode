import UIKit  

class AppDelegate: NSObject, UIApplicationDelegate {
    static let shared = AppDelegate()
    
    private override init() {
        super.init()
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("Application did finish launching")
        return true
    }
} 
