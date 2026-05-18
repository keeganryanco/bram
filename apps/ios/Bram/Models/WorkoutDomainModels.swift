import Foundation

enum WorkoutSyncState: String, Codable, Hashable {
    case localOnly = "LOCAL_ONLY"
    case pendingUpload = "PENDING_UPLOAD"
    case synced = "SYNCED"
    case failed = "FAILED"
    case deleted = "DELETED"
}

enum InterpretedWorkoutLineKind: String, Codable, Hashable {
    case strength
    case cardio
    case health
    case note
    case suggestion
    case reading
}

enum InterpretedLineSegmentKind: String, Codable, Hashable {
    case text
    case exerciseAnchor
    case badge
    case metric
}

struct InterpretedLineSegment: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: InterpretedLineSegmentKind
    var text: String
    var exerciseKey: String?

    init(id: UUID = UUID(), kind: InterpretedLineSegmentKind, text: String, exerciseKey: String? = nil) {
        self.id = id
        self.kind = kind
        self.text = text
        self.exerciseKey = exerciseKey
    }
}

struct InterpretedWorkoutLine: Identifiable, Codable, Hashable {
    let id: UUID
    var noteId: UUID
    var lineIndex: Int
    var rawText: String
    var kind: InterpretedWorkoutLineKind
    var segments: [InterpretedLineSegment]
    var exerciseAnchor: ExerciseAnchor?
    var cardioEntry: CardioEntry?
    var badges: [WorkoutLineBadge]
    var chipText: String
    var detailTitle: String
    var detailText: String
    var confidence: Double

    init(
        id: UUID = UUID(),
        noteId: UUID,
        lineIndex: Int,
        rawText: String,
        kind: InterpretedWorkoutLineKind,
        segments: [InterpretedLineSegment] = [],
        exerciseAnchor: ExerciseAnchor? = nil,
        cardioEntry: CardioEntry? = nil,
        badges: [WorkoutLineBadge] = [],
        chipText: String,
        detailTitle: String,
        detailText: String,
        confidence: Double
    ) {
        self.id = id
        self.noteId = noteId
        self.lineIndex = lineIndex
        self.rawText = rawText
        self.kind = kind
        self.segments = segments
        self.exerciseAnchor = exerciseAnchor
        self.cardioEntry = cardioEntry
        self.badges = badges
        self.chipText = chipText
        self.detailTitle = detailTitle
        self.detailText = detailText
        self.confidence = confidence
    }
}

struct NormalizedExercise: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var exerciseKey: String
    var canonicalName: String
    var muscleGroup: String?
}

struct ExerciseAlias: Identifiable, Codable, Hashable {
    let id: UUID
    var alias: String
    var exerciseKey: String
    var createdAt: Date
}

struct ExerciseAnchor: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var normalizedName: String
    var exerciseKey: String
    var history: ExerciseHistorySummary
    var groupMembers: [SupersetExerciseMember] = []

    var isSupersetGroup: Bool {
        !groupMembers.isEmpty
    }
}

struct SupersetExerciseMember: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var normalizedName: String
    var exerciseKey: String
    var history: ExerciseHistorySummary?
}

enum WorkoutLineBadgeKind: String, Codable, Hashable {
    case pr = "PR"
    case cardio = "CARDIO"
    case health = "HEALTH"
}

struct WorkoutLineBadge: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: WorkoutLineBadgeKind
    var label: String
    var colorRole: MetricColorRole

    init(id: UUID = UUID(), kind: WorkoutLineBadgeKind, label: String, colorRole: MetricColorRole) {
        self.id = id
        self.kind = kind
        self.label = label
        self.colorRole = colorRole
    }
}

struct StrengthEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var noteId: UUID
    var lineId: UUID?
    var exerciseName: String
    var sets: Int
    var reps: Int?
    var load: Double?
    var unit: String
    var effort: String?
    var muscleGroup: String?
}

struct StrengthSetRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var exerciseKey: String
    var exerciseName: String
    var lineIndex: Int?
    var setNumber: Int?
    var reps: Int
    var load: Double
    var unit: String
    var estimatedOneRepMax: Double
    var performedAt: Date
    var effort: String?

    init(
        id: UUID = UUID(),
        exerciseKey: String,
        exerciseName: String,
        lineIndex: Int? = nil,
        setNumber: Int? = nil,
        reps: Int,
        load: Double,
        unit: String = "lb",
        performedAt: Date = .now,
        effort: String? = nil
    ) {
        self.id = id
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.lineIndex = lineIndex
        self.setNumber = setNumber
        self.reps = reps
        self.load = load
        self.unit = unit
        self.estimatedOneRepMax = PRMath.epleyEstimatedOneRepMax(load: load, reps: reps)
        self.performedAt = performedAt
        self.effort = effort
    }
}

