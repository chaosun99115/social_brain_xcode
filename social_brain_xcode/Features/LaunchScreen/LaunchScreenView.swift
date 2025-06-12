import SwiftUI

struct LaunchScreenView: View {
    @State private var opacity: Double = 1.0 // Start fully visible
    @State private var showLoadingIndicator = false
    
    var body: some View {
        ZStack {
            // Background color (in case image has transparency)
            Color(LaunchScreenConfiguration.backgroundColor)
                .ignoresSafeArea()
            
            // Launch screen image fills the entire screen, stretching to match storyboard's scaleToFill
            Image("l")
                .resizable(resizingMode: .stretch)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .opacity(opacity)
            
            // Overlay for custom content if needed
            VStack {
                Spacer()
                
                // Custom text if configured
                if let customText = LaunchScreenConfiguration.customText {
                    Text(customText)
                        .font(.system(size: LaunchScreenConfiguration.textFont.pointSize, weight: .medium))
                        .foregroundColor(Color(LaunchScreenConfiguration.textColor))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 50)
                        .opacity(opacity)
                }
                
                // Loading indicator if enabled
                if LaunchScreenConfiguration.showLoadingIndicator && showLoadingIndicator {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                        .padding(.bottom, 50)
                        .opacity(opacity)
                }
            }
        }
        .onAppear {
            // No fade-in animation! Start fully visible.
            // Only show loading indicator if needed
            if LaunchScreenConfiguration.showLoadingIndicator {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showLoadingIndicator = true
                    }
                }
            }
        }
    }
    
    /// Start fade out animation
    func startFadeOut() {
        withAnimation(.easeOut(duration: LaunchScreenConfiguration.fadeOutDuration)) {
            opacity = 0.0
        }
    }
}

struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView()
    }
} 