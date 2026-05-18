import Foundation

enum WorkoutCoachCardKind: String, Hashable {
    case progression = "Progression"
    case recovery = "Recovery"
    case balance = "Balance"
    case reminder = "Reminder"
    case baseline = "Baseline"
}

struct WorkoutCoachCard: Identifiable, Hashable {
    let id: UUID
    var kind: WorkoutCoachCardKind
    var title: String
    var metadata: String?
    var text: String
    var source: SuggestionSource
    var priority: Int
    var minimumVisibleSeconds: TimeInterval
    var feedbackEligible: Bool
    var affectedExerciseKey: String?
    var coarseContext: [String: String]

    init(
        id: UUID = UUID(),
        kind: WorkoutCoachCardKind,
        title: String? = nil,
        metadata: String? = nil,
        text: String,
        source: SuggestionSource = .local,
        priority: Int,
        minimumVisibleSeconds: TimeInterval = 8,
        feedbackEligible: Bool = false,
        affectedExerciseKey: String? = nil,
        coarseContext: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.title = title ?? kind.rawValue
        self.metadata = metadata
        self.text = text
        self.source = source
        self.priority = priority
        self.minimumVisibleSeconds = minimumVisibleSeconds
        self.feedbackEligible = feedbackEligible
        self.affectedExerciseKey = affectedExerciseKey
        self.coarseContext = coarseContext
    }
}

enum WorkoutCoachCardPhase: Hashable {
    case typing
    case saved
    case wrapUp

    var maximumVisibleCards: Int {
        switch self {
        case .typing:
            1
        case .saved:
            2
        case .wrapUp:
            3
        }
    }
}

enum WorkoutCoachCardDisplayPolicy {
    static func remainingVisibleTime(
        current: WorkoutCoachCard,
        shownAt: Date,
        now: Date = Date()
    ) -> TimeInterval {
        max(0, current.minimumVisibleSeconds - now.timeIntervalSince(shownAt))
    }
}
