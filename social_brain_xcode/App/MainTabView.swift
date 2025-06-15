import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 1 // Default to Social Contact (middle tab)
    @EnvironmentObject var appModeManager: AppModeManager
    @StateObject private var tabBarManager = TabBarManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SocialBrainView(
                sourceType: "general",
                sourceAction: "chat",
                sourceId: ""
            )
            .environmentObject(appModeManager)
            .environmentObject(tabBarManager)
            .showTabBar() // Always show tab bar for main tab views
            .tabItem {
                Label("人际大脑", systemImage: "sparkles")
            }
            .tag(0)
            
            SocialContactView()
                .environmentObject(tabBarManager)
                .showTabBar() // Always show tab bar for main tab views
                .tabItem {
                    Label("关系", systemImage: "person.2")
                }
                .tag(1)
            
            SocialNotesView()
                .environmentObject(tabBarManager)
                .showTabBar() // Always show tab bar for main tab views
                .tabItem {
                    Label("笔记", systemImage: "doc.text")
                }
                .tag(2)
        }
        .tint(.primaryText) // Use system black for selected tab
        .onAppear {
            // Set unselected tab color to system gray
            UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray
            
            // Initialize TabBarManager with the tab bar controller
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let tabBarController = window.rootViewController?.children.first(where: { $0 is UITabBarController }) as? UITabBarController {
                    tabBarManager.initialize(with: tabBarController)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Handle app returning from background - ensure proper tab bar state restoration
            DispatchQueue.main.async {
                tabBarManager.forceUpdateTabBarVisibility()
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppModeManager())
    }
} 