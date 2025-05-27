import SwiftUI
import LocalAuthentication

struct FaceIDAuthView: View {
    @Binding var isAuthenticated: Bool
    @Binding var authError: String?
    @State private var isLoading = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Haptic feedback
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    // Check if running in simulator
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Face ID Icon
            Image(systemName: "faceid")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
                .accessibilityLabel("Face ID Icon")
            
            // Title
            Text(isSimulator ? "Authentication Required" : "Face ID Required")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            // Description
            Text(isSimulator ? 
                 "Please authenticate to access your secure data (Simulator Mode)" :
                 "Please authenticate to access your secure data")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Loading and Error States
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                } else if let error = authError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.title)
                        
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .font(.callout)
                        
                        Button(action: {
                            feedbackGenerator.prepare()
                            authenticate()
                        }) {
                            Label("Try Again", systemImage: "arrow.clockwise")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
                    )
                }
            }
            
            // Simulator-specific button
            if isSimulator {
                Button("Simulate Authentication") {
                    simulateAuthentication()
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            feedbackGenerator.prepare()
            if isSimulator {
                // In simulator, we'll show the simulate button instead of auto-authenticating
                authError = "Running in Simulator Mode"
            } else {
                authenticate()
            }
        }
    }
    
    private func simulateAuthentication() {
        isLoading = true
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            feedbackGenerator.notificationOccurred(.success)
            withAnimation {
                self.isAuthenticated = true
            }
        }
    }
    
    private func authenticate() {
        isLoading = true
        authError = nil
        
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            handleAuthenticationError(error)
            return
        }
        
        // Perform authentication
        let reason = "Authenticate to access your secure Social Brain data"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    feedbackGenerator.notificationOccurred(.success)
                    withAnimation {
                        self.isAuthenticated = true
                    }
                } else {
                    feedbackGenerator.notificationOccurred(.error)
                    handleAuthenticationError(error as NSError?)
                }
            }
        }
    }
    
    private func handleAuthenticationError(_ error: NSError?) {
        isLoading = false
        
        if isSimulator {
            authError = "Face ID is not available in Simulator. Use the 'Simulate Authentication' button."
            return
        }
        
        switch error?.code {
        case LAError.biometryNotAvailable.rawValue:
            authError = "Face ID is not available on this device."
        case LAError.biometryNotEnrolled.rawValue:
            authError = "Face ID is not set up on this device. Please set it up in Settings."
        case LAError.biometryLockout.rawValue:
            authError = "Face ID is locked. Please try again later or use your passcode."
        case LAError.userCancel.rawValue:
            authError = "Authentication was cancelled. Please try again."
        case LAError.authenticationFailed.rawValue:
            authError = "Authentication failed. Please try again."
        default:
            authError = error?.localizedDescription ?? "An unexpected error occurred. Please try again."
        }
    }
}

struct FaceIDAuthView_Previews: PreviewProvider {
    static var previews: some View {
        FaceIDAuthView(
            isAuthenticated: .constant(false),
            authError: .constant(nil)
        )
    }
} 