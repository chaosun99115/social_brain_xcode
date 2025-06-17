//
//  social_brain_xcodeApp.swift
//  social_brain_xcode
//
//  Created by chao sun on 2025-04-04.
//

import SwiftUI
import CoreData
import LocalAuthentication

class AppModeManager: ObservableObject {
    @Published var isSampleMode: Bool = false {
        didSet {
            if isSampleMode != oldValue {
                NotificationCenter.default.post(
                    name: .sampleModeChanged,
                    object: nil,
                    userInfo: ["isSampleMode": isSampleMode, "sampleModeType": sampleModeType as Any]
                )
            }
        }
    }
    @Published var sampleModeType: String? = nil {
        didSet {
            if sampleModeType != oldValue {
                NotificationCenter.default.post(
                    name: .sampleModeChanged,
                    object: nil,
                    userInfo: ["isSampleMode": isSampleMode, "sampleModeType": sampleModeType as Any]
                )
            }
        }
    }
}

// Add notification name extension
extension Notification.Name {
    static let sampleModeChanged = Notification.Name("sampleModeChanged")
}

// Add a new class to manage app settings
class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()
    @Published var isFaceIDEnabled: Bool = false
    
    private init() {
        // Load saved Face ID setting
        isFaceIDEnabled = UserDefaults.standard.bool(forKey: "isFaceIDEnabled")
    }
    
    func setFaceIDEnabled(_ enabled: Bool) {
        isFaceIDEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "isFaceIDEnabled")
    }
}

// Add a new class to manage feature flags
@MainActor
class FeatureFlagManager: ObservableObject {
    static let shared = FeatureFlagManager()
    @Published var requireSubscriptionForProFeatures: Bool = true
    
    private init() {
        // Check if this is the first launch
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        
        if isFirstLaunch {
            // For new users, always require subscription
            requireSubscriptionForProFeatures = true
            UserDefaults.standard.set(true, forKey: "requireSubscriptionForProFeatures")
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        } else {
            // For existing users, load saved setting
            requireSubscriptionForProFeatures = UserDefaults.standard.bool(forKey: "requireSubscriptionForProFeatures")
        }
    }
    
    func setRequireSubscriptionForProFeatures(_ required: Bool) {
        requireSubscriptionForProFeatures = required
        UserDefaults.standard.set(required, forKey: "requireSubscriptionForProFeatures")
        print("Subscription requirement changed to: \(required)")
    }
    
    var canUseProFeatures: Bool {
        if !requireSubscriptionForProFeatures {
            return true
        }
        
        // Check if StoreKit is initialized and has network connectivity
        let storeManager = StoreKitManager.shared
        if !storeManager.isInitialized {
            // If StoreKit is not initialized yet, assume no subscription
            // This prevents network errors during app startup
            return false
        }
        
        return storeManager.subscriptionStatus == .active
    }
    
    // MARK: - Developer Methods (for testing)
    
    #if DEBUG
    /// Reset to first launch state (for testing purposes)
    func resetToFirstLaunch() {
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
        UserDefaults.standard.removeObject(forKey: "requireSubscriptionForProFeatures")
        requireSubscriptionForProFeatures = true
        UserDefaults.standard.set(true, forKey: "requireSubscriptionForProFeatures")
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        print("Reset to first launch state for testing")
    }
    #endif
}

@main
struct social_brain_xcodeApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var noteManager = NoteManager.shared
    @StateObject private var appModeManager = AppModeManager()
    @StateObject private var appSettingsManager = AppSettingsManager.shared
    @StateObject private var featureFlagManager = FeatureFlagManager.shared
    @StateObject private var launchScreenManager = LaunchScreenManager()
    @State private var isAuthenticated = false
    @State private var authError: String?
    
    init() {
        AIConfig.configure()
        // Set consistent tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemGray6
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        
        // Only re-ingest default prompts if no prompts exist at all
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Prompt> = Prompt.fetchRequest()
        do {
            let existingCount = try context.count(for: fetchRequest)
            if existingCount == 0 {
                PromptService.shared.reingestDefaultPrompts(in: context)
            }
        } catch {
            print("🔧 App: Error checking existing prompts: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                if !appSettingsManager.isFaceIDEnabled || isAuthenticated {
                    MainTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(noteManager)
                        .environmentObject(appModeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(featureFlagManager)
                        .opacity(launchScreenManager.shouldShowLaunchScreen ? 0 : 1)
                        .animation(.easeOut(duration: 0.3), value: launchScreenManager.shouldShowLaunchScreen)
                } else {
                    FaceIDAuthView(isAuthenticated: $isAuthenticated, authError: $authError)
                        .opacity(launchScreenManager.shouldShowLaunchScreen ? 0 : 1)
                        .animation(.easeOut(duration: 0.3), value: launchScreenManager.shouldShowLaunchScreen)
                }
                
                // Launch screen overlay
                if launchScreenManager.shouldShowLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            launchScreenManager.startLaunchSequence()
                        }
                }
            }
        }
    }
}
