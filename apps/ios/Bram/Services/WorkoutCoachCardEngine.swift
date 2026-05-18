import Foundation

enum WorkoutCoachCardEngine {
    static func cards(
        context: WorkoutSuggestionRequestContext,
        interpretedLines: [InterpretedWorkoutLine],
        phase: WorkoutCoachCardPhase
    ) -> [WorkoutCoachCard] {
        var cards: [WorkoutCoachCard] = []

        if let recovery = recoveryCard(context: context) {
            cards.append(recovery)
        }

        if let prCard = prCard(context: context, interpretedLines: interpretedLines) {
            cards.append(prCard)
        }

        if let progression = progressionCard(context: context) {
            cards.append(progression)
        }

        if let balance = balanceCard(context: context) {
            cards.append(balance)
        }

        if let cardio = cardioCard(context: context) {
            cards.append(cardio)
        }

        return deduplicated(cards)
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    lhs.title < rhs.title
                } else {
                    lhs.priority > rhs.priority
                }
            }
            .prefix(phase.maximumVisibleCards)
            .map { $0 }
    }

    static func cards(
        from response: WorkoutSuggestionResponse,
        context: WorkoutSuggestionRequestContext,
        phase: WorkoutCoachCardPhase
    ) -> [WorkoutCoachCard] {
        var cards: [WorkoutCoachCard] = []

        if let daily = response.dailySuggestion {
            cards.append(
                WorkoutCoachCard(
                    kind: WorkoutCoachCardKind(suggestionKind: daily.kind),
                    text: daily.text,
                    source: .ai,
                    priority: 92,
                    feedbackEligible: true,
                    coarseContext: coarseContext(context: context, evidence: ["ai_daily"])
                )
            )
        }

        cards.append(contentsOf: response.exerciseSuggestions.prefix(2).map { suggestion in
            WorkoutCoachCard(
                kind: .progression,
                title: suggestion.title,
                text: [suggestion.text, suggestion.target.map { "Aim for \($0)." }]
                    .compactMap { $0 }
                    .joined(separator: " "),
                source: .ai,
                priority: 86,
                feedbackEligible: true,
                affectedExerciseKey: suggestion.exerciseKey,
                coarseContext: coarseContext(context: context, evidence: suggestion.evidence)
            )
        })

        return deduplicated(cards)
            .sorted { $0.priority > $1.priority }
            .prefix(phase.maximumVisibleCards)
            .map { $0 }
    }

    private static func recoveryCard(context: WorkoutSuggestionRequestContext) -> WorkoutCoachCard? {
        guard context.readinessHint == "low" else { return nil }
        let text: String
        if let muscle = context.currentMuscleSets.first(where: { $0.sets >= 6 }) {
            text = "\(muscle.muscleGroup) already has \(muscle.sets) sets today. Keep the next work controlled and leave a rep or two in reserve."
        } else {
            text = "Keep today submaximal and leave one or two reps in reserve."
        }
        return WorkoutCoachCard(
            kind: .recovery,
            text: text,
            priority: 100,
            minimumVisibleSeconds: 10,
            feedbackEligible: true,
            coarseContext: coarseContext(context: context, evidence: ["readiness_low"])
        )
    }

    private static func prCard(
        context: WorkoutSuggestionRequestContext,
        interpretedLines: [InterpretedWorkoutLine]
    ) -> WorkoutCoachCard? {
        guard context.metrics.prCount > 0,
              let prLine = interpretedLines.first(where: { line in
                  line.chipText == "PR" || line.badges.contains { $0.kind == .pr }
              })
        else { return nil }

        let exerciseKey = prLine.exerciseAnchor?.exerciseKey
        let exerciseName = prLine.exerciseAnchor?.displayName
            ?? prLine.detailTitle.nilIfBlank
            ?? "This lift"
        let summary = exerciseKey.flatMap { key in
            context.exerciseSummaries.first { $0.exerciseKey == key }
        } ?? context.exerciseSummaries.first { $0.displayName.localizedCaseInsensitiveContains(exerciseName) }

        let hasSavedHistory = (summary?.recentSessions.count ?? 0) >= 2
        if !hasSavedHistory {
            return WorkoutCoachCard(
                kind: .baseline,
                title: "Baseline",
                text: "\(exerciseName) is saved as a starting point. Bram will compare the next sessions against this.",
                priority: 88,
                feedbackEligible: false,
                affectedExerciseKey: exerciseKey,
                coarseContext: coarseContext(context: context, evidence: ["first_recorded_exercise"])
            )
        }

        let bestSet = summary?.bestSetText.map { " Your best set is \($0)." } ?? ""
        return WorkoutCoachCard(
            kind: .progression,
            title: "Record",
            text: "\(exerciseName) moved up.\(bestSet) \(goalAdjustedPRAdvice(for: context.goals.primaryGoal))",
            priority: context.readinessHint == "low" ? 82 : 96,
            minimumVisibleSeconds: 10,
            feedbackEligible: true,
            affectedExerciseKey: exerciseKey,
            coarseContext: coarseContext(context: context, evidence: ["pr", "goal_\(context.goals.primaryGoal.rawValue)"])
        )
    }

    private static func progressionCard(context: WorkoutSuggestionRequestContext) -> WorkoutCoachCard? {
        guard let suggestion = context.exerciseSummaries
            .compactMap(\.primarySuggestion)
            .first(where: { suggestion in
                suggestion.evidence.contains("upward_trend")
                    || suggestion.evidence.contains("stalled_trend")
                    || suggestion.evidence.contains("saved_history")
            })
        else { return nil }

        let target = suggestion.target.map { " Aim for \($0)." } ?? ""
        let summary = context.exerciseSummaries.first { $0.exerciseKey == suggestion.exerciseKey }
        let title = summary?.displayName ?? suggestion.title
        return WorkoutCoachCard(
            kind: .progression,
            title: title,
            text: "\(suggestion.text)\(target)",
            priority: 84,
            feedbackEligible: true,
            affectedExerciseKey: suggestion.exerciseKey,
            coarseContext: coarseContext(context: context, evidence: suggestion.evidence)
        )
    }

    private static func balanceCard(context: WorkoutSuggestionRequestContext) -> WorkoutCoachCard? {
        if context.constraintHint == "time", context.metrics.totalSets > 0 {
            return WorkoutCoachCard(
                kind: .balance,
                text: "Since time is tight, keep one main movement and limit accessories to focused sets.",
                priority: 78,
                coarseContext: coarseContext(context: context, evidence: ["time_constraint"])
            )
        }

        guard let muscle = context.currentMuscleSets.first(where: { $0.sets >= 10 }) else { return nil }
        return WorkoutCoachCard(
            kind: .balance,
            text: "\(muscle.muscleGroup) is already at \(muscle.sets) sets today. Cap it with 2-3 clean sets if you add more.",
            priority: 76,
            feedbackEligible: true,
            coarseContext: coarseContext(context: context, evidence: ["high_volume"])
        )
    }

    private static func cardioCard(context: WorkoutSuggestionRequestContext) -> WorkoutCoachCard? {
        if let cardio = context.cardioSummaries.first,
           context.goals.primaryGoal == .betterCardio || context.metrics.cardioMinutes > 0 {
            return WorkoutCoachCard(
                kind: .progression,
                title: cardio.activityType,
                text: cardio.recommendation,
                priority: 72,
                coarseContext: coarseContext(context: context, evidence: ["cardio_history"])
            )
        }

        if context.goals.primaryGoal == .betterCardio, context.metrics.cardioMinutes == 0 {
            return WorkoutCoachCard(
                kind: .balance,
                text: "Add a short easy cardio finish if it fits your session.",
                priority: 70,
                coarseContext: coarseContext(context: context, evidence: ["cardio_goal"])
            )
        }

        return nil
    }

    private static func goalAdjustedPRAdvice(for goal: TrainingPrimaryGoal) -> String {
        switch goal {
        case .stronger:
            return "Next time, repeat the setup once before making another small jump."
        case .buildMuscle:
            return "Next time, keep the load steady and earn another clean rep before adding weight."
        case .leaner, .maintain:
            return "Next time, match it cleanly before chasing another jump."
        case .betterCardio, .healthyRoutine:
            return "Next time, keep the effort repeatable and protect the routine."
        }
    }

    private static func deduplicated(_ cards: [WorkoutCoachCard]) -> [WorkoutCoachCard] {
        var seen = Set<String>()
        return cards.filter { card in
            let key = "\(card.kind.rawValue)-\(card.affectedExerciseKey ?? card.text)"
            return seen.insert(key).inserted
        }
    }

    private static func coarseContext(
        context: WorkoutSuggestionRequestContext,
        evidence: [String]
    ) -> [String: String] {
        [
            "goal": context.goals.primaryGoal.rawValue,
            "sessionKind": context.sessionKind,
            "readiness": context.readinessHint ?? "unknown",
            "constraint": context.constraintHint ?? "none",
            "setBucket": setBucket(context.metrics.totalSets),
            "prBucket": context.metrics.prCount > 0 ? "has_pr" : "none",
            "evidence": evidence.prefix(3).joined(separator: ",")
        ]
    }

    private static func setBucket(_ sets: Int) -> String {
        switch sets {
        case 0: "0"
        case 1...3: "low"
        case 4...9: "moderate"
        default: "high"
        }
    }
}

private extension WorkoutCoachCardKind {
    init(suggestionKind: WorkoutSuggestionKind) {
        switch suggestionKind {
        case .progression:
            self = .progression
        case .recovery:
            self = .recovery
        case .balance:
            self = .balance
        case .reminder:
            self = .reminder
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
