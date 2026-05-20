import Foundation

enum BramPreviewData {
    static let populatedNote = DailyWorkoutNote(
        date: .now,
        body: """
        Push day.
        Bench 185 3x8, last set hard.
        Incline DB press 60s 3x10.
        Lateral raises 25s 4x12.
        Bike 12 min.
        Triceps pressdown 70 3x15.
        """,
        interpretedLines: {
            let bench = NormalizedExercise(
                id: UUID(),
                displayName: "Bench",
                exerciseKey: "bench_press",
                canonicalName: "Bench Press",
                muscleGroup: "Chest"
            )
            let bike = NormalizedExercise(
                id: UUID(),
                displayName: "Bike",
                exerciseKey: "bike",
                canonicalName: "Bike",
                muscleGroup: nil
            )
            let benchSet = StrengthSetRecord(
                exerciseKey: "bench_press",
                exerciseName: "Bench",
                reps: 8,
                load: 185
            )
            return [
            InterpretedWorkoutLine(
                noteId: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                lineIndex: 1,
                rawText: "Bench 185 3x8, last set hard.",
                kind: .strength,
                segments: [
                    InterpretedLineSegment(kind: .exerciseAnchor, text: "Bench", exerciseKey: "bench_press"),
                    InterpretedLineSegment(kind: .metric, text: "3 x 8 @ 185"),
                    InterpretedLineSegment(kind: .badge, text: "PR", exerciseKey: "bench_press")
                ],
                exerciseAnchor: ExerciseAnchor(
                    id: UUID(),
                    displayName: bench.displayName,
                    normalizedName: bench.canonicalName,
                    exerciseKey: bench.exerciseKey,
                    history: .placeholder(for: bench, bestSet: benchSet)
                ),
                badges: [WorkoutLineBadge(kind: .pr, label: "PR", colorRole: .violet)],
                chipText: "PR",
                detailTitle: "Bench Press",
                detailText: "Bram read this as 3 sets of 8 at about 185 lb.",
                confidence: 0.84
            ),
            InterpretedWorkoutLine(
                noteId: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                lineIndex: 4,
                rawText: "Bike 12 min.",
                kind: .cardio,
                segments: [
                    InterpretedLineSegment(kind: .text, text: bike.displayName),
                    InterpretedLineSegment(kind: .metric, text: "12 min")
                ],
                chipText: "12 min",
                detailTitle: "Cardio",
                detailText: "Bram recognized this as 12 minutes of bike work.",
                confidence: 0.78
            )
            ]
        }(),
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
            hardSets: 1,
            estimatedVolume: 18_840,
            prCount: 1,
            streakDays: 4,
            cardioMinutes: 12,
            activeEnergyCalories: 380,
            averageHeartRate: 142,
            workoutDurationMinutes: 58,
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
            DailyLoadMetric(weekday: "M", energyCalories: 320, energyIsEstimated: true, volume: 14_200, durationMinutes: 52, muscleBreakdown: [
                MuscleSetMetric(muscleGroup: "Chest", sets: 8, colorRole: .chest),
                MuscleSetMetric(muscleGroup: "Back", sets: 4, colorRole: .back)
            ]),
            DailyLoadMetric(weekday: "T", energyCalories: 280, energyIsEstimated: true, volume: 11_400, durationMinutes: 44, muscleBreakdown: [
                MuscleSetMetric(muscleGroup: "Legs", sets: 10, colorRole: .legs)
            ]),
            DailyLoadMetric(weekday: "W", energyCalories: 380, volume: 18_840, durationMinutes: 58, averageHeartRate: 142, muscleBreakdown: [
                MuscleSetMetric(muscleGroup: "Chest", sets: 6, colorRole: .chest),
                MuscleSetMetric(muscleGroup: "Triceps", sets: 5, colorRole: .triceps)
            ]),
            DailyLoadMetric(weekday: "T", volume: 0),
            DailyLoadMetric(weekday: "F", energyCalories: 350, energyIsEstimated: true, volume: 16_100, durationMinutes: 55, muscleBreakdown: [
                MuscleSetMetric(muscleGroup: "Back", sets: 7, colorRole: .back),
                MuscleSetMetric(muscleGroup: "Abs", sets: 3, colorRole: .abs)
            ]),
            DailyLoadMetric(weekday: "S", volume: 0)
        ],
        setVolumeByMuscle: [
            MuscleSetMetric(muscleGroup: "Chest", sets: 14, colorRole: .chest),
            MuscleSetMetric(muscleGroup: "Back", sets: 11, colorRole: .back),
            MuscleSetMetric(muscleGroup: "Quads", sets: 6, colorRole: .quads),
            MuscleSetMetric(muscleGroup: "Hamstrings", sets: 4, colorRole: .hamstrings),
            MuscleSetMetric(muscleGroup: "Triceps", sets: 5, colorRole: .triceps),
            MuscleSetMetric(muscleGroup: "Biceps", sets: 3, colorRole: .biceps),
            MuscleSetMetric(muscleGroup: "Abs", sets: 3, colorRole: .abs)
        ],
        macroSetVolumeByMuscle: [
            MuscleSetMetric(muscleGroup: "Chest", sets: 14, colorRole: .chest),
            MuscleSetMetric(muscleGroup: "Back", sets: 11, colorRole: .back),
            MuscleSetMetric(muscleGroup: "Legs", sets: 10, colorRole: .legs),
            MuscleSetMetric(muscleGroup: "Arms", sets: 8, colorRole: .biceps),
            MuscleSetMetric(muscleGroup: "Abs", sets: 3, colorRole: .abs)
        ],
        bodyweightTrend: [
            BodyweightTrendPoint(date: Calendar.current.date(byAdding: .day, value: -18, to: .now) ?? .now, value: 194.2, source: .manual),
            BodyweightTrendPoint(date: Calendar.current.date(byAdding: .day, value: -11, to: .now) ?? .now, value: 193.1, source: .note),
            BodyweightTrendPoint(date: Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now, value: 192.4, source: .appleHealth)
        ],
        targetWeight: 185,
        preferredWeightUnit: "lb",
        prCount: 3,
        recentPRLabels: ["Bench Press", "Incline DB Press", "Triceps Pressdown"],
        priorWorkoutDaysInPeriod: 3,
        setVolumeDelta: 6,
        progressSignals: [
            ProgressSignal(label: "PRs", value: "3", colorRole: .violet),
            ProgressSignal(label: "Workouts", value: "4/4", colorRole: .recovery),
            ProgressSignal(label: "Chest", value: "+2 sets", colorRole: .chest)
        ],
        insight: StatsInsight(
            kind: .progression,
            text: "Bench Press and 2 more moved up this period; keep chest volume steady next week.",
            colorRole: .violet
        ),
        currentStreak: 4,
        highestStreak: 9,
        weeklyTarget: 4,
        workoutDaysInPeriod: 4,
        streakRepairCount: 1,
        healthMetricsConnected: true
    )

    static let account = SettingsAccountState(
        userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
        displayName: "Keegan Ryan",
        email: "keegan@trybram.app",
        accountTier: .freePremium,
        isDeveloper: true,
        founderOfferEligible: true,
        activePromoKind: "FRIENDS_DISCOUNT",
        activePromoLabel: "Friends access",
        appleHealthConnected: false,
        appearance: "System",
        preferredUnits: "lb"
    )

    static let goalsProfile = TrainingGoalsProfile(
        primaryGoal: .buildMuscle,
        weeklyTrainingDays: 4,
        sessionLengthMinutes: 60,
        trainingStyles: [.gym],
        equipment: [.fullGym, .dumbbells, .barbell, .machines, .cables],
        heightValue: 72,
        currentWeightValue: 192,
        targetWeightValue: 185,
        sex: .male,
        preferredUnits: .imperial,
        estimatedDailyCalories: 2_800
    )
}
