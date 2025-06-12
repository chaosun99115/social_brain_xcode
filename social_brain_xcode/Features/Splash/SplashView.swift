import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var opacity = 1.0
    @StateObject private var appModeManager = AppModeManager()
    
    var body: some View {
        ZStack {
            // Background color matching launch screen
            Color.white
                .ignoresSafeArea()
            
            // Image that fills the entire screen
            Image("l")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .opacity(opacity)
        }
        .onAppear {
            // Start fade out animation after 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0.0
                }
            }
            
            // Navigate to main app after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isActive = true
            }
        }
        .fullScreenCover(isPresented: $isActive) {
            MainTabView()
                .environmentObject(appModeManager)
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
} 