import Foundation

struct BramBackendWorkoutSuggestionClient: WorkoutSuggestionBackendClient {
    enum ClientError: Error {
        case invalidResponse
        case requestFailed(Int)
    }

    private let baseURL: URL
    private let routeToken: String?
    private let session: URLSession

    init(baseURL: URL, routeToken: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.routeToken = routeToken?.nilIfBlank
        self.session = session
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> BramBackendWorkoutSuggestionClient? {
        guard bundle.object(forInfoDictionaryKey: "BramAIBackendEnabled") as? Bool == true,
              let urlString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let url = URL(string: urlString)
        else { return nil }

        return BramBackendWorkoutSuggestionClient(
            baseURL: url,
            routeToken: bundle.object(forInfoDictionaryKey: "BramAIDevRouteToken") as? String
        )
    }

    func suggestions(for context: WorkoutSuggestionRequestContext, accessToken: String? = nil) async throws -> WorkoutSuggestionResponse {
        var request = URLRequest(url: baseURL.appending(path: "/api/ai/suggestions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyRouteToken(to: &request)
        applySupabaseAccessToken(accessToken, to: &request)
        request.httpBody = try JSONEncoder().encode(BackendSuggestionRequest(context: context))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.requestFailed(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(BackendSuggestionResponse.self, from: data)
        return decoded.workoutSuggestionResponse
    }

    func sendFeedback(_ feedback: SuggestionFeedback, accessToken: String? = nil) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/ai/suggestion-feedback"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyRouteToken(to: &request)
        applySupabaseAccessToken(accessToken, to: &request)
        request.httpBody = try JSONEncoder().encode(BackendSuggestionFeedback(feedback: feedback))

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.requestFailed(httpResponse.statusCode)
        }
    }

    private func applyRouteToken(to request: inout URLRequest) {
        if let routeToken {
            request.setValue("Bearer \(routeToken)", forHTTPHeaderField: "Authorization")
        }
    }

    private func applySupabaseAccessToken(_ accessToken: String?, to request: inout URLRequest) {
        if let accessToken = accessToken?.nilIfBlank {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "X-Supabase-Access-Token")
        }
    }
}

private struct BackendSuggestionRequest: Encodable {
    var installId: String
    var currentWorkout: BackendCurrentWorkoutContext
    var exerciseHistorySummaries: [BackendExerciseHistorySummary]
    var cardioHistorySummaries: [BackendCardioHistorySummary]
    var dailyMetrics: BackendDailyMetrics
    var muscleVolume: [BackendMuscleVolume]
    var goals: BackendGoalsContext
    var noteHints: BackendNoteHints
    var workoutPattern: BackendWorkoutPattern?
    var feedbackSummary: [String: Int]

    init(context: WorkoutSuggestionRequestContext) {
        installId = context.installId
        currentWorkout = BackendCurrentWorkoutContext(context: context)
        exerciseHistorySummaries = context.exerciseSummaries.map(BackendExerciseHistorySummary.init)
        cardioHistorySummaries = context.cardioSummaries.map(BackendCardioHistorySummary.init)
        dailyMetrics = BackendDailyMetrics(context: context)
        muscleVolume = context.currentMuscleSets.map(BackendMuscleVolume.init)
        goals = BackendGoalsContext(context: context)
        noteHints = BackendNoteHints(context: context)
        workoutPattern = context.workoutPattern.map(BackendWorkoutPattern.init)
        feedbackSummary = context.recentFeedbackSummary
    }
}

private struct BackendCurrentWorkoutContext: Encodable {
    var sets: Int
    var prs: Int
    var cardioMinutes: Int
    var energyBucket: String
    var sessionKind: String
    var activeExerciseKey: String?
    var activeExerciseSetCount: Int
    var activeExerciseEffort: String

    init(context: WorkoutSuggestionRequestContext) {
        sets = context.metrics.totalSets
        prs = context.metrics.prCount
        cardioMinutes = context.metrics.cardioMinutes
        energyBucket = context.metrics.activeEnergyCalories.map { calories in
            switch calories {
            case 0..<200: "low"
            case 400...: "high"
            default: "moderate"
            }
        } ?? "unknown"
        sessionKind = context.sessionKind
        activeExerciseKey = context.activeExerciseKey
        activeExerciseSetCount = context.activeExerciseSetCount
        activeExerciseEffort = context.activeExerciseLatestEffort ?? "unknown"
    }
}

private struct BackendDailyMetrics: Encodable {
    var duration: String
    var heartRate: String

    init(context: WorkoutSuggestionRequestContext) {
        duration = context.metrics.workoutDurationMinutes.map(String.init) ?? "unknown"
        heartRate = context.metrics.averageHeartRate.map(String.init) ?? "unknown"
    }
}

private struct BackendGoalsContext: Encodable {
    var primaryGoal: String
    var weeklyTrainingDays: Int
    var sessionLengthMinutes: Int
    var trainingStyles: [String]
    var equipment: [String]

