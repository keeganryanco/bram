import Foundation

struct HeuristicWorkoutInterpretationService: WorkoutInterpretationService {
    private let exerciseMatcher: any ExerciseMatchingService
    private let prDetector: any PRDetectionService

    init(
        exerciseMatcher: any ExerciseMatchingService = DefaultExerciseMatchingService(),
        prDetector: any PRDetectionService = DefaultPRDetectionService()
    ) {
        self.exerciseMatcher = exerciseMatcher
        self.prDetector = prDetector
    }

    func interpret(note: DailyWorkoutNote) async -> WorkoutInterpretationResult {
        let rawLines = note.body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var lines: [InterpretedWorkoutLine] = []
        var totalSets = 0
        var estimatedVolume = 0
        var cardioMinutes = 0
        var prCount = 0
        var averageHeartRate: Int?
        var strengthSets: [StrengthSetRecord] = []
        var cardioEntries: [CardioEntry] = []
        var prEvents: [WorkoutPREvent] = []
        var currentSessionIndex = 0
        var currentSessionName: String?
        var index = 0

        while index < rawLines.count {
            let rawLine = rawLines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                index += 1
                continue
            }
            if let sessionName = workoutSessionLabel(trimmed) {
                currentSessionIndex += 1
                currentSessionName = sessionName
                lines.append(
                    InterpretedWorkoutLine(
                        noteId: note.id,
                        lineIndex: index,
                        rawText: rawLine,
                        kind: .note,
                        segments: [InterpretedLineSegment(kind: .text, text: rawLine)],
                        chipText: "",
                        detailTitle: sessionName,
                        detailText: "Bram treated this as a separate workout segment for the day.",
                        confidence: 0.7
                    )
                )
                index += 1
                continue
            }
            if isSupersetLabel(trimmed), let supersetLine = supersetGroupLine(startingAt: index, lines: rawLines, note: note) {
                lines.append(supersetLine)
                index += 1
                continue
            }
            guard !isWorkoutSectionLabel(trimmed) else {
                index += 1
                continue
            }

            if let block = exerciseBlock(startingAt: index, lines: rawLines, note: note) {
                totalSets += block.sets.count
                estimatedVolume += block.sets.reduce(0) { $0 + Int($1.load) * $1.reps }
                if block.pr.isPR { prCount += 1 }
                strengthSets.append(contentsOf: block.sets)
                prEvents.append(contentsOf: block.pr.events)
                lines.append(contentsOf: block.lines)
                index = block.nextIndex
                continue
            }

            if let strength = strengthSignal(in: trimmed) {
                totalSets += strength.sets
                estimatedVolume += strength.volume
                let exercise = exerciseMatcher.normalize(strength.exerciseName)
                let setRecords = (1...strength.sets).map { setNumber in
                    StrengthSetRecord(
                        exerciseKey: exercise.exerciseKey,
                        exerciseName: exercise.displayName,
                        lineIndex: index,
                        setNumber: setNumber,
                        reps: strength.reps,
                        load: Double(strength.load),
                        performedAt: note.date,
                        effort: strength.effort
                    )
                }
                let pr = prDetector.detectPR(for: exercise, sets: setRecords)
                if pr.isPR { prCount += 1 }
                strengthSets.append(contentsOf: setRecords)
                prEvents.append(contentsOf: pr.events)
                let badges = [pr.badge].compactMap { $0 }
                let history = ExerciseHistorySummary.placeholder(for: exercise, bestSet: setRecords.first)
                let anchor = ExerciseAnchor(
                    id: UUID(),
                    displayName: exercise.displayName,
                    normalizedName: exercise.canonicalName,
                    exerciseKey: exercise.exerciseKey,
                    history: history
                )
                lines.append(
                    InterpretedWorkoutLine(
                        noteId: note.id,
                        lineIndex: index,
                        rawText: rawLine,
                        kind: .strength,
                        segments: [
                            InterpretedLineSegment(kind: .exerciseAnchor, text: exercise.displayName, exerciseKey: exercise.exerciseKey),
                            InterpretedLineSegment(kind: .metric, text: strength.metricText),
                        ] + badges.map { InterpretedLineSegment(kind: .badge, text: $0.label, exerciseKey: exercise.exerciseKey) },
                        exerciseAnchor: anchor,
                        badges: badges,
                        chipText: pr.isPR ? "PR" : "\(strength.sets) sets",
                        detailTitle: exercise.canonicalName,
                        detailText: [strength.detail, strength.effort.map { "Effort: \($0)." }]
                            .compactMap { $0 }
                            .joined(separator: " "),
                        confidence: strength.confidence
                    )
                )
                index += 1
                continue
            }

            if let cardio = cardioSignal(in: trimmed) {
                cardioMinutes += cardio.minutes ?? 0
                let entry = CardioEntry(
                    noteId: note.id,
                    lineIndex: index,
                    sessionIndex: currentSessionIndex > 0 ? currentSessionIndex : nil,
                    sessionName: currentSessionName,
                    activityType: cardio.activityType,
                    durationMinutes: cardio.minutes,
                    distance: cardio.distance,
                    distanceUnit: cardio.distanceUnit
                )
                cardioEntries.append(entry)
                lines.append(
                    InterpretedWorkoutLine(
                        noteId: note.id,
                        lineIndex: index,
                        rawText: rawLine,
                        kind: .cardio,
                        segments: [
                            InterpretedLineSegment(kind: .text, text: rawLine),
                            InterpretedLineSegment(kind: .metric, text: cardio.metricText)
                        ],
                        cardioEntry: entry,
                        chipText: cardio.metricText,
                        detailTitle: cardio.activityType,
                        detailText: cardio.detail,
                        confidence: cardio.confidence
                    )
                )
                index += 1
                continue
            }

            if let heartRate = heartRateSignal(in: trimmed) {
                averageHeartRate = heartRate
                lines.append(
                    InterpretedWorkoutLine(
                        noteId: note.id,
                        lineIndex: index,
                        rawText: rawLine,
                        kind: .health,
                        segments: [
                            InterpretedLineSegment(kind: .text, text: rawLine),
                            InterpretedLineSegment(kind: .metric, text: "HR \(heartRate)")
                        ],
                        chipText: "HR \(heartRate)",
                        detailTitle: "Heart rate",
                        detailText: "Bram recognized this as heart-rate context. Apple Health will become the source of truth later.",
                        confidence: 0.72
                    )
                )
            }
            index += 1
        }

