import SwiftUI

extension MetricColorRole {
    var color: Color {
        switch self {
        case .violet:
            BramColor.violet
        case .energy:
            BramColor.energy
        case .recovery:
            BramColor.recovery
        case .cool:
            BramColor.cool
        case .chest:
            BramColor.violet
        case .back:
            BramColor.cool
        case .legs:
            BramColor.energy
        case .shoulders:
            Color(red: 0.48, green: 0.43, blue: 0.94)
        case .abs:
            Color(red: 0.39, green: 0.58, blue: 0.43)
        case .biceps:
            Color(red: 0.47, green: 0.63, blue: 0.50)
        case .triceps:
            Color(red: 0.55, green: 0.67, blue: 0.55)
        case .forearms:
            Color(red: 0.64, green: 0.73, blue: 0.61)
        case .quads:
            Color(red: 0.93, green: 0.48, blue: 0.28)
        case .hamstrings:
            Color(red: 0.88, green: 0.40, blue: 0.24)
        case .glutes:
            Color(red: 0.80, green: 0.52, blue: 0.34)
        case .calves:
            Color(red: 0.95, green: 0.58, blue: 0.36)
        case .lats:
            Color(red: 0.28, green: 0.58, blue: 0.90)
        case .traps:
            Color(red: 0.34, green: 0.50, blue: 0.76)
        case .rhomboids:
            Color(red: 0.38, green: 0.62, blue: 0.82)
        case .erectors:
            Color(red: 0.32, green: 0.45, blue: 0.66)
        case .other:
            BramColor.textTertiary.opacity(0.72)
        }
    }
}
