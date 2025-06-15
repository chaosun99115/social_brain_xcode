import SwiftUI
import UIKit
import Combine

/// Global Tab Bar Manager for centralized tab bar visibility control
/// Handles all tab bar show/hide operations with proper state management
class TabBarManager: ObservableObject {
    static let shared = TabBarManager()
    
    // MARK: - Published Properties
    @Published var isTabBarVisible: Bool = true
    @Published var currentViewType: TabBarViewType = .mainTab
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var tabBarController: UITabBarController?
    private var isInitialized = false
    private var navigationStack: [TabBarViewType] = [] // Track navigation stack
    
    // MARK: - View Types
    enum TabBarViewType {
        case mainTab           // SocialBrainView, SocialContactView, SocialNotesView
        case detailView        // SocialContactDetailView, CircleDetailView, NoteDetailNav, SocialNoteDetailView
        case modalView         // Any modal or sheet
        case unknown
    }
    
    private init() {
        setupNotificationObservers()
        setupStateObservers()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the tab bar manager with the main tab bar controller
    func initialize(with tabBarController: UITabBarController) {
        self.tabBarController = tabBarController
        self.isInitialized = true
        
        // Set initial state
        updateTabBarVisibility(animated: false)
    }
    
    /// Show tab bar for main tab views
    func showTabBar() {
        handleNavigationStateChange(to: .mainTab)
    }
    
    /// Hide tab bar for detail views
    func hideTabBar() {
        handleNavigationStateChange(to: .detailView)
    }
    
    /// Set tab bar visibility for modal views
    func setTabBarForModal(_ visible: Bool) {
        currentViewType = .modalView
        isTabBarVisible = visible
        updateTabBarVisibility(animated: false)
    }
    
    /// Force update tab bar visibility (used for app state restoration)
    func forceUpdateTabBarVisibility() {
        updateTabBarVisibility(animated: false)
    }
    
    /// Restore tab bar to main tab state (used when navigating back from detail views)
    func restoreTabBarForMainTab() {
        handleNavigationStateChange(to: .mainTab)
    }
    
    /// Immediately restore tab bar for main tab views (no animation)
    func immediatelyRestoreTabBarForMainTab() {
        currentViewType = .mainTab
        isTabBarVisible = true
        updateTabBarVisibility(animated: false)
    }
    
    /// Handle navigation state change (called when navigating between views)
    func handleNavigationStateChange(to viewType: TabBarViewType) {
        // Track navigation stack
        navigationStack.append(viewType)
        
        currentViewType = viewType
        switch viewType {
        case .mainTab:
            isTabBarVisible = true
        case .detailView:
            isTabBarVisible = false
        case .modalView:
            // Keep current visibility state for modals
            break
        case .unknown:
            // Default to visible for unknown states
            isTabBarVisible = true
        }
        updateTabBarVisibility(animated: false)
    }
    
    /// Check if we should restore tab bar when a view disappears
    func shouldRestoreTabBarOnDisappear() -> Bool {
        // If we have at least 2 items in the stack and the previous one was a main tab
        guard navigationStack.count >= 2 else { return false }
        
        let currentIndex = navigationStack.count - 1
        let previousIndex = navigationStack.count - 2
        
        // If we're currently in a detail view and the previous view was a main tab
        // OR if we're returning to a main tab view (the previous view in stack is main tab)
        return (navigationStack[currentIndex] == .detailView && navigationStack[previousIndex] == .mainTab) ||
               navigationStack[previousIndex] == .mainTab
    }
    
    /// Check if we should immediately show tab bar (for main tab views)
    func shouldImmediatelyShowTabBar() -> Bool {
        // If we have at least 1 item in the stack and it's a main tab
        guard !navigationStack.isEmpty else { return false }
        
        let currentIndex = navigationStack.count - 1
        return navigationStack[currentIndex] == .mainTab
    }
    
    /// Check if the current view is a main tab view
    func isCurrentViewMainTab() -> Bool {
        guard !navigationStack.isEmpty else { return false }
        
        let currentIndex = navigationStack.count - 1
        return navigationStack[currentIndex] == .mainTab
    }
    
    /// Remove the current view from navigation stack when it disappears
    func removeCurrentViewFromStack() {
        if !navigationStack.isEmpty {
            navigationStack.removeLast()
        }
    }
    
    /// Get current tab bar height including safe area
    func getTabBarHeight() -> CGFloat {
        guard let tabBarController = tabBarController else { return 0 }
        
        let standardHeight: CGFloat = 49
        let safeAreaInset = tabBarController.view.safeAreaInsets.bottom
        
        return isTabBarVisible ? (standardHeight + safeAreaInset) : 0
    }
    
    // MARK: - Private Methods
    
    private func updateTabBarVisibility(animated: Bool) {
        guard let tabBarController = tabBarController, isInitialized else { return }
        
        // Determine if tab bar should be visible based on current state
        let shouldBeVisible: Bool
        switch currentViewType {
        case .mainTab:
            shouldBeVisible = isTabBarVisible
        case .detailView:
            shouldBeVisible = false
        case .modalView:
            shouldBeVisible = isTabBarVisible
        case .unknown:
            shouldBeVisible = isTabBarVisible
        }
        
        // Immediate visibility without any async or alpha changes
        tabBarController.tabBar.isHidden = !shouldBeVisible
        // Remove alpha manipulation to prevent any visual transitions
        // tabBarController.tabBar.alpha = shouldBeVisible ? 1.0 : 0.0
        tabBarController.view.layoutIfNeeded()
    }
    
    private func setupNotificationObservers() {
        // App lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        // Navigation notifications
        NotificationCenter.default.publisher(for: Notification.Name("NavigationToDetailView"))
            .sink { [weak self] _ in
                self?.hideTabBar()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: Notification.Name("NavigationToMainTab"))
            .sink { [weak self] _ in
                self?.showTabBar()
            }
            .store(in: &cancellables)
    }
    
    private func setupStateObservers() {
        // Observe changes to published properties
        $isTabBarVisible
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.updateTabBarVisibility(animated: false)
            }
            .store(in: &cancellables)
        
        $currentViewType
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.updateTabBarVisibility(animated: false)
            }
            .store(in: &cancellables)
    }
    
    private func handleAppDidBecomeActive() {
        // Restore tab bar state when app becomes active
        DispatchQueue.main.async {
            self.forceUpdateTabBarVisibility()
        }
    }
    
    private func handleAppWillEnterForeground() {
        // Restore tab bar state when app enters foreground
        DispatchQueue.main.async {
            self.forceUpdateTabBarVisibility()
        }
    }
    
    private func handleAppDidEnterBackground() {
        // Save current state when app enters background
        // No action needed as state is preserved in published properties
    }
}

