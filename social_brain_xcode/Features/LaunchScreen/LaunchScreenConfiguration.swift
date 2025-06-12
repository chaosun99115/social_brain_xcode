import Foundation
import UIKit

/// Configuration for the launch screen behavior
struct LaunchScreenConfiguration {
    // MARK: - Timing Configuration
    
    /// Duration to show the launch screen in seconds
    /// Adjust this value to control how long the launch screen stays visible
    static let displayDuration: TimeInterval = 2.0
    
    /// Animation duration for fade out transition
    static let fadeOutDuration: TimeInterval = 0.5
    
    // MARK: - Display Configuration
    
    /// Whether to enable the extended launch screen
    /// Set to false to disable the extended launch screen entirely
    static let isEnabled: Bool = true
    
    /// Background color for the launch screen
    /// Should match your app's launch screen storyboard background
    static let backgroundColor = UIColor.white
    
    /// Whether to show a loading indicator
    /// Useful for longer display durations to indicate app is loading
    static let showLoadingIndicator: Bool = false
    
    // MARK: - Content Configuration
    
    /// Custom text to display on launch screen (optional)
    /// Set to nil to hide custom text
    static let customText: String? = nil
    
    /// Text color for custom text
    static let textColor = UIColor.systemGray
    
    /// Font for custom text
    static let textFont = UIFont.systemFont(ofSize: 16, weight: .medium)
    
    // MARK: - Animation Configuration
    
    /// Whether to enable fade in animation when launch screen appears
    static let enableFadeIn: Bool = true
    
    /// Fade in animation duration
    static let fadeInDuration: TimeInterval = 0.3
    
    // MARK: - Advanced Configuration
    
    /// Whether to skip launch screen on subsequent app launches
    /// This can be used to show launch screen only on first launch
    static let skipOnSubsequentLaunches: Bool = false
    
    /// UserDefaults key for tracking if app has been launched before
    static let hasLaunchedBeforeKey = "hasLaunchedBefore"
    
    // MARK: - Helper Methods
    
    /// Check if this is the first app launch
    static var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
    }
    
    /// Mark that the app has been launched
    static func markAsLaunched() {
        UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
    }
    
    /// Determine if launch screen should be shown based on configuration
    static var shouldShowLaunchScreen: Bool {
        guard isEnabled else { return false }
        
        if skipOnSubsequentLaunches && !isFirstLaunch {
            return false
        }
        
        return true
    }
} 