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
    func importSyncedWorkoutData(_ payloads: [WorkoutSyncPayload]) async throws
    func clearLocalAccountData() async throws
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
    func pullAccountData(userId: UUID) async throws
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
    func trackPaywallImpression()
    func purchase(packageId: String) async throws
    func restorePurchases() async throws
    func presentCodeRedemption()
}

protocol BramEntitlementRefreshing: Sendable {
    func refresh(accessToken: String) async throws -> AccountSnapshot
}

protocol BramPromoRedeeming: Sendable {
    func redeem(code: String, accessToken: String) async throws -> AccountSnapshot
}

protocol BramAccountDeleting: Sendable {
    func deleteAccount(accessToken: String) async throws
}

protocol BramPasswordResetting: Sendable {
    func sendResetEmail(email: String) async throws
}

protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent)
    func capture(error: Error, properties: [String: String])
    func identify(userId: UUID, properties: [String: String])
    func reset()
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

enum SupportCategory: String, CaseIterable, Identifiable, Sendable {
    case bug = "BUG"
    case account = "ACCOUNT"
    case billing = "BILLING"
    case workoutData = "WORKOUT_DATA"
    case feedback = "FEEDBACK"
    case other = "OTHER"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bug: "Bug"
        case .account: "Account"
        case .billing: "Billing"
        case .workoutData: "Workout data"
        case .feedback: "Feedback"
        case .other: "Other"
        }
    }
}

struct SupportRequestDraft: Hashable, Sendable {
    var category: SupportCategory
    var message: String
    var contactEmail: String?
    var includeDiagnostics: Bool
    var source: String?
}

enum AppErrorSeverity: String, Sendable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case fatal = "FATAL"
}

struct AppErrorReport: Hashable, Sendable {
    var severity: AppErrorSeverity
    var source: String
    var eventName: String
    var message: String?
    var errorCode: String?
    var metadata: [String: String]
}

protocol SupportRequestSubmitting: Sendable {
    func submit(_ draft: SupportRequestDraft, accessToken: String) async throws
}

protocol AppErrorReporting: Sendable {
    func report(_ report: AppErrorReport, accessToken: String) async throws
}

protocol WorkoutReminderScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func scheduleReminder(after note: DailyWorkoutNote, goals: TrainingGoalsProfile) async
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
