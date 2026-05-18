import Foundation

enum SuggestionContextBuilder {
    static func build(
        installId: String = "local-install",
        note: DailyWorkoutNote,
        result: WorkoutInterpretationResult,
        goals: TrainingGoalsProfile,
        store: any WorkoutLocalStore,
        recentFeedbackSummary: [String: Int] = [:]
    ) async -> WorkoutSuggestionRequestContext {
        let hints = NoteSuggestionHints(body: note.body)
        let currentMuscleSets = muscleSetMetrics(from: result.strengthSets)
        let currentExerciseSetCounts = Dictionary(grouping: result.strengthSets, by: \.exerciseKey)
            .mapValues(\.count)
        let exerciseSummaries = await exerciseSummaries(from: result.strengthSets, store: store, currentMuscleSets: currentMuscleSets)
        let cardioSummaries = await cardioSummaries(from: result.cardioEntries, store: store)

        return WorkoutSuggestionRequestContext(
            installId: installId,
            metrics: result.metrics,
            goals: goals,
            currentMuscleSets: currentMuscleSets,
            currentExerciseSetCounts: currentExerciseSetCounts,
            exerciseSummaries: exerciseSummaries,
            cardioSummaries: cardioSummaries,
            readinessHint: hints.readiness,
            equipmentHint: hints.equipment,
            constraintHint: hints.constraint,
            cardioIntent: hints.cardioIntent,
            sessionKind: sessionKind(result: result),
            recentFeedbackSummary: recentFeedbackSummary
        )
    }

    private static func exerciseSummaries(
        from sets: [StrengthSetRecord],
        store: any WorkoutLocalStore,
        currentMuscleSets: [MuscleSetMetric]
    ) async -> [ExerciseHistorySummary] {
        let currentSetsByMuscle = Dictionary(uniqueKeysWithValues: currentMuscleSets.map { ($0.muscleGroup, $0.sets) })
        let bestSets = Dictionary(grouping: sets, by: \.exerciseKey)
            .compactMapValues { sets in sets.max { $0.estimatedOneRepMax < $1.estimatedOneRepMax } }
            .values
            .sorted { $0.estimatedOneRepMax > $1.estimatedOneRepMax }
            .prefix(6)

        var summaries: [ExerciseHistorySummary] = []
        for set in bestSets {
            let anchor = ExerciseAnchor(
                id: UUID(),
                displayName: set.exerciseName,
                normalizedName: set.exerciseName,
                exerciseKey: set.exerciseKey,
                history: .placeholder(
                    for: NormalizedExercise(
                        id: UUID(),
                        displayName: set.exerciseName,
                        exerciseKey: set.exerciseKey,
                        canonicalName: set.exerciseName,
                        muscleGroup: muscleGroup(for: set.exerciseKey)
                    ),
                    bestSet: set
                )
            )

            let history = (try? await store.exerciseHistory(for: anchor)) ?? anchor.history
            let muscleSets = muscleGroup(for: set.exerciseKey).flatMap { currentSetsByMuscle[$0] } ?? 0
            var enriched = history
            enriched.primarySuggestion = LocalSuggestionEngine.exerciseSuggestion(
                exerciseKey: set.exerciseKey,
                sessions: history.recentSessions,
                currentMuscleSets: muscleSets
            )
            summaries.append(enriched)
        }
        return summaries
    }

    private static func cardioSummaries(
        from entries: [CardioEntry],
        store: any WorkoutLocalStore
    ) async -> [CardioHistorySummary] {
        var seen = Set<String>()
        var summaries: [CardioHistorySummary] = []
        for entry in entries where seen.insert(entry.activityType.lowercased()).inserted {
            summaries.append((try? await store.cardioHistory(for: entry.activityType)) ?? .placeholder(for: entry))
        }
        return summaries
    }

    private static func muscleSetMetrics(from sets: [StrengthSetRecord]) -> [MuscleSetMetric] {
        let counts = sets.reduce(into: [String: Int]()) { result, set in
            guard let muscle = muscleGroup(for: set.exerciseKey) else { return }
            result[muscle, default: 0] += 1
        }

        return counts
            .sorted { $0.value > $1.value }
            .map { muscle, sets in
                MuscleSetMetric(muscleGroup: muscle, sets: sets, colorRole: colorRole(for: muscle))
            }
    }

    private static func sessionKind(result: WorkoutInterpretationResult) -> String {
        if !result.cardioEntries.isEmpty && !result.strengthSets.isEmpty { return "mixed" }
        if !result.cardioEntries.isEmpty { return "cardio" }
        if !result.strengthSets.isEmpty { return "strength" }
        return "unknown"
    }

    private static func colorRole(for muscle: String) -> MetricColorRole {
        switch muscle.lowercased() {
        case "chest": .chest
        case "legs": .legs
        case "back": .back
        case "shoulders": .shoulders
        case "abs": .abs
        case "biceps": .biceps
        case "triceps": .triceps
        case "forearms": .forearms
        case "other": .other
        default: .violet
        }
    }

    private static func muscleGroup(for exerciseKey: String) -> String? {
        if exerciseKey.contains("crunch") || exerciseKey.contains("ab") || exerciseKey.contains("plank") || exerciseKey.contains("sit_up") || exerciseKey.contains("leg_raise") { return "Abs" }
        if exerciseKey.contains("squat") || exerciseKey.contains("leg") || exerciseKey.contains("deadlift") || exerciseKey.contains("rdl") || exerciseKey.contains("nordic") || exerciseKey.contains("calf") { return "Legs" }
        if exerciseKey.contains("forearm") || exerciseKey.contains("wrist") || exerciseKey.contains("grip") { return "Forearms" }
        if exerciseKey.contains("tricep") || exerciseKey.contains("triceps") || exerciseKey.contains("dip") || exerciseKey.contains("pushdown") { return "Triceps" }
        if exerciseKey.contains("curl") || exerciseKey.contains("preacher") || exerciseKey.contains("bicep") || exerciseKey.contains("biceps") { return "Biceps" }
        if exerciseKey.contains("delt") || exerciseKey.contains("lateral_raise") || exerciseKey.contains("shoulder") { return "Shoulders" }
        if exerciseKey.contains("bench") || exerciseKey.contains("chest") || exerciseKey.contains("fly") || exerciseKey.contains("press") { return "Chest" }
        if exerciseKey.contains("row") || exerciseKey.contains("pulldown") || exerciseKey.contains("pullover") || exerciseKey.contains("lat") { return "Back" }
        return nil
    }
}
