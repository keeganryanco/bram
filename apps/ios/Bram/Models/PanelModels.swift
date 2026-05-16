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
    var macroSetVolumeByMuscle: [MuscleSetMetric] = []
    var bodyweightTrend: [BodyweightTrendPoint] = []
    var targetWeight: Double?
    var preferredWeightUnit: String = "lb"
    var prCount: Int = 0
    var recentPRLabels: [String] = []
    var priorWorkoutDaysInPeriod: Int = 0
    var setVolumeDelta: Int = 0
    var progressSignals: [ProgressSignal] = []
    var insight: StatsInsight?
    var currentStreak: Int
    var highestStreak: Int
    var streakTitle: String = "Build the week"
    var streakSubtitle: String = "Workout days count when a lift or cardio session is logged."
    var streakAwards: [StreakAward] = []
    var weeklyTarget: Int = 4
    var workoutDaysInPeriod: Int = 0
    var streakRepairCount: Int = 0
    var healthMetricsConnected: Bool
}

enum StatsPeriod: String, CaseIterable, Identifiable, Hashable {
    case week
    case month
    case year

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .week: "W"
        case .month: "M"
        case .year: "Y"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    var accessibilityPeriodName: String {
        switch self {
        case .week: "week"
        case .month: "month"
        case .year: "year"
        }
    }
}

struct DailyLoadMetric: Identifiable, Hashable {
    let id = UUID()
    var weekday: String
    var energyCalories: Int
    var energyIsEstimated: Bool = false
    var volume: Int
    var durationMinutes: Int?
    var averageHeartRate: Int?
    var muscleBreakdown: [MuscleSetMetric] = []

    init(
        weekday: String,
        energyCalories: Int? = nil,
        energyIsEstimated: Bool = false,
        volume: Int,
        durationMinutes: Int? = nil,
        averageHeartRate: Int? = nil,
        muscleBreakdown: [MuscleSetMetric] = []
    ) {
        self.weekday = weekday
        self.energyCalories = energyCalories ?? max(volume / 50, 0)
        self.energyIsEstimated = energyIsEstimated || energyCalories == nil
        self.volume = volume
        self.durationMinutes = durationMinutes
        self.averageHeartRate = averageHeartRate
        self.muscleBreakdown = muscleBreakdown
    }
}

struct MuscleSetMetric: Identifiable, Hashable {
    let id = UUID()
    var muscleGroup: String
    var sets: Int
    var colorRole: MetricColorRole
}

struct BodyweightTrendPoint: Identifiable, Hashable {
    let id = UUID()
    var date: Date
    var value: Double
    var source: BodyweightSource
}

struct ProgressSignal: Identifiable, Hashable {
    let id = UUID()
    var label: String
    var value: String
    var colorRole: MetricColorRole
}

struct StatsInsight: Identifiable, Hashable {
    let id = UUID()
    var kind: StatsInsightKind
    var text: String
    var colorRole: MetricColorRole
}

struct StreakAward: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var subtitle: String
    var systemImage: String
    var colorRole: MetricColorRole
    var isUnlocked: Bool
}

enum StatsInsightKind: String, Hashable {
    case progression = "Progression"
    case balance = "Balance"
    case consistency = "Consistency"
    case bodyweight = "Bodyweight"
}

enum MetricColorRole: String, Codable, Hashable {
    case violet
    case energy
    case recovery
    case cool
    case chest
    case back
    case legs
    case shoulders
    case abs
    case biceps
    case triceps
    case forearms
    case quads
    case hamstrings
    case glutes
    case calves
    case lats
    case traps
    case rhomboids
    case erectors
    case other
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
