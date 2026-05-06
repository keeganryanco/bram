import Foundation

enum BramPreviewData {
    static let populatedNote = DailyWorkoutNote(
        date: .now,
        body: """
        Push day.
        Bench 185 3x8, last set hard.
        Incline DB press 60s 3x10.
        Lateral raises 25s 4x12.
        Triceps pressdown 70 3x15.
        """,
        parsedSummary: ParsedWorkoutSummary(
            title: "Push day",
            exercises: [
                ParsedExerciseSummary(name: "Bench Press", setSummary: "3 x 8", loadSummary: "185 lb"),
                ParsedExerciseSummary(name: "Incline DB Press", setSummary: "3 x 10", loadSummary: "60 lb"),
                ParsedExerciseSummary(name: "Lateral Raise", setSummary: "4 x 12", loadSummary: "25 lb"),
                ParsedExerciseSummary(name: "Triceps Pressdown", setSummary: "3 x 15", loadSummary: "70 lb")
            ]
        ),
        suggestion: WorkoutSuggestion(
            kind: .progression,
            text: "Your pressing volume is steady; add one rep to the first bench set next time."
        ),
        metrics: WorkoutMetricSnapshot(
            totalSets: 13,
            estimatedVolume: 18_840,
            prCount: 1,
            streakDays: 4,
            parseState: .parsed
        )
    )

    static let emptyNote = DailyWorkoutNote(metrics: .empty)

    static let calendarDays: [CalendarWorkoutDay] = {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 3)) ?? .now
        return (0..<35).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let day = calendar.component(.day, from: date)
            return CalendarWorkoutDay(
                date: date,
                isSelected: day == 6,
                isToday: day == 6,
                hasWorkout: [3, 5, 6, 8, 10, 13, 15, 17, 20, 24, 28].contains(day),
                hadPR: [6, 17].contains(day)
            )
        }
    }()

    static let stats = StatsWeekSnapshot(
        dateRangeTitle: "May 3 - May 9",
        loadByDay: [
            DailyLoadMetric(weekday: "S", volume: 0),
            DailyLoadMetric(weekday: "M", volume: 14_200),
            DailyLoadMetric(weekday: "T", volume: 11_400),
            DailyLoadMetric(weekday: "W", volume: 18_840),
            DailyLoadMetric(weekday: "T", volume: 0),
            DailyLoadMetric(weekday: "F", volume: 16_100),
            DailyLoadMetric(weekday: "S", volume: 0)
        ],
        setVolumeByMuscle: [
            MuscleSetMetric(muscleGroup: "Chest", sets: 14, colorRole: .violet),
            MuscleSetMetric(muscleGroup: "Back", sets: 11, colorRole: .cool),
            MuscleSetMetric(muscleGroup: "Legs", sets: 10, colorRole: .energy),
            MuscleSetMetric(muscleGroup: "Recovery", sets: 2, colorRole: .recovery)
        ],
        currentStreak: 4,
        highestStreak: 9,
        healthMetricsConnected: false
    )

    static let account = SettingsAccountState(
        displayName: "Keegan Ryan",
        email: "keegan@trybram.app",
        accountTier: .freePremium,
        isDeveloper: true,
        founderOfferEligible: true,
        appleHealthConnected: false,
        appearance: "System",
        preferredUnits: "lb"
    )
}
