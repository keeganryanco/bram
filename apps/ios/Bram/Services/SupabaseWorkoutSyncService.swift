import Foundation
import Supabase

struct SupabaseWorkoutSyncService: WorkoutSyncService {
    private let client: SupabaseClient
    private let localStore: any WorkoutLocalStore
    private let bodyEncryptor: any WorkoutNoteBodyEncrypting

    init(
        client: SupabaseClient,
        localStore: any WorkoutLocalStore,
        bodyEncryptor: any WorkoutNoteBodyEncrypting = WorkoutNoteBodyEncryptionService()
    ) {
        self.client = client
        self.localStore = localStore
        self.bodyEncryptor = bodyEncryptor
    }

    func syncPendingAccountData(userId: UUID) async throws {
        let payloads = try await localStore.pendingWorkoutSyncPayloads(limit: 25)
        var failures: [Error] = []
        for payload in payloads {
            do {
                let remoteId = payload.note.remoteId ?? payload.note.id
                try await upsert(payload: payload, userId: userId, remoteId: remoteId)
                try await localStore.markWorkoutSynced(localNoteId: payload.note.id, remoteId: remoteId, userId: userId)
            } catch {
                failures.append(error)
                try? await localStore.markWorkoutSyncFailed(localNoteId: payload.note.id, errorMessage: error.localizedDescription)
            }
        }
        if let firstFailure = failures.first {
            throw firstFailure
        }
    }

    func pullAccountData(userId: UUID) async throws {
        let notes: [RemoteWorkoutNoteRow] = try await client
            .from("workout_notes")
            .select()
            .eq("user_id", value: userId)
            .limit(500)
            .execute()
            .value

        guard !notes.isEmpty else { return }

        let metrics: [RemoteDailyWorkoutMetricsRow] = try await client
            .from("daily_workout_metrics")
            .select()
            .eq("user_id", value: userId)
            .limit(500)
            .execute()
            .value
        let strengthEntries: [RemoteStrengthEntryRow] = try await client
            .from("strength_entries")
            .select()
            .eq("user_id", value: userId)
            .limit(2_000)
            .execute()
            .value
        let cardioEntries: [RemoteCardioEntryRow] = try await client
            .from("cardio_entries")
            .select()
            .eq("user_id", value: userId)
            .limit(2_000)
            .execute()
            .value
        let prEvents: [RemoteWorkoutPRRow] = try await client
            .from("workout_prs")
            .select()
            .eq("user_id", value: userId)
            .limit(2_000)
            .execute()
            .value
        let healthMetrics: [RemoteHealthDailyMetricRow] = try await client
            .from("health_daily_metrics")
            .select()
            .eq("user_id", value: userId)
            .limit(500)
            .execute()
            .value
        let healthMatches: [RemoteHealthWorkoutMatchRow] = try await client
            .from("health_workout_matches")
            .select()
            .eq("user_id", value: userId)
            .limit(500)
            .execute()
            .value

        let metricsByNoteId = Dictionary(uniqueKeysWithValues: metrics.compactMap { row in
            row.noteId.map { ($0, row.localMetrics) }
        })
        let strengthByNoteId = Dictionary(grouping: strengthEntries, by: \.noteId)
        let cardioByNoteId = Dictionary(grouping: cardioEntries, by: \.noteId)
        let prsByNoteId = Dictionary(grouping: prEvents.compactMap { $0.localEvent }, by: \.noteId)
        let healthByDate = Dictionary(uniqueKeysWithValues: healthMetrics.map { ($0.metricDate, $0.localMetric) })
        let matchByNoteId = Dictionary(uniqueKeysWithValues: healthMatches.map { ($0.noteId, $0.localMatch) })

        let payloads = notes.map { row in
            let note = row.localNote(userId: userId, body: decryptedBody(for: row, userId: userId))
            return WorkoutSyncPayload(
                note: note,
                metrics: metricsByNoteId[row.id],
                strengthSets: (strengthByNoteId[row.id] ?? []).map(\.localSet),
                cardioEntries: (cardioByNoteId[row.id] ?? []).map { $0.localEntry(localNoteId: note.id) },
                prEvents: prsByNoteId[row.id] ?? [],
                healthDailyMetric: healthByDate[row.workoutDate],
                healthWorkoutMatch: matchByNoteId[row.id]
            )
        }

        try await localStore.importSyncedWorkoutData(payloads)
    }