struct CardioEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var noteId: UUID
    var lineId: UUID?
    var lineIndex: Int?
    var sessionIndex: Int?
    var sessionName: String?
    var activityType: String
    var durationMinutes: Int?
    var distance: Double?
    var distanceUnit: String?
    var averageHeartRate: Int?
    var activeEnergyCalories: Int?

    init(
        id: UUID = UUID(),
        noteId: UUID,
        lineId: UUID? = nil,
        lineIndex: Int? = nil,
        sessionIndex: Int? = nil,
        sessionName: String? = nil,
        activityType: String,
        durationMinutes: Int? = nil,
        distance: Double? = nil,
        distanceUnit: String? = nil,
        averageHeartRate: Int? = nil,
        activeEnergyCalories: Int? = nil
    ) {
        self.id = id
        self.noteId = noteId
        self.lineId = lineId
        self.lineIndex = lineIndex
        self.sessionIndex = sessionIndex
        self.sessionName = sessionName
        self.activityType = activityType
        self.durationMinutes = durationMinutes
        self.distance = distance
        self.distanceUnit = distanceUnit
        self.averageHeartRate = averageHeartRate
        self.activeEnergyCalories = activeEnergyCalories
    }
}

struct CardioHistorySummary: Identifiable, Codable, Hashable {
    let id: UUID
    var activityType: String
    var recentSessions: [CardioHistorySession]
    var averageDurationMinutes: Int?
    var averagePaceText: String?
    var bestDistanceText: String?
    var estimatedCaloriesText: String
    var recommendation: String

    init(
        id: UUID = UUID(),
        activityType: String,
        recentSessions: [CardioHistorySession] = [],
        averageDurationMinutes: Int? = nil,
        averagePaceText: String? = nil,
        bestDistanceText: String? = nil,
        estimatedCaloriesText: String = "--",
        recommendation: String = "More saved sessions will make this more useful."
    ) {
        self.id = id
        self.activityType = activityType
        self.recentSessions = recentSessions
        self.averageDurationMinutes = averageDurationMinutes
        self.averagePaceText = averagePaceText
        self.bestDistanceText = bestDistanceText
        self.estimatedCaloriesText = estimatedCaloriesText
        self.recommendation = recommendation
    }

    static func placeholder(for entry: CardioEntry) -> CardioHistorySummary {
        let calories = entry.activeEnergyCalories.map { "\($0)" } ?? "--"
        return CardioHistorySummary(
            activityType: entry.activityType,
            recentSessions: [
                CardioHistorySession(
                    date: .now,
                    activityType: entry.activityType,
                    durationMinutes: entry.durationMinutes,
                    distance: entry.distance,
                    distanceUnit: entry.distanceUnit,
                    estimatedCalories: entry.activeEnergyCalories
                )
            ],
            averageDurationMinutes: entry.durationMinutes,
            averagePaceText: Self.paceText(durationMinutes: entry.durationMinutes, distance: entry.distance, unit: entry.distanceUnit),
            bestDistanceText: Self.distanceText(value: entry.distance, unit: entry.distanceUnit),
            estimatedCaloriesText: calories
        )
    }

    static func distanceText(value: Double?, unit: String?) -> String? {
        guard let value, let unit, value > 0 else { return nil }
        let amount = value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
        return "\(amount) \(unit)"
    }

    static func paceText(durationMinutes: Int?, distance: Double?, unit: String?) -> String? {
        guard let durationMinutes else { return nil }
        return paceText(durationMinutes: Double(durationMinutes), distance: distance, unit: unit)
    }

    static func paceText(durationMinutes: Double?, distance: Double?, unit: String?) -> String? {
        guard let durationMinutes, durationMinutes > 0,
              let distance, distance > 0,
              let unit
        else { return nil }
        let totalSeconds = Int((durationMinutes * 60 / distance).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))/\(unit)"
    }
}

struct CardioHistorySession: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var activityType: String
    var durationMinutes: Int?
    var distance: Double?
    var distanceUnit: String?
    var estimatedCalories: Int?
    var averageHeartRate: Int?
    var paceText: String {
        CardioHistorySummary.paceText(durationMinutes: durationMinutes, distance: distance, unit: distanceUnit) ?? "--"
    }

    init(
        id: UUID = UUID(),
        date: Date,
        activityType: String,
        durationMinutes: Int? = nil,
        distance: Double? = nil,
        distanceUnit: String? = nil,
        estimatedCalories: Int? = nil,
        averageHeartRate: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.activityType = activityType
        self.durationMinutes = durationMinutes
        self.distance = distance
        self.distanceUnit = distanceUnit
        self.estimatedCalories = estimatedCalories
        self.averageHeartRate = averageHeartRate
    }

    var durationText: String {
        guard let durationMinutes, durationMinutes > 0 else { return "--" }
        return "\(durationMinutes) min"
    }

    var distanceText: String {
        CardioHistorySummary.distanceText(value: distance, unit: distanceUnit) ?? "--"
    }

    var caloriesText: String {
        guard let estimatedCalories, estimatedCalories > 0 else { return "--" }
        return "\(estimatedCalories)"
    }
}

