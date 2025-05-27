import SwiftUI
import LocalAuthentication

struct FaceIDAuthView: View {
    @Binding var isAuthenticated: Bool
    @Binding var authError: String?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "faceid")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            Text("Face ID Required")
                .font(.title2)
                .fontWeight(.semibold)
            if isLoading {
                ProgressView()
            }
            if let error = authError {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    authenticate()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
        .onAppear {
            authenticate()
        }
    }
    
    private func authenticate() {
        isLoading = true
        authError = nil
        let context = LAContext()
        var error: NSError?
        let reason = "Authenticate to access Social Brain."
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    isLoading = false
                    if success {
                        self.isAuthenticated = true
                    } else {
                        self.authError = authError?.localizedDescription ?? "Face ID authentication failed."
                    }
                }
            }
        } else {
            isLoading = false
            authError = error?.localizedDescription ?? "Face ID not available on this device."
        }
    }
} 