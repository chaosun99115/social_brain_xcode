import UIKit

extension UIApplication {
    /// Dismisses the keyboard by resigning the first responder
    public func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
} 