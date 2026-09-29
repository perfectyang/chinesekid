import SwiftUI

enum KidsTheme {
    static let ink = Color(red: 0.16, green: 0.21, blue: 0.31)
    static let muted = Color(red: 0.39, green: 0.45, blue: 0.56)
    static let paper = Color(red: 1.00, green: 0.98, blue: 0.93)
    static let orange = Color(red: 1.00, green: 0.49, blue: 0.31)
    static let yellow = Color(red: 1.00, green: 0.79, blue: 0.30)
    static let mint = Color(red: 0.48, green: 0.80, blue: 0.68)
    static let lilac = Color(red: 0.70, green: 0.62, blue: 0.90)
    static let blue = Color(red: 0.43, green: 0.68, blue: 0.91)
    static let peach = Color(red: 1.00, green: 0.78, blue: 0.68)
    static let red = Color(red: 0.81, green: 0.27, blue: 0.29)
}

/// A quiet storybook backdrop: warm paper with a few soft color islands.
struct StorybookBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                KidsTheme.paper
                Circle()
                    .fill(KidsTheme.yellow.opacity(0.17))
                    .frame(width: 250, height: 250)
                    .position(x: proxy.size.width - 16, y: 22)
                Circle()
                    .fill(KidsTheme.mint.opacity(0.13))
                    .frame(width: 220, height: 220)
                    .position(x: 8, y: proxy.size.height * 0.63)
                Circle()
                    .fill(KidsTheme.lilac.opacity(0.12))
                    .frame(width: 180, height: 180)
                    .position(x: proxy.size.width - 8, y: proxy.size.height * 0.94)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
