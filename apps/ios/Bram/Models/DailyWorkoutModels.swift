import Foundation

struct DailyWorkoutNote: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var body: String
    var parsedSummary: ParsedWorkoutSummary?
    var suggestion: WorkoutSuggestion?
    var metrics: WorkoutMetricSnapshot

    init(
        id: UUID = UUID(),
        date: Date = .now,
        body: String = "",
        parsedSummary: ParsedWorkoutSummary? = nil,
        suggestion: WorkoutSuggestion? = nil,
        metrics: WorkoutMetricSnapshot = .empty
    ) {
        self.id = id
        self.date = date
        self.body = body
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
    var estimatedVolume: Int
    var prCount: Int
    var streakDays: Int
    var parseState: WorkoutParseState

    static let empty = WorkoutMetricSnapshot(
        totalSets: 0,
        estimatedVolume: 0,
        prCount: 0,
        streakDays: 0,
        parseState: .empty
    )
}

enum WorkoutParseState: String, Hashable {
    case empty = "Ready"
    case interpreting = "Reading"
    case parsed = "Parsed"
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
