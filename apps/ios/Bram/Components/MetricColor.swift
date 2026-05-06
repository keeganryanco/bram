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
        }
    }
}
