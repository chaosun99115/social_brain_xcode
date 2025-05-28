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
    @Published var isSampleMode: Bool = false
    @Published var sampleModeType: String? = nil
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
        // Load saved feature flag setting
        requireSubscriptionForProFeatures = UserDefaults.standard.bool(forKey: "requireSubscriptionForProFeatures")
    }
    
    func setRequireSubscriptionForProFeatures(_ required: Bool) {
        requireSubscriptionForProFeatures = required
        UserDefaults.standard.set(required, forKey: "requireSubscriptionForProFeatures")
    }
    
    var canUseProFeatures: Bool {
        if !requireSubscriptionForProFeatures {
            return true
        }
        return StoreKitManager.shared.subscriptionStatus == .active
    }
}

@main
struct social_brain_xcodeApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var noteManager = NoteManager.shared
    @StateObject private var appModeManager = AppModeManager()
    @StateObject private var appSettingsManager = AppSettingsManager.shared
    @StateObject private var featureFlagManager = FeatureFlagManager.shared
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
    }
    
    var body: some Scene {
        WindowGroup {
            if !appSettingsManager.isFaceIDEnabled || isAuthenticated {
                MainTabView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(noteManager)
                    .environmentObject(appModeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(featureFlagManager)
            } else {
                FaceIDAuthView(isAuthenticated: $isAuthenticated, authError: $authError)
            }
        }
    }
}