    init(context: WorkoutSuggestionRequestContext) {
        primaryGoal = context.goals.primaryGoal.rawValue
        weeklyTrainingDays = context.goals.weeklyTrainingDays
        sessionLengthMinutes = context.goals.sessionLengthMinutes
        trainingStyles = context.goals.trainingStyles.map(\.rawValue).sorted()
        equipment = context.goals.equipment.map(\.rawValue).sorted()
    }
}

private struct BackendNoteHints: Encodable {
    var readiness: String
    var equipment: String
    var constraint: String
    var cardioIntent: String
    var sessionKind: String

    init(context: WorkoutSuggestionRequestContext) {
        readiness = context.readinessHint ?? "unknown"
        equipment = context.equipmentHint ?? "unknown"
        constraint = context.constraintHint ?? "none"
        cardioIntent = context.cardioIntent ?? "none"
        sessionKind = context.sessionKind
    }
}

private struct BackendWorkoutPattern: Encodable {
    var label: String
    var confidence: String
    var workoutCount: Int
    var matchedMuscleGroup: String?
    var matchedExerciseKeys: [String]
    var evidence: [String]

    init(summary: WorkoutPatternSummary) {
        label = summary.label
        confidence = summary.confidence.rawValue
        workoutCount = summary.workoutCount
        matchedMuscleGroup = summary.matchedMuscleGroup
        matchedExerciseKeys = summary.matchedExerciseKeys
        evidence = summary.evidence
    }
}

private struct BackendExerciseHistorySummary: Encodable {
    var exerciseKey: String
    var displayName: String
    var bestSet: String?
    var estimatedOneRepMax: Int?
    var recentSessionCount: Int
    var recommendationEvidence: [String]
    var target: String?

    init(summary: ExerciseHistorySummary) {
        exerciseKey = summary.exerciseKey
        displayName = summary.displayName
        bestSet = summary.bestSetText
        estimatedOneRepMax = summary.estimatedOneRepMax.map { Int($0.rounded()) }
        recentSessionCount = summary.recentSessions.count
        recommendationEvidence = summary.primarySuggestion?.evidence ?? []
        target = summary.primarySuggestion?.target
    }
}

private struct BackendCardioHistorySummary: Encodable {
    var activityType: String
    var recentSessionCount: Int
    var averageDurationMinutes: Int?
    var bestDistance: String?
    var estimatedCalories: String
    var recommendation: String

    init(summary: CardioHistorySummary) {
        activityType = summary.activityType
        recentSessionCount = summary.recentSessions.count
        averageDurationMinutes = summary.averageDurationMinutes
        bestDistance = summary.bestDistanceText
        estimatedCalories = summary.estimatedCaloriesText
        recommendation = summary.recommendation
    }
}

private struct BackendMuscleVolume: Encodable {
    var muscleGroup: String
    var sets: Int

    init(metric: MuscleSetMetric) {
        muscleGroup = metric.muscleGroup
        sets = metric.sets
    }
}

private struct BackendSuggestionResponse: Decodable {
    var suggestions: BackendSuggestionPayload

    var workoutSuggestionResponse: WorkoutSuggestionResponse {
        WorkoutSuggestionResponse(
            dailySuggestion: suggestions.dailySuggestion?.workoutSuggestion,
            exerciseSuggestions: suggestions.exerciseSuggestions.map(\.exerciseSuggestion),
            draft: suggestions.draft?.suggestionDraft
        )
    }
}

private struct BackendSuggestionPayload: Decodable {
    var dailySuggestion: BackendDailySuggestion?
    var exerciseSuggestions: [BackendExerciseSuggestion]
    var draft: BackendSuggestionDraft?
}

private struct BackendDailySuggestion: Decodable {
    var type: String
    var text: String
    var affectedExerciseKey: String?
    var affectedCardioKey: String?

    var workoutSuggestion: WorkoutSuggestion {
        WorkoutSuggestion(
            kind: WorkoutSuggestionKind(rawValue: type.capitalized) ?? .reminder,
            text: text,
            affectedExerciseKey: affectedExerciseKey,
            affectedCardioKey: affectedCardioKey
        )
    }
}

private struct BackendExerciseSuggestion: Decodable {
    var exerciseKey: String
    var title: String
    var text: String
    var target: String?
    var evidence: [String]

    var exerciseSuggestion: ExerciseSuggestion {
        ExerciseSuggestion(
            exerciseKey: exerciseKey,
            title: title,
            text: text,
            target: target,
            source: .ai,
            evidence: evidence
        )
    }
}

private struct BackendSuggestionDraft: Decodable {
    var text: String
    var evidence: [String]

    var suggestionDraft: SuggestionDraft {
        SuggestionDraft(
            text: text,
            source: .ai,
            coarseContext: Dictionary(uniqueKeysWithValues: evidence.map { ($0, "true") })
        )
    }
}

private struct BackendSuggestionFeedback: Encodable {
    var installId: String
    var suggestionId: String
    var suggestionType: String
    var action: String
    var source: String
    var coarseContext: [String: String]

    init(feedback: SuggestionFeedback) {
        installId = feedback.installId
        suggestionId = feedback.suggestionId.uuidString
        suggestionType = feedback.suggestionType
        action = feedback.action.rawValue
        source = feedback.source.rawValue
        coarseContext = feedback.coarseContext
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