    private func decryptedBody(for row: RemoteWorkoutNoteRow, userId: UUID) -> String {
        guard let bodyCiphertext = row.bodyCiphertext,
              let bodyNonce = row.bodyNonce
        else { return row.body }

        do {
            return try bodyEncryptor.decrypt(
                EncryptedWorkoutNoteBody(
                    ciphertext: bodyCiphertext,
                    nonce: bodyNonce,
                    keyVersion: row.bodyKeyVersion,
                    algorithm: row.bodyEncryptionAlg
                ),
                userId: userId
            )
        } catch {
            return row.body.isEmpty ? "" : row.body
        }
    }

    private func upsert(payload: WorkoutSyncPayload, userId: UUID, remoteId: UUID) async throws {
        let note = payload.note
        let encryptedBody = try bodyEncryptor.encrypt(note.body, userId: userId)
        try await client
            .from("workout_notes")
            .upsert(RemoteWorkoutNoteUpsert(note: note, remoteId: remoteId, userId: userId, encryptedBody: encryptedBody), onConflict: "id")
            .execute()

        try await deleteStructuredRows(remoteId: remoteId)
        guard note.deletedAt == nil else { return }

        if let metrics = payload.metrics {
            try await client
                .from("daily_workout_metrics")
                .upsert(RemoteDailyWorkoutMetrics(metrics: metrics, note: note, remoteId: remoteId, userId: userId), onConflict: "user_id,workout_date")
                .execute()
        }

        if !payload.strengthSets.isEmpty {
            try await client
                .from("strength_entries")
                .insert(payload.strengthSets.map { RemoteStrengthEntry(set: $0, noteId: remoteId, userId: userId) })
                .execute()
        }

        if !payload.cardioEntries.isEmpty {
            try await client
                .from("cardio_entries")
                .insert(payload.cardioEntries.map { RemoteCardioEntry(entry: $0, noteId: remoteId, userId: userId) })
                .execute()
        }

        if !payload.prEvents.isEmpty {
            try await client
                .from("workout_prs")
                .insert(payload.prEvents.map { RemoteWorkoutPR(event: $0, noteId: remoteId, userId: userId) })
                .execute()
        }

        if let healthDailyMetric = payload.healthDailyMetric {
            try await client
                .from("health_daily_metrics")
                .upsert(RemoteHealthDailyMetric(metric: healthDailyMetric, userId: userId), onConflict: "user_id,metric_date")
                .execute()
        }

        if let healthWorkoutMatch = payload.healthWorkoutMatch {
            try await client
                .from("health_workout_matches")
                .upsert(RemoteHealthWorkoutMatch(match: healthWorkoutMatch, noteId: remoteId, userId: userId), onConflict: "user_id,health_workout_id")
                .execute()
        }
    }

    private func deleteStructuredRows(remoteId: UUID) async throws {
        for table in ["workout_note_lines", "strength_entries", "cardio_entries", "workout_prs", "health_workout_matches"] {
            try await client
                .from(table)
                .delete()
                .eq("note_id", value: remoteId)
                .execute()
        }
    }
}

private struct RemoteWorkoutNoteUpsert: Encodable {
    var id: UUID
    var userId: UUID
    var clientLocalId: UUID
    var workoutDate: String
    var timezoneIdentifier: String
    var body: String
    var bodyCiphertext: String?
    var bodyNonce: String?
    var bodyKeyVersion: Int
    var bodyEncryptionAlg: String
    var syncState: String
    var clientUpdatedAt: Date
    var deletedAt: Date?

    init(note: DailyWorkoutNote, remoteId: UUID, userId: UUID, encryptedBody: EncryptedWorkoutNoteBody?) {
        id = remoteId
        self.userId = userId
        clientLocalId = note.id
        workoutDate = SQLiteWorkoutLocalStore.dayKey(for: note.date)
        timezoneIdentifier = note.timezoneIdentifier
        body = ""
        bodyCiphertext = encryptedBody?.ciphertext
        bodyNonce = encryptedBody?.nonce
        bodyKeyVersion = encryptedBody?.keyVersion ?? 1
        bodyEncryptionAlg = encryptedBody?.algorithm ?? "AES-256-GCM"
        syncState = note.deletedAt == nil ? WorkoutSyncState.synced.rawValue : WorkoutSyncState.deleted.rawValue
        clientUpdatedAt = note.updatedAt
        deletedAt = note.deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case clientLocalId = "client_local_id"
        case workoutDate = "workout_date"
        case timezoneIdentifier = "timezone_identifier"
        case body
        case bodyCiphertext = "body_ciphertext"
        case bodyNonce = "body_nonce"
        case bodyKeyVersion = "body_key_version"
        case bodyEncryptionAlg = "body_encryption_alg"
        case syncState = "sync_state"
        case clientUpdatedAt = "client_updated_at"
        case deletedAt = "deleted_at"
    }
}

