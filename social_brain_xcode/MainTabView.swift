import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 1 // Default to Social Notes (middle tab)
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SocialBrainView()
                .tabItem {
                    Label("Social Brain", systemImage: "brain")
                }
                .tag(0)
            
            SocialNotesView()
                .tabItem {
                    Label("Social Notes", systemImage: "note.text")
                }
                .tag(1)
            
            SocialNetworkView()
                .tabItem {
                    Label("Social Network", systemImage: "person.2")
                }
                .tag(2)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
} 