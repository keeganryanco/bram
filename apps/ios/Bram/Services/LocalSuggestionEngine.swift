import Foundation

enum LocalSuggestionEngine {
    static func dailySuggestion(context: WorkoutSuggestionRequestContext) -> WorkoutSuggestion? {
        if context.readinessHint == "low" {
            if let muscle = context.currentMuscleSets.first(where: { $0.sets >= 8 }) {
                return WorkoutSuggestion(
                    kind: .recovery,
                    text: "\(muscle.muscleGroup) is already at \(muscle.sets) sets today; keep the next work controlled."
                )
            }
            return WorkoutSuggestion(kind: .recovery, text: "Keep today submaximal and leave one or two reps in reserve.")
        }

        if let progression = bestProgressionSuggestion(from: context.exerciseSummaries) {
            return progression
        }

        if let muscle = context.currentMuscleSets.first(where: { $0.sets >= 10 }) {
            return WorkoutSuggestion(
                kind: .balance,
                text: "\(muscle.muscleGroup) is already at \(muscle.sets) sets today; cap it with 2-3 clean sets if you add more."
            )
        }

        if context.constraintHint == "time", context.metrics.totalSets > 0 {
            return WorkoutSuggestion(
                kind: .balance,
                text: "Since time is tight, keep one main movement and limit accessories to focused sets."
            )
        }

        if let cardio = context.cardioSummaries.first,
           context.goals.primaryGoal == .betterCardio || context.metrics.cardioMinutes > 0 {
            return WorkoutSuggestion(
                kind: .progression,
                text: cardio.recommendation
            )
        }

        if context.goals.primaryGoal == .betterCardio, context.metrics.cardioMinutes == 0 {
            return WorkoutSuggestion(kind: .balance, text: "Add a short easy cardio finish if it fits your session.")
        }

        return nil
    }

    static func exerciseSuggestion(
        exerciseKey: String,
        sessions: [ExerciseHistorySession],
        goals: TrainingGoalsProfile = TrainingGoalsProfile(),
        currentMuscleSets: Int = 0
    ) -> ExerciseSuggestion {
        let ordered = sessions.sorted { $0.date > $1.date }
        let evidence = evidenceLabels(sessions: ordered, goals: goals, currentMuscleSets: currentMuscleSets)

        guard let latest = ordered.first else {
            return ExerciseSuggestion(
                exerciseKey: exerciseKey,
                text: baselineText(for: goals),
                target: "2-3 clean sets",
                evidence: evidence
            )
        }

        let isBodyweight = latest.bestSetText.hasPrefix("BW") || latest.estimatedOneRepMax <= 0
        if currentMuscleSets >= 10 {
            return ExerciseSuggestion(
                exerciseKey: exerciseKey,
                title: "Volume",
                text: "Stop at 2-3 clean sets today; this muscle already has enough work.",
                target: "2-3 sets",
                evidence: evidence + ["high_current_volume"]
            )
        }

        guard ordered.count >= 2 else {
            if isBodyweight {
                return ExerciseSuggestion(
                    exerciseKey: exerciseKey,
                    text: "Repeat this movement and try to beat your best set by one clean rep.",
                    target: nextBodyweightTarget(from: latest.bestSetText),
                    evidence: evidence + ["thin_history"]
                )
            }
            return ExerciseSuggestion(
                exerciseKey: exerciseKey,
                text: "Repeat the same load and add one rep before increasing weight.",
                target: nextLoadedTarget(from: latest.bestSetText, addLoad: false),
                evidence: evidence + ["thin_history"]
            )
        }

        let previous = ordered[1]
        let improving = latest.estimatedOneRepMax > previous.estimatedOneRepMax
        if isBodyweight {
            return ExerciseSuggestion(
                exerciseKey: exerciseKey,
                title: improving ? "Progress" : "Control",
                text: improving
                    ? "Keep the same setup and add one clean rep if it is there."
                    : "Match your best reps before adding another set or harder variation.",
                target: nextBodyweightTarget(from: latest.bestSetText),
                evidence: evidence + [improving ? "upward_trend" : "stalled_trend"]
            )
        }

        if improving {
            return ExerciseSuggestion(
                exerciseKey: exerciseKey,
                title: "Progress",
                text: "If the top set moves well, make a small load jump or add one rep.",
                target: nextLoadedTarget(from: latest.bestSetText, addLoad: true),
                evidence: evidence + ["upward_trend"]
            )
        }

        return ExerciseSuggestion(
            exerciseKey: exerciseKey,
            title: "Steady",
            text: "Keep the same load and try to match or add one rep before pushing weight again.",
            target: nextLoadedTarget(from: latest.bestSetText, addLoad: false),
            evidence: evidence + ["stalled_trend"]
        )
    }

