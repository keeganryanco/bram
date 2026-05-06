import Foundation

enum HomePanel: String, Identifiable {
    case calendar
    case stats
    case settings

    var id: String { rawValue }
}
