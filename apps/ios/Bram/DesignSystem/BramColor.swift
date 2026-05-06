import SwiftUI

enum BramColor {
    static let appBackground = adaptive(
        light: RGB(244, 239, 231),
        dark: RGB(27, 27, 27)
    )
    static let deepBackground = adaptive(
        light: RGB(255, 252, 247),
        dark: RGB(15, 16, 18)
    )
    static let elevated = adaptive(
        light: RGB(255, 252, 247),
        dark: RGB(34, 35, 38)
    )
    static let cardSurface = adaptive(
        light: RGB(255, 255, 255),
        dark: RGB(39, 40, 43)
    )
    static let charcoal = Color(red: 0.106, green: 0.106, blue: 0.106)
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
        dark: RGB(136, 132, 124)
    )
    static let hairline = adaptive(
        light: RGB(35, 38, 44, alpha: 0.10),
        dark: RGB(255, 255, 255, alpha: 0.09)
    )
    static let violet = Color(red: 0.365, green: 0.353, blue: 0.969)
    static let violetDeep = Color(red: 0.278, green: 0.259, blue: 0.851)
    static let energy = Color(red: 0.906, green: 0.478, blue: 0.294)
    static let recovery = Color(red: 0.494, green: 0.592, blue: 0.494)
    static let warning = Color(red: 0.961, green: 0.706, blue: 0.263)
    static let cool = Color(red: 0.242, green: 0.565, blue: 0.965)
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