// MARK: - SwiftUI View Modifiers

extension View {
    /// Show tab bar for main tab views
    func showTabBar() -> some View {
        self.onAppear {
            TabBarManager.shared.handleNavigationStateChange(to: .mainTab)
        }
        .onDisappear {
            // Remove from navigation stack when main tab disappears
            TabBarManager.shared.removeCurrentViewFromStack()
        }
    }
    
    /// Hide tab bar for detail views
    func hideTabBar() -> some View {
        self.onAppear {
            TabBarManager.shared.handleNavigationStateChange(to: .detailView)
        }
        .onDisappear {
            // Always remove from navigation stack first
            TabBarManager.shared.removeCurrentViewFromStack()
            
            // Check if we're returning to a main tab view
            if TabBarManager.shared.isCurrentViewMainTab() {
                TabBarManager.shared.restoreTabBarForMainTab()
            }
        }
    }
    
    /// Set tab bar visibility for modal views
    func setTabBarForModal(_ visible: Bool) -> some View {
        self.onAppear {
            TabBarManager.shared.setTabBarForModal(visible)
        }
        .onDisappear {
            // Always remove from navigation stack first
            TabBarManager.shared.removeCurrentViewFromStack()
            
            // When a modal disappears, restore the previous tab bar state
            if TabBarManager.shared.isCurrentViewMainTab() {
                TabBarManager.shared.restoreTabBarForMainTab()
            }
        }
    }
    
    /// Add padding for tab bar height
    func tabBarPadding() -> some View {
        self.padding(.bottom, TabBarManager.shared.getTabBarHeight())
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigationToDetailView = Notification.Name("NavigationToDetailView")
    static let navigationToMainTab = Notification.Name("NavigationToMainTab")
} 