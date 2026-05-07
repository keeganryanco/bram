import Foundation

enum HomePanel: String, Identifiable {
    case calendar
    case dayStats
    case progress
    case settings

    var id: String { rawValue }
}
