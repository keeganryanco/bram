import SwiftUI

enum OnboardingStyle {
    static let background = adaptive(
        light: RGB(244, 239, 231),
        dark: RGB(27, 27, 27)
    )
    static let deepSurface = adaptive(
        light: RGB(255, 252, 247),
        dark: RGB(15, 16, 18)
    )
    static let cardSurface = adaptive(
        light: RGB(255, 255, 255, alpha: 0.78),
        dark: RGB(255, 255, 255, alpha: 0.07)
    )
    static let cardSurfaceStrong = adaptive(
        light: RGB(255, 252, 247, alpha: 0.92),
        dark: RGB(255, 255, 255, alpha: 0.11)
    )
    static let fieldSurface = adaptive(
        light: RGB(255, 252, 247),
        dark: RGB(34, 35, 38)
    )
    static let textPrimary = adaptive(
        light: RGB(35, 38, 44),
        dark: RGB(247, 242, 234)
    )
    static let textSecondary = adaptive(
        light: RGB(68, 72, 82),
        dark: RGB(201, 196, 187)
    )
    static let textTertiary = adaptive(
        light: RGB(108, 112, 120),
        dark: RGB(156, 151, 143)
    )
    static let hairline = adaptive(
        light: RGB(35, 38, 44, alpha: 0.10),
        dark: RGB(255, 255, 255, alpha: 0.10)
    )
    static let fieldShadow = adaptive(
        light: RGB(35, 38, 44, alpha: 0.10),
        dark: RGB(0, 0, 0, alpha: 0.20)
    )
}

private struct RGB {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red / 255
        self.green = green / 255
        self.blue = blue / 255
        self.alpha = alpha
    }
}

private func adaptive(light: RGB, dark: RGB) -> Color {
    Color(
        UIColor { traits in
            let color = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: color.alpha
            )
        }
    )
}
