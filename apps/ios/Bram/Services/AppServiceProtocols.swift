import Foundation

protocol WorkoutLocalStore: Sendable {
    func note(for date: Date) async throws -> DailyWorkoutNote
    func trainingGoalsProfile() async throws -> TrainingGoalsProfile
    func healthDailyMetric(for date: Date) async throws -> HealthDailyMetric?
    func healthWorkoutSamples(on date: Date) async throws -> [HealthWorkoutSample]
    func healthWorkoutMatch(for noteId: UUID) async throws -> HealthWorkoutMatch?
    func calendarWorkoutDays() async throws -> [CalendarWorkoutDay]
    func statsWeek(containing date: Date) async throws -> StatsWeekSnapshot
    func stats(for period: StatsPeriod, containing date: Date) async throws -> StatsWeekSnapshot
    func exerciseHistory(for exercise: ExerciseAnchor) async throws -> ExerciseHistorySummary
    func cardioHistory(for activityType: String) async throws -> CardioHistorySummary
    func save(_ note: DailyWorkoutNote) async throws
    func save(_ profile: TrainingGoalsProfile) async throws
    func onboardingDraft() async throws -> OnboardingDraft
    func save(_ draft: OnboardingDraft) async throws
    func clearOnboardingDraft() async throws
    func save(_ metric: HealthDailyMetric) async throws
    func save(_ workouts: [HealthWorkoutSample]) async throws
    func save(_ match: HealthWorkoutMatch) async throws
    func delete(_ note: DailyWorkoutNote) async throws
    func pendingWorkoutSyncPayloads(limit: Int) async throws -> [WorkoutSyncPayload]
    func markWorkoutSynced(localNoteId: UUID, remoteId: UUID, userId: UUID) async throws
    func markWorkoutSyncFailed(localNoteId: UUID, errorMessage: String) async throws
}

struct WorkoutSyncPayload: Sendable {
    var note: DailyWorkoutNote
    var metrics: WorkoutMetricSnapshot?
    var strengthSets: [StrengthSetRecord]
    var cardioEntries: [CardioEntry]
    var prEvents: [WorkoutPREvent]
    var healthDailyMetric: HealthDailyMetric?
    var healthWorkoutMatch: HealthWorkoutMatch?
}

protocol WorkoutSyncService: Sendable {
    func syncPendingAccountData(userId: UUID) async throws
}

protocol WorkoutInterpretationService: Sendable {
    func interpret(note: DailyWorkoutNote) async -> WorkoutInterpretationResult
}

protocol ExerciseMatchingService: Sendable {
    func normalize(_ rawName: String) -> NormalizedExercise
}

protocol ExerciseHistoryProviding: Sendable {
    func history(for exerciseKey: String) async throws -> ExerciseHistorySummary
}

protocol PRDetectionService: Sendable {
    func detectPR(for exercise: NormalizedExercise, sets: [StrengthSetRecord]) -> PRDetectionResult
}

protocol WorkoutInterpretationBackendClient: Sendable {
    func interpret(note: DailyWorkoutNote) async throws -> WorkoutInterpretationResult
}

protocol WorkoutSuggestionBackendClient: Sendable {
    func suggestions(for context: WorkoutSuggestionRequestContext) async throws -> WorkoutSuggestionResponse
    func sendFeedback(_ feedback: SuggestionFeedback) async throws
}

protocol AppleHealthWorkoutMatchingService: Sendable {
    func matchHealthWorkout(to note: DailyWorkoutNote) async throws -> HealthWorkoutMatch?
}

protocol AccountStateProviding {
    func accountSnapshot() async throws -> AccountSnapshot
}

protocol EntitlementProviding {
    func featureAccess() async throws -> BramFeatureAccess
}

@MainActor
protocol BramPaywallServicing {
    func configure(userId: UUID) throws
    func loadPaywall() async throws -> BramPaywallSnapshot
    func purchase(packageId: String) async throws
    func restorePurchases() async throws
    func presentCodeRedemption()
}

protocol BramEntitlementRefreshing: Sendable {
    func refresh(accessToken: String) async throws -> AccountSnapshot
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

protocol HealthMetricsProviding {
    func weeklySnapshot() async throws -> StatsWeekSnapshot
    func dailyMetric(for date: Date) async throws -> HealthDailyMetric?
}

protocol AppleHealthProviding: Sendable {
    func authorizationState() -> HealthAuthorizationState
    func requestAuthorization() async throws -> HealthAuthorizationState
    func workouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutSample]
    func dailyMetrics(from startDate: Date, to endDate: Date) async throws -> [HealthDailyMetric]
    func matchWorkout(note: DailyWorkoutNote, workouts: [HealthWorkoutSample]) -> HealthWorkoutMatch?
    func refreshHealthData(for date: Date) async throws -> (dailyMetric: HealthDailyMetric?, workouts: [HealthWorkoutSample])
}

protocol AnimationAssetProviding {
    func mascotAssetName(for moment: MascotMoment) -> String?
}

struct AnalyticsEvent: Hashable {
    var name: String
    var properties: [String: String]
}

struct WorkoutInterpretationResult: Hashable {
    var lines: [InterpretedWorkoutLine]
    var metrics: WorkoutMetricSnapshot
    var suggestion: WorkoutSuggestion?
    var strengthSets: [StrengthSetRecord] = []
    var cardioEntries: [CardioEntry] = []
    var prEvents: [WorkoutPREvent] = []
}

struct WorkoutSuggestionRequestContext: Hashable {
    var installId: String
    var metrics: WorkoutMetricSnapshot
    var goals: TrainingGoalsProfile
    var currentMuscleSets: [MuscleSetMetric]
    var exerciseSummaries: [ExerciseHistorySummary]
    var cardioSummaries: [CardioHistorySummary]
    var readinessHint: String?
    var equipmentHint: String?
    var constraintHint: String?
    var cardioIntent: String?
    var sessionKind: String
    var recentFeedbackSummary: [String: Int]
}

struct WorkoutSuggestionResponse: Hashable {
    var dailySuggestion: WorkoutSuggestion?
    var exerciseSuggestions: [ExerciseSuggestion]
    var draft: SuggestionDraft?
}

enum MascotMoment: Hashable {
    case idle
    case streak
    case weeklyReview
}
