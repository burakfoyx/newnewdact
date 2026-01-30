import SwiftUI

// MARK: - Keyboard Dismissal Extension

extension View {
    /// Adds a tap gesture to dismiss the keyboard when tapping outside of text fields
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Hide Keyboard Function

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
