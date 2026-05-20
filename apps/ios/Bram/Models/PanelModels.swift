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
    var launchChallenge: LaunchChallengeProgress = .make(qualifyingWorkoutDays: 0)
    var healthMetricsConnected: Bool
}

enum LaunchChallengeState: String, Hashable {
    case hidden
    case announced
    case active
    case completed
    case ended
}

struct LaunchChallengeProgress: Hashable {
    static let eventKey = "founding_lifters_week_2026"
    static let title = "Founding Lifters Week"
    static let badgeTitle = "Founding Lifters"
    static let goalWorkoutDays = 4

    var eventKey: String = Self.eventKey
    var title: String = Self.title
    var badgeTitle: String = Self.badgeTitle
    var shortDescription: String = "Log 4 workouts and start your first strength history."
    var progressCount: Int
    var goalCount: Int = Self.goalWorkoutDays
    var state: LaunchChallengeState
    var announcementDate: Date
    var startDate: Date
    var endDate: Date

    var isVisible: Bool {
        state != .hidden
    }

    var isEarned: Bool {
        progressCount >= goalCount
    }

    var clampedProgress: Int {
        min(progressCount, goalCount)
    }

    var progressText: String {
        "\(clampedProgress)/\(goalCount) workouts"
    }

    var stateLabel: String {
        switch state {
        case .hidden:
            "Launch challenge"
        case .announced:
            "Starts May 26"
        case .active:
            isEarned ? "Badge earned" : "Live now"
        case .completed:
            "Badge earned"
        case .ended:
            isEarned ? "Badge earned" : "Ended"
        }
    }

    var subtitle: String {
        switch state {
        case .hidden:
            shortDescription
        case .announced:
            "Starts May 26. Log four workouts by June 2 to earn the limited badge."
        case .active:
            isEarned ? "Limited badge unlocked." : "Log \(max(goalCount - clampedProgress, 0)) more by June 2 to earn the limited badge."
        case .completed:
            "Limited badge unlocked."
        case .ended:
            isEarned ? "Limited badge unlocked." : "This launch challenge has ended."
        }
    }

    static func make(
        qualifyingWorkoutDays: Int,
        asOf date: Date = Date(),
        calendar inputCalendar: Calendar = .current
    ) -> LaunchChallengeProgress {
        var calendar = inputCalendar
        calendar.timeZone = .current
        let announcement = eventDate(year: 2026, month: 5, day: 22, calendar: calendar)
        let start = eventDate(year: 2026, month: 5, day: 26, calendar: calendar)
        let end = eventDate(year: 2026, month: 6, day: 2, calendar: calendar)
        let today = calendar.startOfDay(for: date)
        let earned = qualifyingWorkoutDays >= goalWorkoutDays
        let state: LaunchChallengeState
        if today < announcement {
            state = .hidden
        } else if earned {
            state = .completed
        } else if today < start {
            state = .announced
        } else if today <= end {
            state = .active
        } else {
            state = .ended
        }
        return LaunchChallengeProgress(
            progressCount: qualifyingWorkoutDays,
            state: state,
            announcementDate: announcement,
            startDate: start,
            endDate: end
        )
    }

    private static func eventDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }
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

    var hasHealthBackedEnergy: Bool {
        energyCalories > 0 && !energyIsEstimated
    }

    var hasHealthDuration: Bool {
        (durationMinutes ?? 0) > 0
    }

    var hasHealthHeartRate: Bool {
        (averageHeartRate ?? 0) > 0
    }

    var energyUnitLabel: String {
        energyIsEstimated ? "est. cal" : "Health cal"
    }

    var energyAccessibilityLabel: String {
        energyIsEstimated ? "\(energyCalories) estimated calories" : "\(energyCalories) calories from Apple Health"
    }

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

struct AppleHealthProgressPresentation: Hashable {
    var title: String
    var subtitle: String
    var systemImage: String
    var isConnectedLike: Bool
    var showsCharts: Bool

    static func make(state: HealthAuthorizationState, stats: StatsWeekSnapshot) -> AppleHealthProgressPresentation {
        let hasHealthData = stats.hasHealthChartData || stats.hasAppleHealthBodyweight
        if state.isConnectedLike {
            return AppleHealthProgressPresentation(
                title: "Apple Health",
                subtitle: hasHealthData ? "Health-backed context is improving progress." : "Connected. No Health data found for this range yet.",
                systemImage: "heart.fill",
                isConnectedLike: true,
                showsCharts: hasHealthData
            )
        }

        switch state {
        case .accessNeedsReview, .error:
            return AppleHealthProgressPresentation(
                title: "Apple Health",
                subtitle: "Check Bram in iOS Health data access, then refresh.",
                systemImage: "heart",
                isConnectedLike: false,
                showsCharts: false
            )
        case .unavailable:
            return AppleHealthProgressPresentation(
                title: "Apple Health",
                subtitle: "HealthKit needs a supported iPhone.",
                systemImage: "heart",
                isConnectedLike: false,
                showsCharts: false
            )
        case .notRequested:
            fallthrough
        case .requested, .connected, .connectedNoRecentData:
            return AppleHealthProgressPresentation(
                title: "Connect Apple Health",
                subtitle: "Energy, heart rate, duration, and bodyweight can improve progress.",
                systemImage: "heart",
                isConnectedLike: false,
                showsCharts: false
            )
        }
    }
}

extension StatsWeekSnapshot {
    var hasAppleHealthBodyweight: Bool {
        bodyweightTrend.contains { $0.source == .appleHealth }
    }

    var hasHealthChartData: Bool {
        loadByDay.contains { $0.hasHealthDuration || $0.hasHealthHeartRate }
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
    case effort = "Effort"
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
    var activePromoKind: String?
    var activePromoLabel: String?
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

    var hasVisiblePaywallPromo: Bool {
        founderOfferEligible || activePromoKind != nil
    }

    var paywallPromoLabel: String {
        activePromoLabel ?? (founderOfferEligible ? "Founder month" : "Promo")
    }

    var usesReviewTestingPaywall: Bool {
        isDeveloper && email.caseInsensitiveCompare("review@trybram.app") == .orderedSame
    }
}
