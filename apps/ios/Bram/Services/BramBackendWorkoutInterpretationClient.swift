import Foundation

struct BramBackendWorkoutInterpretationClient: WorkoutInterpretationBackendClient {
    enum ClientError: Error {
        case notConfigured
        case invalidResponse
        case requestFailed(Int)
    }

    private let baseURL: URL
    private let routeToken: String?
    private let session: URLSession
    private let exerciseMatcher: any ExerciseMatchingService

    init(
        baseURL: URL,
        routeToken: String? = nil,
        session: URLSession = .shared,
        exerciseMatcher: any ExerciseMatchingService = DefaultExerciseMatchingService()
    ) {
        self.baseURL = baseURL
        self.routeToken = routeToken?.nilIfBlank
        self.session = session
        self.exerciseMatcher = exerciseMatcher
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> BramBackendWorkoutInterpretationClient? {
        guard bundle.object(forInfoDictionaryKey: "BramAIBackendEnabled") as? Bool == true,
              let urlString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let url = URL(string: urlString)
        else { return nil }

        return BramBackendWorkoutInterpretationClient(
            baseURL: url,
            routeToken: bundle.object(forInfoDictionaryKey: "BramAIDevRouteToken") as? String
        )
    }

    func interpret(note: DailyWorkoutNote) async throws -> WorkoutInterpretationResult {
        var request = URLRequest(url: baseURL.appending(path: "/api/ai/interpret-workout"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let routeToken {
            request.setValue("Bearer \(routeToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder.bramBackend.encode(
            BackendInterpretationRequest(
                noteText: note.body,
                userId: note.userId?.uuidString,
                workoutDate: Self.workoutDateString(note.date),
                timezone: note.timezoneIdentifier
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.requestFailed(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder.bramBackend.decode(
            BackendInterpretationResponse.self,
            from: data
        )
        return decoded.parsedWorkout.toWorkoutInterpretationResult(
            note: note,
            exerciseMatcher: exerciseMatcher
        )
    }

    private static func workoutDateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}

private struct BackendInterpretationRequest: Encodable {
    var noteText: String
    var userId: String?
    var workoutDate: String
    var timezone: String
}

private struct BackendInterpretationResponse: Decodable {
    var parsedWorkout: BackendParsedWorkout
}

private struct BackendParsedWorkout: Decodable {
    var summary: String
    var lines: [BackendParsedLine]
    var exercises: [BackendParsedExercise]
    var cardioEntries: [BackendParsedCardioEntry]?

    func toWorkoutInterpretationResult(
        note: DailyWorkoutNote,
        exerciseMatcher: any ExerciseMatchingService
    ) -> WorkoutInterpretationResult {
        let exerciseByKey = exercises.reduce(into: [String: BackendParsedExercise]()) { result, exercise in
            guard let key = exercise.resolvedExerciseKey(using: exerciseMatcher) else { return }
            result[key] = exercise
        }

        let strengthSets = exercises.flatMap { exercise in
            exercise.strengthSets(note: note, exerciseMatcher: exerciseMatcher)
        }
        let cardioEntries = (cardioEntries ?? []).map { entry in
            entry.cardioEntry(note: note)
        }
        let cardioByLine = cardioEntries.reduce(into: [Int: CardioEntry]()) { result, entry in
            guard let lineIndex = entry.lineIndex else { return }
            result[lineIndex] = entry
        }
        let interpretedLines = lines.compactMap { line -> InterpretedWorkoutLine? in
            line.toInterpretedLine(
                note: note,
                exerciseByKey: exerciseByKey,
                cardioEntry: cardioByLine[line.lineIndex],
                exerciseMatcher: exerciseMatcher
            )
        }
        let totalSets = strengthSets.count
        let estimatedVolume = strengthSets.reduce(0) { total, set in
            total + Int(set.load) * set.reps
        }
        let cardioMinutes = cardioEntries.reduce(0) { total, entry in
            total + (entry.durationMinutes ?? 0)
        }

        return WorkoutInterpretationResult(
            lines: interpretedLines,
            metrics: WorkoutMetricSnapshot(
                totalSets: totalSets,
                hardSets: 0,
                estimatedVolume: estimatedVolume,
                prCount: 0,
                streakDays: note.metrics.streakDays,
                cardioMinutes: cardioMinutes,
                workoutDurationMinutes: cardioMinutes > 0 ? cardioMinutes : nil,
                parseState: note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .parsed
            ),
            suggestion: nil,
            strengthSets: strengthSets,
            cardioEntries: cardioEntries,
            prEvents: []
        )
    }
}

private struct BackendParsedExercise: Decodable {
    var name: String
    var normalizedName: String?
    var exerciseKey: String?
    var muscleGroupHint: String?
    var sets: [BackendWorkoutSet]

    func resolvedExerciseKey(using exerciseMatcher: any ExerciseMatchingService) -> String? {
        exerciseKey?.nilIfBlank ?? exerciseMatcher.normalize(name).exerciseKey
    }

    func normalizedExercise(using exerciseMatcher: any ExerciseMatchingService) -> NormalizedExercise {
        let local = exerciseMatcher.normalize(name)
        return NormalizedExercise(
            id: UUID(),
            displayName: name,
            exerciseKey: exerciseKey?.nilIfBlank ?? local.exerciseKey,
            canonicalName: normalizedName?.nilIfBlank ?? local.canonicalName,
            muscleGroup: muscleGroupHint?.nilIfBlank ?? local.muscleGroup
        )
    }

    func strengthSets(
        note: DailyWorkoutNote,
        exerciseMatcher: any ExerciseMatchingService
    ) -> [StrengthSetRecord] {
        let exercise = normalizedExercise(using: exerciseMatcher)
        return sets.enumerated().compactMap { index, set in
            guard let reps = set.reps else { return nil }
            return StrengthSetRecord(
                exerciseKey: exercise.exerciseKey,
                exerciseName: exercise.displayName,
                setNumber: index + 1,
                reps: reps,
                load: set.load ?? 0,
                unit: set.unit == "kg" ? "kg" : "lb",
                performedAt: note.date,
                effort: set.effort
            )
        }
    }
}

private struct BackendWorkoutSet: Decodable {
    var reps: Int?
    var load: Double?
    var unit: String
    var effort: String?
}

private struct BackendParsedCardioEntry: Decodable {
    var activityType: String
    var durationMinutes: Int?
    var distanceValue: Double?
    var distanceUnit: String?
    var sessionIndex: Int?
    var sourceLineIndex: Int?

    func cardioEntry(note: DailyWorkoutNote) -> CardioEntry {
        CardioEntry(
            noteId: note.id,
            lineIndex: sourceLineIndex,
            sessionIndex: sessionIndex,
            activityType: activityType,
            durationMinutes: durationMinutes,
            distance: distanceValue,
            distanceUnit: distanceUnit == "unknown" ? nil : distanceUnit
        )
    }
}

private struct BackendParsedLine: Decodable {
    var lineIndex: Int
    var kind: String
    var segments: [BackendParsedLineSegment]

    func toInterpretedLine(
        note: DailyWorkoutNote,
        exerciseByKey: [String: BackendParsedExercise],
        cardioEntry: CardioEntry?,
        exerciseMatcher: any ExerciseMatchingService
    ) -> InterpretedWorkoutLine? {
        guard lineIndex >= 0 else { return nil }

        let mappedSegments = segments.map(\.interpretedSegment)
        let exerciseSegment = mappedSegments.first { $0.kind == .exerciseAnchor }
        let exercise = exerciseSegment?.exerciseKey.flatMap { exerciseByKey[$0] }
            ?? exerciseSegment.map { BackendParsedExercise(name: $0.text, normalizedName: nil, exerciseKey: $0.exerciseKey, muscleGroupHint: nil, sets: []) }
        let anchor = exercise.map { parsedExercise -> ExerciseAnchor in
            let normalized = parsedExercise.normalizedExercise(using: exerciseMatcher)
            return ExerciseAnchor(
                id: UUID(),
                displayName: parsedExercise.name,
                normalizedName: normalized.canonicalName,
                exerciseKey: normalized.exerciseKey,
                history: .placeholder(for: normalized)
            )
        }

        return InterpretedWorkoutLine(
            noteId: note.id,
            lineIndex: lineIndex,
            rawText: "",
            kind: InterpretedWorkoutLineKind(rawValue: kind) ?? .note,
            segments: mappedSegments,
            exerciseAnchor: anchor,
            cardioEntry: cardioEntry,
            badges: [],
            chipText: "",
            detailTitle: anchor?.normalizedName ?? cardioEntry?.activityType ?? "Workout note",
            detailText: "Bram interpreted this line in the background.",
            confidence: 0.8
        )
    }
}

private struct BackendParsedLineSegment: Decodable {
    var type: String
    var text: String
    var exerciseKey: String?

    var interpretedSegment: InterpretedLineSegment {
        InterpretedLineSegment(
            kind: kind,
            text: text,
            exerciseKey: exerciseKey
        )
    }

    private var kind: InterpretedLineSegmentKind {
        switch type {
        case "exercise_anchor": .exerciseAnchor
        case "badge": .badge
        case "metric": .metric
        default: .text
        }
    }
}

private extension JSONEncoder {
    static var bramBackend: JSONEncoder {
        JSONEncoder()
    }
}

private extension JSONDecoder {
    static var bramBackend: JSONDecoder {
        JSONDecoder()
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
