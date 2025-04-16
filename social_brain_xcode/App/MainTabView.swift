import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 1 // Default to Social Notes (middle tab)
    @EnvironmentObject var localizationManager: LocalizationManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SocialBrainView()
                .tabItem {
                    Label("Relate AI", systemImage: "sparkles")
                }
                .tag(0)
            
            SocialNotesView()
                .tabItem {
                    Label("笔记", systemImage: "doc.text")
                }
                .tag(1)
            
            SocialContactView()
                .tabItem {
                    Label("联系人", systemImage: "person.2")
                }
                .tag(2)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(LocalizationManager())
    }
} 
