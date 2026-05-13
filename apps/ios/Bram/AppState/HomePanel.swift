import Foundation

enum HomePanel: String, Identifiable {
    case calendar
    case dayStats
    case progress
    case premiumPrompt
    case settings
    case goals
    case health

    var id: String { rawValue }
}