private struct RemoteWorkoutNoteRow: Decodable {
    var id: UUID
    var userId: UUID
    var clientLocalId: UUID?
    var workoutDate: String
    var timezoneIdentifier: String
    var body: String
    var bodyCiphertext: String?
    var bodyNonce: String?
    var bodyKeyVersion: Int
    var bodyEncryptionAlg: String
    var syncState: String
    var clientUpdatedAt: Date?
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    func localNote(userId: UUID, body: String) -> DailyWorkoutNote {
        DailyWorkoutNote(
            id: clientLocalId ?? id,
            remoteId: id,
            userId: userId,
            date: SQLiteWorkoutLocalStore.date(from: workoutDate) ?? .now,
            timezoneIdentifier: timezoneIdentifier,
            body: body,
            createdAt: createdAt,
            updatedAt: clientUpdatedAt ?? updatedAt,
            deletedAt: deletedAt,
            syncState: .synced,
            lastSyncError: nil
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case clientLocalId = "client_local_id"
        case workoutDate = "workout_date"
        case timezoneIdentifier = "timezone_identifier"
        case body
        case bodyCiphertext = "body_ciphertext"
        case bodyNonce = "body_nonce"
        case bodyKeyVersion = "body_key_version"
        case bodyEncryptionAlg = "body_encryption_alg"
        case syncState = "sync_state"
        case clientUpdatedAt = "client_updated_at"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct RemoteDailyWorkoutMetrics: Encodable {
    var userId: UUID
    var workoutDate: String
    var noteId: UUID
    var totalSets: Int
    var hardSets: Int
    var estimatedVolume: Int
    var prCount: Int
    var cardioMinutes: Int
    var activeEnergyCalories: Int?
    var averageHeartRate: Int?
    var workoutDurationMinutes: Int?

    init(metrics: WorkoutMetricSnapshot, note: DailyWorkoutNote, remoteId: UUID, userId: UUID) {
        self.userId = userId
        workoutDate = SQLiteWorkoutLocalStore.dayKey(for: note.date)
        noteId = remoteId
        totalSets = metrics.totalSets
        hardSets = metrics.hardSets
        estimatedVolume = metrics.estimatedVolume
        prCount = metrics.prCount
        cardioMinutes = metrics.cardioMinutes
        activeEnergyCalories = metrics.activeEnergyCalories
        averageHeartRate = metrics.averageHeartRate
        workoutDurationMinutes = metrics.workoutDurationMinutes
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case workoutDate = "workout_date"
        case noteId = "note_id"
        case totalSets = "total_sets"
        case hardSets = "hard_sets"
        case estimatedVolume = "estimated_volume"
        case prCount = "pr_count"
        case cardioMinutes = "cardio_minutes"
        case activeEnergyCalories = "active_energy_calories"
        case averageHeartRate = "average_heart_rate"
        case workoutDurationMinutes = "workout_duration_minutes"
    }
}

private struct RemoteDailyWorkoutMetricsRow: Decodable {
    var userId: UUID
    var workoutDate: String
    var noteId: UUID?
    var totalSets: Int
    var hardSets: Int
    var estimatedVolume: Int
    var prCount: Int
    var cardioMinutes: Int
    var activeEnergyCalories: Int?
    var averageHeartRate: Int?
    var workoutDurationMinutes: Int?

    var localMetrics: WorkoutMetricSnapshot {
        WorkoutMetricSnapshot(
            totalSets: totalSets,
            hardSets: hardSets,
            estimatedVolume: estimatedVolume,
            prCount: prCount,
            streakDays: 0,
            cardioMinutes: cardioMinutes,
            activeEnergyCalories: activeEnergyCalories,
            energyIsEstimated: false,
            averageHeartRate: averageHeartRate,
            workoutDurationMinutes: workoutDurationMinutes,
            parseState: .parsed
        )
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case workoutDate = "workout_date"
        case noteId = "note_id"
        case totalSets = "total_sets"
        case hardSets = "hard_sets"
        case estimatedVolume = "estimated_volume"
        case prCount = "pr_count"
        case cardioMinutes = "cardio_minutes"
        case activeEnergyCalories = "active_energy_calories"
        case averageHeartRate = "average_heart_rate"
        case workoutDurationMinutes = "workout_duration_minutes"
    }
}

private struct RemoteStrengthEntry: Encodable {
    var id: UUID
    var userId: UUID
    var noteId: UUID
    var lineId: UUID?
    var exerciseName: String
    var exerciseKey: String?
    var sets: Int
    var reps: Int
    var loadValue: Double
    var loadUnit: String
    var effort: String?
    var muscleGroup: String?

    init(set: StrengthSetRecord, noteId: UUID, userId: UUID) {
        id = set.id
        self.userId = userId
        self.noteId = noteId
        lineId = nil
        exerciseName = set.exerciseName
        exerciseKey = nil
        sets = 1
        reps = set.reps
        loadValue = set.load
        loadUnit = set.unit
        effort = set.effort
        muscleGroup = nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case noteId = "note_id"
        case lineId = "line_id"
        case exerciseName = "exercise_name"
        case exerciseKey = "exercise_key"
        case sets
        case reps
        case loadValue = "load_value"
        case loadUnit = "load_unit"
        case effort
        case muscleGroup = "muscle_group"
    }
}

private struct RemoteStrengthEntryRow: Decodable {
    var id: UUID
    var noteId: UUID
    var exerciseName: String
    var exerciseKey: String?
    var reps: Int?
    var loadValue: Double?
    var loadUnit: String
    var effort: String?

    var localSet: StrengthSetRecord {
        StrengthSetRecord(
            id: id,
            exerciseKey: exerciseKey ?? RemoteExerciseKey.key(for: exerciseName),
            exerciseName: exerciseName,
            reps: reps ?? 0,
            load: loadValue ?? 0,
            unit: loadUnit,
            performedAt: .now,
            effort: effort
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case noteId = "note_id"
        case exerciseName = "exercise_name"
        case exerciseKey = "exercise_key"
        case reps
        case loadValue = "load_value"
        case loadUnit = "load_unit"
        case effort
    }
}

private struct RemoteCardioEntry: Encodable {
    var id: UUID
    var userId: UUID
    var noteId: UUID
    var lineId: UUID?
    var lineIndex: Int?
    var sessionIndex: Int?
    var sessionName: String?
    var activityType: String
    var durationMinutes: Int?
    var distanceValue: Double?
    var distanceUnit: String?
    var averageHeartRate: Int?
    var activeEnergyCalories: Int?

    init(entry: CardioEntry, noteId: UUID, userId: UUID) {
        id = entry.id
        self.userId = userId
        self.noteId = noteId
        lineId = nil
        lineIndex = entry.lineIndex
        sessionIndex = entry.sessionIndex
        sessionName = entry.sessionName
        activityType = entry.activityType
        durationMinutes = entry.durationMinutes
        distanceValue = entry.distance
        distanceUnit = entry.distanceUnit
        averageHeartRate = entry.averageHeartRate
        activeEnergyCalories = entry.activeEnergyCalories
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case noteId = "note_id"
        case lineId = "line_id"
        case lineIndex = "source_line_index"
        case sessionIndex = "session_index"
        case sessionName = "session_name"
        case activityType = "activity_type"
        case durationMinutes = "duration_minutes"
        case distanceValue = "distance_value"
        case distanceUnit = "distance_unit"
        case averageHeartRate = "average_heart_rate"
        case activeEnergyCalories = "active_energy_calories"
    }
}

private struct RemoteCardioEntryRow: Decodable {
    var id: UUID
    var noteId: UUID
    var lineIndex: Int?
    var sessionIndex: Int?
    var sessionName: String?
    var activityType: String
    var durationMinutes: Int?
    var distanceValue: Double?
    var distanceUnit: String?
    var averageHeartRate: Int?
    var activeEnergyCalories: Int?

    func localEntry(localNoteId: UUID) -> CardioEntry {
        CardioEntry(
            id: id,
            noteId: localNoteId,
            lineIndex: lineIndex,
            sessionIndex: sessionIndex,
            sessionName: sessionName,
            activityType: activityType,
            durationMinutes: durationMinutes,
            distance: distanceValue,
            distanceUnit: distanceUnit,
            averageHeartRate: averageHeartRate,
            activeEnergyCalories: activeEnergyCalories
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case noteId = "note_id"
        case lineIndex = "source_line_index"
        case sessionIndex = "session_index"
        case sessionName = "session_name"
        case activityType = "activity_type"
        case durationMinutes = "duration_minutes"
        case distanceValue = "distance_value"
        case distanceUnit = "distance_unit"
        case averageHeartRate = "average_heart_rate"
        case activeEnergyCalories = "active_energy_calories"
    }
}

private struct RemoteWorkoutPR: Encodable {
    var id: UUID
    var userId: UUID
    var noteId: UUID
    var exerciseName: String
    var exerciseKey: String?
    var prKind: String
    var value: Double
    var unit: String
    var achievedAt: Date

    init(event: WorkoutPREvent, noteId: UUID, userId: UUID) {
        id = event.id
        self.userId = userId
        self.noteId = noteId
        exerciseName = event.exerciseName
        exerciseKey = nil
        prKind = event.kind
        value = event.value
        unit = event.unit
        achievedAt = event.achievedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case noteId = "note_id"
        case exerciseName = "exercise_name"
        case exerciseKey = "exercise_key"
        case prKind = "pr_kind"
        case value
        case unit
        case achievedAt = "achieved_at"
    }
}

private struct RemoteWorkoutPRRow: Decodable {
    var id: UUID
    var noteId: UUID?
    var exerciseName: String
    var prKind: String
    var value: Double
    var unit: String
    var achievedAt: Date

    var localEvent: WorkoutPREvent? {
        guard let noteId else { return nil }
        return WorkoutPREvent(
            id: id,
            noteId: noteId,
            exerciseName: exerciseName,
            kind: prKind,
            value: value,
            unit: unit,
            achievedAt: achievedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case noteId = "note_id"
        case exerciseName = "exercise_name"
        case prKind = "pr_kind"
        case value
        case unit
        case achievedAt = "achieved_at"
    }
}

private struct RemoteHealthDailyMetric: Encodable {
    var userId: UUID
    var metricDate: String
    var activeEnergyCalories: Int?
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var bodyweightValue: Double?
    var bodyweightUnit: String?
    var source: String

    init(metric: HealthDailyMetric, userId: UUID) {
        self.userId = userId
        metricDate = SQLiteWorkoutLocalStore.dayKey(for: metric.date)
        activeEnergyCalories = metric.activeEnergyCalories
        averageHeartRate = metric.averageHeartRate
        maxHeartRate = metric.maxHeartRate
        bodyweightValue = metric.bodyweightValue
        bodyweightUnit = metric.bodyweightUnit
        source = metric.source
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case metricDate = "metric_date"
        case activeEnergyCalories = "active_energy_calories"
        case averageHeartRate = "average_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case bodyweightValue = "bodyweight_value"
        case bodyweightUnit = "bodyweight_unit"
        case source
    }
}

private struct RemoteHealthDailyMetricRow: Decodable {
    var metricDate: String
    var activeEnergyCalories: Int?
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var bodyweightValue: Double?
    var bodyweightUnit: String?
    var source: String
    var updatedAt: Date?

    var localMetric: HealthDailyMetric {
        HealthDailyMetric(
            date: SQLiteWorkoutLocalStore.date(from: metricDate) ?? .now,
            activeEnergyCalories: activeEnergyCalories,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            bodyweightValue: bodyweightValue,
            bodyweightUnit: bodyweightUnit,
            source: source,
            updatedAt: updatedAt ?? .now
        )
    }

    enum CodingKeys: String, CodingKey {
        case metricDate = "metric_date"
        case activeEnergyCalories = "active_energy_calories"
        case averageHeartRate = "average_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case bodyweightValue = "bodyweight_value"
        case bodyweightUnit = "bodyweight_unit"
        case source
        case updatedAt = "updated_at"
    }
}

private struct RemoteHealthWorkoutMatch: Encodable {
    var id: UUID
    var userId: UUID
    var noteId: UUID
    var healthWorkoutId: String
    var matchQuality: String
    var matchedAt: Date

    init(match: HealthWorkoutMatch, noteId: UUID, userId: UUID) {
        id = match.id
        self.userId = userId
        self.noteId = noteId
        healthWorkoutId = match.healthWorkoutId
        matchQuality = match.matchQuality.rawValue
        matchedAt = match.matchedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case noteId = "note_id"
        case healthWorkoutId = "health_workout_id"
        case matchQuality = "match_quality"
        case matchedAt = "matched_at"
    }
}

private struct RemoteHealthWorkoutMatchRow: Decodable {
    var id: UUID
    var noteId: UUID
    var healthWorkoutId: String
    var matchQuality: String
    var matchedAt: Date

    var localMatch: HealthWorkoutMatch {
        HealthWorkoutMatch(
            id: id,
            noteId: noteId,
            noteDate: .now,
            healthWorkoutId: healthWorkoutId,
            matchQuality: HealthWorkoutMatchQuality(rawValue: matchQuality) ?? .possible,
            matchedAt: matchedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case noteId = "note_id"
        case healthWorkoutId = "health_workout_id"
        case matchQuality = "match_quality"
        case matchedAt = "matched_at"
    }
}

private enum RemoteExerciseKey {
    static func key(for name: String) -> String {
        let words = name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return words.isEmpty ? "unknown" : words.joined(separator: "_")
    }
}
