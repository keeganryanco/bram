import Foundation

struct DailyWorkoutNote: Identifiable, Hashable {
    let id: UUID
    var remoteId: UUID?
    var userId: UUID?
    var date: Date
    var timezoneIdentifier: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncState: WorkoutSyncState
    var lastSyncError: String?
    var interpretedLines: [InterpretedWorkoutLine]
    var parsedSummary: ParsedWorkoutSummary?
    var suggestion: WorkoutSuggestion?
    var metrics: WorkoutMetricSnapshot

    init(
        id: UUID = UUID(),
        remoteId: UUID? = nil,
        userId: UUID? = nil,
        date: Date = .now,
        timezoneIdentifier: String = TimeZone.current.identifier,
        body: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        syncState: WorkoutSyncState = .localOnly,
        lastSyncError: String? = nil,
        interpretedLines: [InterpretedWorkoutLine] = [],
        parsedSummary: ParsedWorkoutSummary? = nil,
        suggestion: WorkoutSuggestion? = nil,
        metrics: WorkoutMetricSnapshot = .empty
    ) {
        self.id = id
        self.remoteId = remoteId
        self.userId = userId
        self.date = date
        self.timezoneIdentifier = timezoneIdentifier
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.syncState = syncState
        self.lastSyncError = lastSyncError
        self.interpretedLines = interpretedLines
        self.parsedSummary = parsedSummary
        self.suggestion = suggestion
        self.metrics = metrics
    }
}

struct ParsedWorkoutSummary: Identifiable, Hashable {
    let id: UUID
    var title: String
    var exercises: [ParsedExerciseSummary]
    var unresolvedNote: String?

    init(
        id: UUID = UUID(),
        title: String,
        exercises: [ParsedExerciseSummary],
        unresolvedNote: String? = nil
    ) {
        self.id = id
        self.title = title
        self.exercises = exercises
        self.unresolvedNote = unresolvedNote
    }
}

struct ParsedExerciseSummary: Identifiable, Hashable {
    let id: UUID
    var name: String
    var setSummary: String
    var loadSummary: String

    init(id: UUID = UUID(), name: String, setSummary: String, loadSummary: String) {
        self.id = id
        self.name = name
        self.setSummary = setSummary
        self.loadSummary = loadSummary
    }
}

struct WorkoutMetricSnapshot: Hashable {
    var totalSets: Int
    var hardSets: Int
    var estimatedVolume: Int
    var prCount: Int
    var streakDays: Int
    var cardioMinutes: Int
    var activeEnergyCalories: Int?
    var energyIsEstimated: Bool
    var averageHeartRate: Int?
    var workoutDurationMinutes: Int?
    var parseState: WorkoutParseState

    static let empty = WorkoutMetricSnapshot(
        totalSets: 0,
        hardSets: 0,
        estimatedVolume: 0,
        prCount: 0,
        streakDays: 0,
        cardioMinutes: 0,
        activeEnergyCalories: nil,
        energyIsEstimated: false,
        averageHeartRate: nil,
        workoutDurationMinutes: nil,
        parseState: .empty
    )

    init(
        totalSets: Int,
        hardSets: Int = 0,
        estimatedVolume: Int,
        prCount: Int,
        streakDays: Int,
        cardioMinutes: Int = 0,
        activeEnergyCalories: Int? = nil,
        energyIsEstimated: Bool = false,
        averageHeartRate: Int? = nil,
        workoutDurationMinutes: Int? = nil,
        parseState: WorkoutParseState
    ) {
        self.totalSets = totalSets
        self.hardSets = hardSets
        self.estimatedVolume = estimatedVolume
        self.prCount = prCount
        self.streakDays = streakDays
        self.cardioMinutes = cardioMinutes
        self.activeEnergyCalories = activeEnergyCalories
        self.energyIsEstimated = energyIsEstimated
        self.averageHeartRate = averageHeartRate
        self.workoutDurationMinutes = workoutDurationMinutes
        self.parseState = parseState
    }
}

enum WorkoutParseState: String, Hashable {
    case empty = "Ready"
    case interpreting = "Reading"
    case parsed = "Tracked"
    case needsReview = "Review"
}

struct WorkoutSuggestion: Identifiable, Hashable {
    let id: UUID
    var kind: WorkoutSuggestionKind
    var text: String

    init(id: UUID = UUID(), kind: WorkoutSuggestionKind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}

enum WorkoutSuggestionKind: String, Hashable {
    case progression = "Progression"
    case recovery = "Recovery"
    case balance = "Balance"
    case reminder = "Reminder"
}
