import SwiftUI
import UIKit

@MainActor
enum KeyboardSupport {
    static func dismissActiveInput() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct KeyboardDismissToolbar: ViewModifier {
    let dismiss: () -> Void

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘", action: dismiss)
            }
        }
    }
}

extension View {
    func keyboardDismissToolbar(dismiss: @escaping () -> Void) -> some View {
        modifier(KeyboardDismissToolbar(dismiss: dismiss))
    }
}