        let state: WorkoutParseState = note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .parsed
        let hardSets = strengthSets.filter { Self.isHardEffort($0.effort) }.count
        let metrics = WorkoutMetricSnapshot(
            totalSets: totalSets,
            hardSets: hardSets,
            estimatedVolume: estimatedVolume,
            prCount: prCount,
            streakDays: note.metrics.streakDays,
            cardioMinutes: cardioMinutes,
            activeEnergyCalories: nil,
            averageHeartRate: averageHeartRate,
            workoutDurationMinutes: cardioMinutes > 0 ? cardioMinutes : nil,
            parseState: state
        )

        let suggestion = suggestion(for: totalSets, cardioMinutes: cardioMinutes, prCount: prCount)
        return WorkoutInterpretationResult(
            lines: lines,
            metrics: metrics,
            suggestion: suggestion,
            strengthSets: strengthSets,
            cardioEntries: cardioEntries,
            prEvents: prEvents
        )
    }

    private func exerciseBlock(
        startingAt index: Int,
        lines rawLines: [String],
        note: DailyWorkoutNote
    ) -> (lines: [InterpretedWorkoutLine], sets: [StrengthSetRecord], pr: PRDetectionResult, nextIndex: Int)? {
        let header = rawLines[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !header.isEmpty,
              !isWorkoutSectionLabel(header),
              !isMetadataLine(header),
              strengthSignal(in: header) == nil,
              cardioSignal(in: header) == nil
        else { return nil }

        var setRows: [(lineIndex: Int, rawText: String, record: StrengthSetRecord)] = []
        var cursor = index + 1
        let headerEffort = effortSignal(in: header)
        while cursor < rawLines.count {
            let line = rawLines[cursor].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { break }
            guard !isWorkoutSectionLabel(line) else { break }
            guard var set = setLineSignal(in: line, exerciseName: header, fallbackEffort: headerEffort) else { break }
            set.lineIndex = cursor
            set.setNumber = setRows.count + 1
            set.performedAt = note.date
            setRows.append((cursor, rawLines[cursor], set))
            cursor += 1
        }
        let setRecords = setRows.map(\.record)
        guard !setRecords.isEmpty else { return nil }

        let exercise = exerciseMatcher.normalize(header)
        let pr = prDetector.detectPR(for: exercise, sets: setRecords)
        let history = ExerciseHistorySummary.placeholder(
            for: exercise,
            bestSet: setRecords.max(by: { $0.estimatedOneRepMax < $1.estimatedOneRepMax })
        )
        let anchor = ExerciseAnchor(
            id: UUID(),
            displayName: exercise.displayName,
            normalizedName: exercise.canonicalName,
            exerciseKey: exercise.exerciseKey,
            history: history
        )
        var interpretedLines = [
            InterpretedWorkoutLine(
            noteId: note.id,
            lineIndex: index,
            rawText: header,
            kind: .strength,
            segments: [
                InterpretedLineSegment(kind: .exerciseAnchor, text: exercise.displayName, exerciseKey: exercise.exerciseKey)
            ],
            exerciseAnchor: anchor,
            badges: [],
            chipText: "\(setRecords.count) sets",
            detailTitle: exercise.canonicalName,
            detailText: [ "Bram grouped \(setRecords.count) sets under \(exercise.displayName).", effortSummaryText(for: setRecords).map { "Effort: \($0)." } ]
                .compactMap { $0 }
                .joined(separator: " "),
            confidence: 0.8
            )
        ]

        if let badge = pr.badge, let bestSetId = pr.bestSetId {
            interpretedLines.append(contentsOf: setRows.compactMap { row in
                guard row.record.id == bestSetId else { return nil }
                return InterpretedWorkoutLine(
                    noteId: note.id,
                    lineIndex: row.lineIndex,
                    rawText: row.rawText,
                    kind: .strength,
                    segments: [
                        InterpretedLineSegment(kind: .text, text: row.rawText),
                        InterpretedLineSegment(kind: .badge, text: badge.label, exerciseKey: exercise.exerciseKey)
                    ],
                    badges: [badge],
                    chipText: "PR",
                    detailTitle: exercise.canonicalName,
                    detailText: [
                        "\(Int(row.record.load)) x \(row.record.reps) is the best estimated strength set Bram found in this block.",
                        row.record.effort.map { "Effort: \($0)." }
                    ]
                        .compactMap { $0 }
                        .joined(separator: " "),
                    confidence: 0.8
                )
            })
        }

        return (interpretedLines, setRecords, pr, cursor)
    }

    private func supersetGroupLine(
        startingAt index: Int,
        lines rawLines: [String],
        note: DailyWorkoutNote
    ) -> InterpretedWorkoutLine? {
        var cursor = index + 1
        var members: [SupersetExerciseMember] = []

        while cursor < rawLines.count {
            let line = rawLines[cursor].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { break }
            guard !isSupersetLabel(line) else { break }

            if let block = exerciseBlock(startingAt: cursor, lines: rawLines, note: note),
               let anchor = block.lines.first?.exerciseAnchor {
                members.append(
                    SupersetExerciseMember(
                        id: UUID(),
                        displayName: anchor.displayName,
                        normalizedName: anchor.normalizedName,
                        exerciseKey: anchor.exerciseKey,
                        history: nil
                    )
                )
                cursor = block.nextIndex
                continue
            }

            cursor += 1
        }

        guard members.count >= 2 else { return nil }

        let anchor = ExerciseAnchor(
            id: UUID(),
            displayName: "Superset",
            normalizedName: "Superset",
            exerciseKey: "superset_\(members.map(\.exerciseKey).joined(separator: "_"))",
            history: .supersetPlaceholder(members: members),
            groupMembers: members
        )

        return InterpretedWorkoutLine(
            noteId: note.id,
            lineIndex: index,
            rawText: rawLines[index],
            kind: .strength,
            segments: [
                InterpretedLineSegment(kind: .exerciseAnchor, text: rawLines[index].trimmingCharacters(in: .whitespacesAndNewlines), exerciseKey: anchor.exerciseKey)
            ],
            exerciseAnchor: anchor,
            badges: [],
            chipText: "",
            detailTitle: "Superset",
            detailText: "Bram grouped \(members.count) exercises in this superset.",
            confidence: 0.8
        )
    }

    private func strengthSignal(in line: String) -> (exerciseName: String, sets: Int, reps: Int, load: Int, volume: Int, isPR: Bool, effort: String?, metricText: String, detail: String, confidence: Double)? {
        let lower = line.lowercased()
        let isPR = lower.contains("pr") || lower.contains("personal record")
        guard let match = firstMatch(#"(\d+)\s*[xX]\s*(\d+)"#, in: line) else {
            return nil
        }

        let sets = Int(match[1]) ?? 0
        let reps = Int(match[2]) ?? 0
        let load = firstNumber(before: match[0], in: line) ?? 0
        let volume = sets * reps * load
        let exerciseName = exerciseName(before: load, in: line)
        let effort = effortSignal(in: line)
        let metricText = load > 0 ? "\(sets) x \(reps) @ \(load)" : "\(sets) x \(reps)"
        let detail = load > 0
            ? "Bram read this as \(sets) sets of \(reps) at about \(load) lb."
            : "Bram read this as \(sets) sets of \(reps). Load can be added naturally in the note."
        return (exerciseName, max(sets, 1), reps, load, volume, isPR, effort, metricText, detail, load > 0 ? 0.82 : 0.68)
    }

    private func setLineSignal(in line: String, exerciseName: String, fallbackEffort: String? = nil) -> StrengthSetRecord? {
        let lower = line.lowercased()
        let effort = effortSignal(in: line) ?? fallbackEffort
        if let match = firstMatch(#"^\s*\d+\s*[-:]\s*((?:\d+(?:\.\d+)?)(?:s)?|bw|bodyweight)(?:\s*(?:lb|lbs|pounds?))?(?:\s*(?:each|ea|per side|descending))*\s*(?:for|x)\s*(\d+)"#, in: lower) {
            guard let reps = Int(match[2]) else { return nil }
            let loadToken = match[1].replacingOccurrences(of: #"s$"#, with: "", options: .regularExpression)
            let load = bodyweightTokens.contains(match[1]) ? 0 : Double(loadToken) ?? 0
            let exercise = exerciseMatcher.normalize(exerciseName)
            return StrengthSetRecord(
                exerciseKey: exercise.exerciseKey,
                exerciseName: exercise.displayName,
                reps: reps,
                load: load,
                effort: effort
            )
        }

        guard let repOnlyMatch = firstMatch(#"^\s*\d+\s*[-:]\s*(\d+)(?:\s+.*)?$"#, in: lower),
              let reps = Int(repOnlyMatch[1])
        else {
            return nil
        }
        let exercise = exerciseMatcher.normalize(exerciseName)
        return StrengthSetRecord(
            exerciseKey: exercise.exerciseKey,
            exerciseName: exercise.displayName,
            reps: reps,
            load: 0,
            effort: effort
        )
    }

    private func effortSignal(in line: String) -> String? {
        let lower = line.lowercased()
        if let match = firstMatch(#"\brpe\s*([0-9](?:\.[05])?|10)\b"#, in: lower),
           let value = Double(match[1]) {
            return value.rounded() == value ? "RPE \(Int(value))" : "RPE \(String(format: "%.1f", value))"
        }
        if let match = firstMatch(#"\brir\s*([0-9])\b"#, in: lower),
           let value = Int(match[1]) {
            return "RIR \(value)"
        }
        if let match = firstMatch(#"\b([0-9])\s*rir\b"#, in: lower),
           let value = Int(match[1]) {
            return "RIR \(value)"
        }
        if lower.contains("to failure") || lower.contains("till failure") || lower.contains("until failure") || lower.contains("failed rep") || lower.contains("failure") {
            return "Failure"
        }
        if lower.contains("grinder") || lower.contains("grinded") || lower.contains("grindy") {
            return "Grinder"
        }
        if lower.contains("hard set") || lower.contains("hard sets") || lower.contains(" felt hard") || lower.hasSuffix(" hard") {
            return "Hard"
        }
        if lower.contains("easy set") || lower.contains("easy sets") || lower.contains(" felt easy") || lower.hasSuffix(" easy") {
            return "Easy"
        }
        return nil
    }

    private static func isHardEffort(_ effort: String?) -> Bool {
        guard let effort else { return false }
        let lower = effort.lowercased()
        if lower.contains("failure") || lower.contains("grinder") || lower == "hard" { return true }
        if lower.hasPrefix("rpe "),
           let value = Double(lower.replacingOccurrences(of: "rpe ", with: "")) {
            return value >= 8
        }
        if lower.hasPrefix("rir "),
           let value = Int(lower.replacingOccurrences(of: "rir ", with: "")) {
            return value <= 2
        }
        return false
    }

    private func effortSummaryText(for sets: [StrengthSetRecord]) -> String? {
        let efforts = sets.compactMap(\.effort)
        guard !efforts.isEmpty else { return nil }
        let counts = Dictionary(grouping: efforts, by: { $0 }).mapValues(\.count)
        return counts.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
            return $0.value > $1.value
        }.first?.key
    }

    private var bodyweightTokens: Set<String> {
        ["bw", "bodyweight"]
    }

    private func isWorkoutSectionLabel(_ line: String) -> Bool {
        let normalized = line
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^a-z\s]"#, with: "", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")

        return [
            "superset",
            "warm up",
            "warmup",
            "warm ups",
            "warmups",
            "working sets"
        ].contains(normalized)
    }

    private func isSupersetLabel(_ line: String) -> Bool {
        line
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^a-z\s]"#, with: "", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ") == "superset"
    }

    private func isMetadataLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.contains("weight at") { return true }
        if firstMatch(#"^\s*[a-z]{3,9}\s+\d{1,2}\b"#, in: lower) != nil { return true }
        return false
    }

    private func workoutSessionLabel(_ line: String) -> String? {
        let lower = line.lowercased()
        guard lower.contains("workout") || lower.contains("session") || lower.contains("lift") || lower.contains("cardio") || lower.contains("run") else {
            return nil
        }
        guard firstMatch(#"^\s*\d+\s*[-:]"#, in: line) == nil,
              setLineSignal(in: line, exerciseName: "Exercise") == nil,
              strengthSignal(in: line) == nil,
              cardioSignal(in: line) == nil
        else { return nil }
        if lower.contains("day") || lower.contains("session") || lower.contains("workout") {
            return line
        }
        if (lower.contains("morning") || lower.contains("evening") || lower.contains("afternoon")) &&
            (lower.contains("run") || lower.contains("cardio") || lower.contains("lift")) {
            return line
        }
        return nil
    }

    private func cardioSignal(in line: String) -> (
        activityType: String,
        minutes: Int?,
        distance: Double?,
        distanceUnit: String?,
        metricText: String,
        detail: String,
        confidence: Double
    )? {
        let lower = line.lowercased()
        let cardioWords = ["run", "ran", "walk", "bike", "cycle", "row", "stair", "elliptical", "cardio", "treadmill"]
        guard cardioWords.contains(where: lower.contains) else { return nil }
        let activity = cardioActivityType(in: lower)
        let explicitMinutes = explicitCardioMinutes(in: lower)
        let distance = cardioDistance(in: lower)
        let estimatedMinutes = explicitMinutes ?? estimatedMinutes(activity: activity, distance: distance?.value, unit: distance?.unit)
        guard explicitMinutes != nil || distance != nil else { return nil }

        let metricText: String
        if let distance {
            metricText = distanceText(value: distance.value, unit: distance.unit)
        } else if let estimatedMinutes {
            metricText = "\(estimatedMinutes) min"
        } else {
            metricText = "Cardio"
        }

        let detail: String
        if let distance, let explicitMinutes {
            detail = "Bram read this as \(distanceText(value: distance.value, unit: distance.unit)) of \(activity.lowercased()) in \(explicitMinutes) minutes."
        } else if let distance, let estimatedMinutes {
            detail = "Bram read this as \(distanceText(value: distance.value, unit: distance.unit)) of \(activity.lowercased()) and estimated \(estimatedMinutes) minutes until Health data is linked."
        } else if let explicitMinutes {
            detail = "Bram read this as \(explicitMinutes) minutes of \(activity.lowercased())."
        } else {
            detail = "Bram recognized this as cardio."
        }

        return (activity, estimatedMinutes, distance?.value, distance?.unit, metricText, detail, distance == nil ? 0.74 : 0.82)
    }

    private func cardioActivityType(in lower: String) -> String {
        if lower.contains("walk") { return "Walking" }
        if lower.contains("bike") || lower.contains("cycle") { return "Cycling" }
        if lower.contains("row") { return "Rowing" }
        if lower.contains("stair") { return "Stairs" }
        if lower.contains("elliptical") { return "Elliptical" }
        return "Running"
    }

    private func explicitCardioMinutes(in lower: String) -> Int? {
        if let match = firstMatch(#"(\d+)\s*(min|mins|minute|minutes)"#, in: lower),
           let minutes = Int(match[1]) {
            return minutes
        }
        if let match = firstMatch(#"\b(\d{1,2}):(\d{2})\b"#, in: lower),
           let minutes = Int(match[1]),
           let seconds = Int(match[2]) {
            return seconds >= 30 ? minutes + 1 : minutes
        }
        return nil
    }

    private func cardioDistance(in lower: String) -> (value: Double, unit: String)? {
        if let match = firstMatch(#"(\d+(?:\.\d+)?)\s*(mi|mile|miles)\b"#, in: lower),
           let value = Double(match[1]) {
            return (value, "mi")
        }
        if let match = firstMatch(#"(\d+(?:\.\d+)?)\s*(km|kilometer|kilometers)\b"#, in: lower),
           let value = Double(match[1]) {
            return (value, "km")
        }
        if let match = firstMatch(#"\b(5k|10k)\b"#, in: lower) {
            return (match[1] == "10k" ? 10 : 5, "km")
        }
        if let match = firstMatch(#"(\d+(?:\.\d+)?)\s*k\b"#, in: lower),
           let value = Double(match[1]) {
            return (value, "km")
        }
        return nil
    }

    private func estimatedMinutes(activity: String, distance: Double?, unit: String?) -> Int? {
        guard let distance, let unit else { return nil }
        let miles = unit == "km" ? distance * 0.621371 : distance
        let minutesPerMile: Double
        switch activity {
        case "Walking": minutesPerMile = 18
        case "Cycling": minutesPerMile = 4
        case "Rowing": minutesPerMile = 8
        default: minutesPerMile = 10
        }
        return max(1, Int((miles * minutesPerMile).rounded()))
    }

    private func distanceText(value: Double, unit: String) -> String {
        let amount = value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
        return "\(amount) \(unit)"
    }

    private func heartRateSignal(in line: String) -> Int? {
        firstMatch(#"(hr|heart rate|bpm)\s*:?\s*(\d{2,3})"#, in: line.lowercased()).flatMap { Int($0[2]) }
    }

    private func suggestion(for sets: Int, cardioMinutes: Int, prCount: Int) -> WorkoutSuggestion? {
        guard sets > 0 || cardioMinutes > 0 else { return nil }
        if prCount > 0 {
            return nil
        }
        if sets >= 12 {
            return WorkoutSuggestion(kind: .balance, text: "Solid volume today. Your weekly balance will get clearer as more days fill in.")
        }
        if cardioMinutes > 0 {
            return WorkoutSuggestion(kind: .recovery, text: "Cardio is logged. Heart-rate context will make this more useful once Apple Health is connected.")
        }
        return nil
    }

    private func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func firstNumber(before marker: String, in text: String) -> Int? {
        guard let markerRange = text.range(of: marker) else { return nil }
        let prefix = String(text[..<markerRange.lowerBound])
        let numbers = prefix.split { !$0.isNumber }.compactMap { Int($0) }
        return numbers.last
    }

    private func exerciseName(before load: Int, in text: String) -> String {
        guard load > 0, let range = text.range(of: "\(load)") else {
            return text.components(separatedBy: CharacterSet.decimalDigits).first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? "Exercise"
        }
        return String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Exercise"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
