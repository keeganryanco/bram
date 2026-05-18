import SwiftUI

enum BramAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}
