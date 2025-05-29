import SwiftUI
import LocalAuthentication
import os.log

struct FaceIDAuthView: View {
    @Binding var isAuthenticated: Bool
    @Binding var authError: String?
    @State private var isLoading = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Logger for critical errors only
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.socialbrain", category: "FaceIDAuth")
    
    // Haptic feedback
    @State private var feedbackGenerator: UINotificationFeedbackGenerator?
    
    // Check if running in simulator
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack {
                Spacer()
                // Divider with lock icon in the center
                ZStack {
                    // Horizontal line
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                        .padding(.horizontal)
                    // Lock icon in a circle
                    SwiftUI.Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .foregroundColor(Color(.label))
                        )
                        .shadow(color: Color(.black).opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .frame(height: 64)
                Spacer()
                // Face ID button at the bottom
                Button(action: {
                    feedbackGenerator?.prepare()
                    authenticate()
                }) {
                    Image(systemName: "faceid")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundColor(Color(.systemGray3))
                        .padding(24)
                        .background(
                            SwiftUI.Circle()
                                .fill(Color(.systemGray5).opacity(0.5))
                        )
                }
                .accessibilityLabel("Authenticate with Face ID")
                .padding(.bottom, 60)
                .opacity(isLoading ? 0.5 : 1)
                .disabled(isLoading)
            }
            // Error overlay
            if let error = authError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title)
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .font(.callout)
                    Button(action: {
                        feedbackGenerator?.prepare()
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
                .padding()
            }
            // Loading overlay
            if isLoading {
                Color.black.opacity(0.05).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            feedbackGenerator = UINotificationFeedbackGenerator()
            feedbackGenerator?.prepare()
            checkFaceIDAvailability()
            if isSimulator {
                authError = "Running in Simulator Mode"
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticate()
                }
            }
        }
    }
    
    private func checkFaceIDAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let biometryType = context.biometryType
            switch biometryType {
            case .faceID, .touchID:
                break
            case .none:
                logger.error("No biometric authentication available")
                authError = "No biometric authentication available on this device"
            @unknown default:
                logger.error("Unknown biometric type")
                authError = "Unknown biometric authentication type"
            }
        } else {
            if let error = error {
                handleAuthenticationError(error)
            }
        }
    }
    
    private func simulateAuthentication() {
        isLoading = true
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            feedbackGenerator?.notificationOccurred(.success)
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
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            handleAuthenticationError(error)
            return
        }
        
        // Get the type of biometric authentication available
        let biometryType = context.biometryType
        let authType = biometryType == .faceID ? "Face ID" : "Touch ID"
        
        // Perform authentication
        let reason = "Authenticate to access your secure Social Brain data"
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    self.feedbackGenerator?.notificationOccurred(.success)
                    withAnimation {
                        self.isAuthenticated = true
                    }
                } else {
                    self.feedbackGenerator?.notificationOccurred(.error)
                    self.handleAuthenticationError(error as NSError?)
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
        
        guard let error = error else {
            logger.error("Unknown authentication error")
            authError = "An unexpected error occurred. Please try again."
            return
        }
        
        logger.error("Authentication error code: \(error.code)")
        
        switch error.code {
        case LAError.biometryNotAvailable.rawValue:
            logger.error("Biometry not available")
            authError = "Face ID is not available on this device."
        case LAError.biometryNotEnrolled.rawValue:
            logger.error("Biometry not enrolled")
            authError = "Face ID is not set up on this device. Please set it up in Settings."
        case LAError.biometryLockout.rawValue:
            logger.error("Biometry locked out")
            authError = "Face ID is locked. Please try again later or use your passcode."
        case LAError.userCancel.rawValue:
            logger.error("User cancelled authentication")
            authError = "Authentication was cancelled. Please try again."
        case LAError.authenticationFailed.rawValue:
            logger.error("Authentication failed")
            authError = "Authentication failed. Please try again."
        case LAError.systemCancel.rawValue:
            logger.error("System cancelled authentication")
            authError = "Authentication was cancelled by the system. Please try again."
        case LAError.passcodeNotSet.rawValue:
            logger.error("Passcode not set")
            authError = "Please set up a passcode in Settings to use Face ID."
        case LAError.appCancel.rawValue:
            logger.error("App cancelled authentication")
            authError = "Authentication was cancelled by the app. Please try again."
        case LAError.invalidContext.rawValue:
            logger.error("Invalid context")
            authError = "Authentication context is invalid. Please restart the app."
        default:
            logger.error("Unexpected error: \(error.localizedDescription)")
            authError = error.localizedDescription
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