struct DailyWorkoutAggregate: Codable, Hashable {
    var totalSets: Int
    var hardSets: Int
    var estimatedVolume: Int
    var prCount: Int
    var cardioMinutes: Int
    var activeEnergyCalories: Int?
    var averageHeartRate: Int?
    var workoutDurationMinutes: Int?

    static let empty = DailyWorkoutAggregate(
        totalSets: 0,
        hardSets: 0,
        estimatedVolume: 0,
        prCount: 0,
        cardioMinutes: 0,
        activeEnergyCalories: nil,
        averageHeartRate: nil,
        workoutDurationMinutes: nil
    )
}

struct WorkoutPREvent: Identifiable, Codable, Hashable {
    let id: UUID
    var noteId: UUID
    var exerciseName: String
    var kind: String
    var value: Double
    var unit: String
    var achievedAt: Date
}

struct ExerciseHistorySession: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var bestSetText: String
    var estimatedOneRepMax: Double
    var volume: Int
    var effortText: String? = nil
}

struct ExerciseHistorySummary: Identifiable, Codable, Hashable {
    let id: UUID
    var exerciseKey: String
    var displayName: String
    var estimatedOneRepMax: Double?
    var bestSetText: String?
    var recentDates: [Date]
    var recentSessions: [ExerciseHistorySession]
    var recommendation: String
    var recentEffortText: String? = nil
    var primarySuggestion: ExerciseSuggestion? = nil

    static func placeholder(for exercise: NormalizedExercise, bestSet: StrengthSetRecord? = nil) -> ExerciseHistorySummary {
        let recentDates = [
            Calendar.current.date(byAdding: .day, value: -4, to: .now),
            Calendar.current.date(byAdding: .day, value: -11, to: .now),
            Calendar.current.date(byAdding: .day, value: -18, to: .now)
        ].compactMap { $0 }
        return ExerciseHistorySummary(
            id: UUID(),
            exerciseKey: exercise.exerciseKey,
            displayName: exercise.displayName,
            estimatedOneRepMax: bestSet?.estimatedOneRepMax,
            bestSetText: bestSet.map { "\(Int($0.load)) x \($0.reps)" },
            recentDates: recentDates,
            recentSessions: recentDates.enumerated().map { index, date in
                ExerciseHistorySession(
                    id: UUID(),
                    date: date,
                    bestSetText: bestSet.map { "\(Int($0.load) - index * 5) x \($0.reps)" } ?? "History pending",
                    estimatedOneRepMax: max((bestSet?.estimatedOneRepMax ?? 0) - Double(index * 4), 0),
                    volume: max((Int(bestSet?.load ?? 0) * max(bestSet?.reps ?? 0, 1)) - index * 80, 0),
                    effortText: bestSet?.effort
                )
            },
            recommendation: "Keep the next exposure steady, then add a rep or small load jump if the last set moves well.",
            recentEffortText: bestSet?.effort,
            primarySuggestion: ExerciseSuggestion(
                exerciseKey: exercise.exerciseKey,
                text: "Repeat the last clean setup, then add one rep before increasing weight.",
                target: bestSet.map { "\(Int($0.load)) x \($0.reps + 1)" },
                evidence: ["placeholder_history"]
            )
        )
    }

    static func supersetPlaceholder(members: [SupersetExerciseMember]) -> ExerciseHistorySummary {
        ExerciseHistorySummary(
            id: UUID(),
            exerciseKey: "superset_\(members.map(\.exerciseKey).joined(separator: "_"))",
            displayName: "Superset",
            estimatedOneRepMax: nil,
            bestSetText: nil,
            recentDates: [],
            recentSessions: [],
            recommendation: "Keep the pairing steady until both exercises are moving cleanly, then progress one side of the superset at a time.",
            primarySuggestion: ExerciseSuggestion(
                exerciseKey: "superset",
                title: "Superset",
                text: "Keep both movements clean before progressing one side of the pairing.",
                evidence: ["superset_group"]
            )
        )
    }
}

enum PRKind: String, Codable, Hashable {
    case estimatedOneRepMax
    case load
    case reps
}

struct PRDetectionResult: Codable, Hashable {
    var isPR: Bool
    var events: [WorkoutPREvent]
    var badge: WorkoutLineBadge?
    var bestSetId: UUID?
}

enum PRMath {
    static func epleyEstimatedOneRepMax(load: Double, reps: Int) -> Double {
        guard reps > 0 else { return load }
        return load * (1 + Double(reps) / 30)
    }
}

struct WorkoutSyncRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var entityName: String
    var entityLocalId: UUID
    var remoteId: UUID?
    var syncState: WorkoutSyncState
    var lastSyncedAt: Date?
    var lastError: String?
}
