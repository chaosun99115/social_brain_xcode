import SwiftUI
import Combine

/// Manages the launch screen display and transition
class LaunchScreenManager: ObservableObject {
    @Published var shouldShowLaunchScreen: Bool = true
    @Published var isTransitioning: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Use the configuration to determine if launch screen should be shown
        shouldShowLaunchScreen = LaunchScreenConfiguration.shouldShowLaunchScreen
    }
    
    /// Start the launch screen sequence
    func startLaunchSequence() {
        guard LaunchScreenConfiguration.shouldShowLaunchScreen else {
            shouldShowLaunchScreen = false
            return
        }
        
        // Mark that the app has been launched (for first launch tracking)
        LaunchScreenConfiguration.markAsLaunched()
        
        // Schedule the transition after the configured duration
        DispatchQueue.main.asyncAfter(deadline: .now() + LaunchScreenConfiguration.displayDuration) {
            self.transitionToMainApp()
        }
    }
    
    /// Transition from launch screen to main app
    private func transitionToMainApp() {
        isTransitioning = true
        
        // Fade out animation duration
        let fadeOutDuration = LaunchScreenConfiguration.fadeOutDuration
        
        // After fade out completes, hide the launch screen
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.shouldShowLaunchScreen = false
            }
            
            // Reset transition state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isTransitioning = false
            }
        }
    }
    
    /// Skip launch screen (useful for testing or user preference)
    func skipLaunchScreen() {
        shouldShowLaunchScreen = false
        isTransitioning = false
    }
    
    /// Reset launch screen state (useful for testing)
    func reset() {
        shouldShowLaunchScreen = LaunchScreenConfiguration.shouldShowLaunchScreen
        isTransitioning = false
    }
    
    /// Force show launch screen (useful for testing)
    func forceShowLaunchScreen() {
        shouldShowLaunchScreen = true
        isTransitioning = false
    }
} 