    static func draft(
        for note: DailyWorkoutNote,
        goals: TrainingGoalsProfile,
        feedbackPenalty: Bool = false,
        enabled: Bool = false
    ) -> SuggestionDraft? {
        guard enabled else { return nil }
        let body = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.count > 40,
              !body.localizedCaseInsensitiveContains("Bram:"),
              !feedbackPenalty
        else { return nil }

        let hints = NoteSuggestionHints(body: body)
        guard hints.hasStrongContext else { return nil }

        let text: String
        if hints.readiness == "low" {
            text = "Bram: Keep the next exercise to 2-3 clean sets and stop before form slips."
        } else if hints.constraint == "time" {
            text = "Bram: Pick the next main lift and keep accessories to 2 focused sets."
        } else if hints.readiness == "high" {
            text = "Bram: If the top set moves well, add one rep before increasing weight."
        } else if note.metrics.totalSets >= 12 {
            text = "Bram: Volume is already high today, so keep the next movement controlled."
        } else {
            text = "Bram: Aim for steady working sets before chasing more load today."
        }

        return SuggestionDraft(
            text: text,
            coarseContext: [
                "readiness": hints.readiness ?? "unknown",
                "constraint": hints.constraint ?? "none",
                "equipment": hints.equipment ?? "unknown",
                "goal": goals.primaryGoal.rawValue,
                "setBucket": setBucket(note.metrics.totalSets)
            ]
        )
    }

    static func dailySuggestion(
        metrics: WorkoutMetricSnapshot,
        goals: TrainingGoalsProfile,
        hints: NoteSuggestionHints
    ) -> WorkoutSuggestion? {
        if hints.readiness == "low" {
            return WorkoutSuggestion(kind: .recovery, text: "Keep today submaximal and leave one or two reps in reserve.")
        }

        if metrics.prCount > 0 {
            return nil
        }

        if metrics.totalSets >= 14 {
            return WorkoutSuggestion(kind: .balance, text: "Volume is high today, so the rest of the session should favor clean reps over more work.")
        }

        if goals.primaryGoal == .betterCardio, metrics.cardioMinutes == 0 {
            return WorkoutSuggestion(kind: .balance, text: "Add a short easy cardio finish if it fits your session.")
        }

        return nil
    }

    private static func bestProgressionSuggestion(from summaries: [ExerciseHistorySummary]) -> WorkoutSuggestion? {
        for summary in summaries {
            guard summary.recentSessions.count >= 2,
                  let suggestion = summary.primarySuggestion,
                  suggestion.evidence.contains("upward_trend") || suggestion.evidence.contains("stalled_trend") || suggestion.evidence.contains("saved_history")
            else { continue }

            let target = suggestion.target.map { " Aim for \($0)." } ?? ""
            return WorkoutSuggestion(
                kind: .progression,
                text: "\(summary.displayName): \(suggestion.text)\(target)"
            )
        }
        return nil
    }

    private static func baselineText(for goals: TrainingGoalsProfile) -> String {
        switch goals.primaryGoal {
        case .stronger:
            "Start with 2-3 clean working sets and keep one rep in reserve."
        case .buildMuscle:
            "Start with 3 controlled sets and focus on clean reps before adding load."
        case .leaner, .betterCardio, .healthyRoutine, .maintain:
            "Start with 2-3 steady sets and keep the effort repeatable."
        }
    }

    private static func nextLoadedTarget(from bestSetText: String, addLoad: Bool) -> String? {
        let parts = bestSetText.split(separator: "x").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2,
              let load = Double(parts[0]),
              let reps = Int(parts[1])
        else { return nil }

        if addLoad {
            return "\(Int((load + 5).rounded())) x \(max(reps - 1, 3))-\(reps)"
        }
        return "\(Int(load.rounded())) x \(reps + 1)"
    }

    private static func nextBodyweightTarget(from bestSetText: String) -> String? {
        guard let repsText = bestSetText.split(separator: "x").last?.trimmingCharacters(in: .whitespacesAndNewlines),
              let reps = Int(repsText)
        else { return "add 1 clean rep" }
        return "\(reps + 1) clean reps"
    }

    private static func evidenceLabels(
        sessions: [ExerciseHistorySession],
        goals: TrainingGoalsProfile,
        currentMuscleSets: Int
    ) -> [String] {
        var labels = ["goal_\(goals.primaryGoal.rawValue)"]
        labels.append(sessions.count < 2 ? "thin_history" : "saved_history")
        labels.append("current_sets_\(setBucket(currentMuscleSets))")
        return labels
    }

    private static func setBucket(_ sets: Int) -> String {
        switch sets {
        case 0...3: "low"
        case 4...9: "moderate"
        default: "high"
        }
    }
}

struct NoteSuggestionHints: Hashable {
    var readiness: String?
    var equipment: String?
    var constraint: String?
    var cardioIntent: String?

    init(body: String) {
        let lower = body.lowercased()
        if lower.contains("tired") || lower.contains("sore") || lower.contains("low energy") || lower.contains("beat up") {
            readiness = "low"
        } else if lower.contains("strong") || lower.contains("good") || lower.contains("great") {
            readiness = "high"
        }

        if lower.contains("short on time") || lower.contains("rushed") || lower.contains("limited time") {
            constraint = "time"
        }

        if lower.contains("run") || lower.contains("jog") || lower.contains("bike") || lower.contains("cycle") || lower.contains("walk") || lower.contains("mile") || lower.contains("5k") {
            cardioIntent = "cardio_logged"
        }

        if lower.contains("dumbbell") || lower.contains("db") {
            equipment = "dumbbells"
        } else if lower.contains("cable") {
            equipment = "cables"
        } else if lower.contains("machine") {
            equipment = "machines"
        } else if lower.contains("band") {
            equipment = "bands"
        } else if lower.contains("home") || lower.contains("bodyweight") {
            equipment = "bodyweight"
        } else if lower.contains("gym") {
            equipment = "gym"
        }
    }

    var hasStrongContext: Bool {
        readiness != nil || equipment != nil || constraint != nil || cardioIntent != nil
    }
}
