import Foundation

struct CalendarWorkoutDay: Identifiable, Hashable {
    let id: Date
    var date: Date
    var isSelected: Bool
    var isToday: Bool
    var hasWorkout: Bool
    var hadPR: Bool

    init(date: Date, isSelected: Bool = false, isToday: Bool = false, hasWorkout: Bool = false, hadPR: Bool = false) {
        self.id = date
        self.date = date
        self.isSelected = isSelected
        self.isToday = isToday
        self.hasWorkout = hasWorkout
        self.hadPR = hadPR
    }
}

struct StatsWeekSnapshot: Hashable {
    var dateRangeTitle: String
    var loadByDay: [DailyLoadMetric]
    var setVolumeByMuscle: [MuscleSetMetric]
    var currentStreak: Int
    var highestStreak: Int
    var healthMetricsConnected: Bool
}

struct DailyLoadMetric: Identifiable, Hashable {
    let id = UUID()
    var weekday: String
    var volume: Int
}

struct MuscleSetMetric: Identifiable, Hashable {
    let id = UUID()
    var muscleGroup: String
    var sets: Int
    var colorRole: MetricColorRole
}

enum MetricColorRole: Hashable {
    case violet
    case energy
    case recovery
    case cool
}

struct SettingsAccountState: Hashable {
    var displayName: String
    var email: String
    var accountTier: BramAccountTier
    var isDeveloper: Bool
    var founderOfferEligible: Bool
    var appleHealthConnected: Bool
    var appearance: String
    var preferredUnits: String

    var subscriptionLabel: String {
        switch accountTier {
        case .free:
            "No Subscription Active"
        case .premium:
            "Premium Active"
        case .freePremium:
            "Lifetime Premium"
        }
    }
}
