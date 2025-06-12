import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 1 // Default to Social Contact (middle tab)
    @EnvironmentObject var appModeManager: AppModeManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SocialBrainView(
                sourceType: "general",
                sourceAction: "chat",
                sourceId: ""
            )
            .environmentObject(appModeManager)
            .tabItem {
                Label("人际大脑", systemImage: "sparkles")
            }
            .tag(0)
            
            SocialContactView()
                .tabItem {
                    Label("关系", systemImage: "person.2")
                }
                .tag(1)
            
            SocialNotesView()
                .tabItem {
                    Label("笔记", systemImage: "doc.text")
                }
                .tag(2)
        }
        .tint(.primaryText) // Use system black for selected tab
        .onAppear {
            // Set unselected tab color to system gray
            UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppModeManager())
    }
} 