import Foundation

enum SuggestionSource: String, Codable, Hashable {
    case local
    case ai
}

enum SuggestionFeedbackAction: String, Codable, Hashable {
    case accepted
    case dismissed
    case thumbsUp
    case thumbsDown
    case modified
    case deleted
}

enum SuggestionDraftState: String, Codable, Hashable {
    case active
    case accepted
    case dismissed
    case thumbsUp
    case thumbsDown
    case modified
}

struct ExerciseSuggestion: Identifiable, Codable, Hashable {
    let id: UUID
    var exerciseKey: String
    var title: String
    var text: String
    var target: String?
    var source: SuggestionSource
    var evidence: [String]

    init(
        id: UUID = UUID(),
        exerciseKey: String,
        title: String = "Next time",
        text: String,
        target: String? = nil,
        source: SuggestionSource = .local,
        evidence: [String] = []
    ) {
        self.id = id
        self.exerciseKey = exerciseKey
        self.title = title
        self.text = text
        self.target = target
        self.source = source
        self.evidence = evidence
    }
}

struct SuggestionDraft: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var source: SuggestionSource
    var state: SuggestionDraftState
    var coarseContext: [String: String]

    init(
        id: UUID = UUID(),
        text: String,
        source: SuggestionSource = .local,
        state: SuggestionDraftState = .active,
        coarseContext: [String: String] = [:]
    ) {
        self.id = id
        self.text = text
        self.source = source
        self.state = state
        self.coarseContext = coarseContext
    }
}

struct SuggestionFeedback: Codable, Hashable {
    var installId: String
    var suggestionId: UUID
    var suggestionType: String
    var action: SuggestionFeedbackAction
    var source: SuggestionSource
    var coarseContext: [String: String]
}

enum WorkoutPatternConfidence: String, Codable, Hashable {
    case none
    case low
    case high
}

struct WorkoutPatternSummary: Codable, Hashable {
    var label: String
    var confidence: WorkoutPatternConfidence
    var workoutCount: Int
    var matchedMuscleGroup: String?
    var matchedExerciseKeys: [String]
    var evidence: [String]

    var isHighConfidence: Bool {
        confidence == .high && workoutCount >= 3
    }
}
