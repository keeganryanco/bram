import Foundation

actor SQLiteWorkoutLocalStore: WorkoutLocalStore {
    static let shared = SQLiteWorkoutLocalStore()

    private let database: SQLiteDatabase
    private let interpreter: any WorkoutInterpretationService

    static func accountScoped(userId: UUID) -> SQLiteWorkoutLocalStore {
        SQLiteWorkoutLocalStore(path: accountDatabasePath(userId: userId))
    }

    init(
        path: String = SQLiteWorkoutLocalStore.defaultDatabasePath(),
        interpreter: any WorkoutInterpretationService = HeuristicWorkoutInterpretationService()
    ) {
        do {
            database = try SQLiteDatabase(path: path)
            self.interpreter = interpreter
            try Self.migrate(database)
        } catch {
            fatalError("Unable to open Bram workout store: \(error)")
        }
    }

    init(databasePath: String, interpreter: any WorkoutInterpretationService = HeuristicWorkoutInterpretationService()) throws {
        database = try SQLiteDatabase(path: databasePath)
        self.interpreter = interpreter
        try Self.migrate(database)
    }

    private static func accountDatabasePath(userId: UUID) -> String {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bram", isDirectory: true)
            .appendingPathComponent("Accounts", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(userId.uuidString.lowercased()).sqlite").path
    }

    func note(for date: Date) async throws -> DailyWorkoutNote {
        let dayKey = Self.dayKey(for: date)
        let sql = """
        select id, remote_id, user_id, workout_date, timezone_identifier, body,
               created_at, updated_at, deleted_at, sync_state, last_sync_error
        from workout_notes
        where workout_date = ? and deleted_at is null
        limit 1;
        """

        var storedNote: DailyWorkoutNote?
        try database.withStatement(sql) { statement in
            try database.bind(dayKey, to: 1, in: statement)
            if try database.step(statement) {
                storedNote = makeNote(from: statement)
            }
        }

        if var note = storedNote {
            note = await interpreted(note)
            return note
        }

        let note = DailyWorkoutNote(date: date, syncState: .localOnly)
        try saveSync(note)
        return await interpreted(note)
    }

    func trainingGoalsProfile() async throws -> TrainingGoalsProfile {
        try reconciledTrainingGoalsProfileSync()
    }

    func healthDailyMetric(for date: Date) async throws -> HealthDailyMetric? {
        try healthDailyMetricSync(for: date)
    }

    func healthWorkoutSamples(on date: Date) async throws -> [HealthWorkoutSample] {
        try healthWorkoutSamplesSync(on: date)
    }

    func healthWorkoutMatch(for noteId: UUID) async throws -> HealthWorkoutMatch? {
        try healthWorkoutMatchSync(noteId: noteId)
    }

    private func healthWorkoutMatchSync(noteId: UUID) throws -> HealthWorkoutMatch? {
        let sql = """
        select id, note_id, note_date, health_workout_id, match_quality, matched_at
        from health_workout_matches
        where note_id = ?
        limit 1;
        """
        var match: HealthWorkoutMatch?
        try database.withStatement(sql) { statement in
            try database.bind(noteId.uuidString, to: 1, in: statement)
            if try database.step(statement) {
                match = makeHealthWorkoutMatch(from: statement)
            }
        }
        return match
    }

    func calendarWorkoutDays() async throws -> [CalendarWorkoutDay] {
        let sql = """
        select n.workout_date, 1, coalesce(m.pr_count, 0)
        from workout_notes n
        left join workout_daily_metrics m on m.note_id = n.id
        where n.deleted_at is null
          and (
            exists (select 1 from workout_strength_sets s where s.note_id = n.id)
            or exists (select 1 from workout_cardio_entries c where c.note_id = n.id)
          )
        order by n.workout_date asc;
        """

        var days: [CalendarWorkoutDay] = []
        try database.withStatement(sql) { statement in
            while try database.step(statement) {
                guard let dayKey = database.string(at: 0, in: statement),
                      let date = Self.date(from: dayKey)
                else { continue }
                days.append(
                    CalendarWorkoutDay(
                        date: date,
                        isSelected: false,
                        isToday: Calendar.current.isDateInToday(date),
                        hasWorkout: (database.int(at: 1, in: statement) ?? 0) > 0,
                        hadPR: (database.int(at: 2, in: statement) ?? 0) > 0
                    )
                )
            }
        }
        return days
    }

    func statsWeek(containing date: Date) async throws -> StatsWeekSnapshot {
        try await stats(for: .week, containing: date)
    }

    func stats(for period: StatsPeriod, containing date: Date) async throws -> StatsWeekSnapshot {
        let calendar = Calendar.current
        let interval = Self.statsInterval(for: period, containing: date, calendar: calendar)
        let endDate = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        let startKey = Self.dayKey(for: interval.start)
        let endKey = Self.dayKey(for: endDate)
        let previousStart = calendar.date(byAdding: period.calendarComponent, value: -1, to: interval.start) ?? interval.start
        let previousEnd = calendar.date(byAdding: .day, value: -1, to: interval.start) ?? previousStart
        let previousStartKey = Self.dayKey(for: previousStart)
        let previousEndKey = Self.dayKey(for: previousEnd)

        var volumeByDay: [String: Int] = [:]
        var energyByDay: [String: Int] = [:]
        var energyEstimateByDay: [String: Bool] = [:]
        var durationByDay: [String: Int] = [:]
        var heartRateByDay: [String: Int] = [:]
        var workoutDays = Set<String>()
        let metricsSQL = """
        select n.workout_date, m.estimated_volume, m.active_energy_calories,
               coalesce(m.energy_is_estimated, 0), m.workout_duration_minutes, m.average_heart_rate
        from workout_daily_metrics m
        join workout_notes n on n.id = m.note_id
        where n.deleted_at is null
          and n.workout_date between ? and ?
          and (
            exists (select 1 from workout_strength_sets s where s.note_id = n.id)
            or exists (select 1 from workout_cardio_entries c where c.note_id = n.id)
          );
        """
        try database.withStatement(metricsSQL) { statement in
            try database.bind(startKey, to: 1, in: statement)
            try database.bind(endKey, to: 2, in: statement)
            while try database.step(statement) {
                guard let dayKey = database.string(at: 0, in: statement) else { continue }
                volumeByDay[dayKey] = database.int(at: 1, in: statement) ?? 0
                if let energy = database.int(at: 2, in: statement) {
                    energyByDay[dayKey] = energy
                    energyEstimateByDay[dayKey] = (database.int(at: 3, in: statement) ?? 0) > 0
                }
                if let duration = database.int(at: 4, in: statement) {
                    durationByDay[dayKey] = duration
                }
                if let heartRate = database.int(at: 5, in: statement) {
                    heartRateByDay[dayKey] = heartRate
                }
                workoutDays.insert(dayKey)
            }
        }

        var currentSetsByMuscle: [String: Int] = [:]
        var setBreakdownByDay: [String: [String: Int]] = [:]
        let muscleSQL = """
        select n.workout_date, coalesce(s.muscle_group, 'Other'), count(*)
        from workout_strength_sets s
        join workout_notes n on n.id = s.note_id
        where n.deleted_at is null
          and n.workout_date between ? and ?
        group by n.workout_date, coalesce(s.muscle_group, 'Other');
        """
        try database.withStatement(muscleSQL) { statement in
            try database.bind(startKey, to: 1, in: statement)
            try database.bind(endKey, to: 2, in: statement)
            while try database.step(statement) {
                guard let dayKey = database.string(at: 0, in: statement),
                      let muscle = database.string(at: 1, in: statement)
                else { continue }
                let sets = database.int(at: 2, in: statement) ?? 0
                currentSetsByMuscle[muscle, default: 0] += sets
                setBreakdownByDay[dayKey, default: [:]][muscle, default: 0] += sets
            }
        }

        let loadByDay = Self.loadMetrics(
            for: period,
            interval: interval,
            volumeByDay: volumeByDay,
            energyByDay: energyByDay,
            energyEstimateByDay: energyEstimateByDay,
            durationByDay: durationByDay,
            heartRateByDay: heartRateByDay,
            setBreakdownByDay: setBreakdownByDay,
            calendar: calendar
        )
        let setVolume = currentSetsByMuscle
            .sorted { $0.value > $1.value }
            .map { muscle, sets in
                MuscleSetMetric(muscleGroup: muscle, sets: sets, colorRole: Self.colorRole(for: muscle))
            }
        let macroSetVolume = Self.muscleMetrics(from: Self.macroMuscleSets(from: currentSetsByMuscle))
        let previousSetsByMuscle = try setsByMuscle(from: previousStartKey, to: previousEndKey)
        let priorWorkoutDays = try workoutDayCount(from: previousStartKey, to: previousEndKey)
        let prLabels = try prLabels(from: startKey, to: endKey)
        let totalSets = currentSetsByMuscle.values.reduce(0, +)
        let previousTotalSets = previousSetsByMuscle.values.reduce(0, +)
        let setVolumeDelta = totalSets - previousTotalSets
        let goals = (try? reconciledTrainingGoalsProfileSync()) ?? TrainingGoalsProfile()
        let bodyweightTrend = try bodyweightTrend(from: interval.start, to: endDate, goals: goals)
        let streak = currentStreak(from: workoutDays)
        let streakAwards = Self.streakAwards(
            workoutDays: workoutDays.count,
            weeklyTarget: goals.weeklyTrainingDays,
            currentStreak: streak,
            prCount: prLabels.count,
            macroSets: macroSetVolume,
            bodyweightTrend: bodyweightTrend,
            repairCount: streakRepairsAvailable(from: workoutDays)
        )
        let progressSignals = Self.progressSignals(
            prCount: prLabels.count,
            workoutDays: workoutDays.count,
            weeklyTarget: goals.weeklyTrainingDays,
            setVolumeDelta: setVolumeDelta,
            topChangedMuscle: Self.topChangedMuscle(current: Self.macroMuscleSets(from: currentSetsByMuscle), previous: Self.macroMuscleSets(from: previousSetsByMuscle))
        )
        let insight = Self.statsInsight(
            prLabels: prLabels,
            macroSets: macroSetVolume,
            workoutDays: workoutDays.count,
            weeklyTarget: goals.weeklyTrainingDays,
            bodyweightTrend: bodyweightTrend,
            targetWeight: goals.targetWeightValue
        )

        return StatsWeekSnapshot(
            dateRangeTitle: Self.rangeTitle(for: period, start: interval.start, end: endDate),
            loadByDay: loadByDay,
            setVolumeByMuscle: setVolume,
            macroSetVolumeByMuscle: macroSetVolume,
            bodyweightTrend: bodyweightTrend,
            targetWeight: goals.targetWeightValue,
            preferredWeightUnit: goals.preferredUnits.weightUnit,
            prCount: prLabels.count,
            recentPRLabels: Array(prLabels.prefix(3)),
            priorWorkoutDaysInPeriod: priorWorkoutDays,
            setVolumeDelta: setVolumeDelta,
            progressSignals: progressSignals,
            insight: insight,
            currentStreak: streak,
            highestStreak: max(streak, longestStreak(from: workoutDays)),
            streakTitle: Self.streakTitle(workoutDays: workoutDays.count, weeklyTarget: goals.weeklyTrainingDays),
            streakSubtitle: Self.streakSubtitle(workoutDays: workoutDays.count, weeklyTarget: goals.weeklyTrainingDays),
            streakAwards: streakAwards,
            weeklyTarget: goals.weeklyTrainingDays,
            workoutDaysInPeriod: workoutDays.count,
            streakRepairCount: streakRepairsAvailable(from: workoutDays),
            healthMetricsConnected: !energyByDay.isEmpty && energyEstimateByDay.values.contains(false)
        )
    }

    func exerciseHistory(for exercise: ExerciseAnchor) async throws -> ExerciseHistorySummary {
        let sql = """
        select n.workout_date, s.load_value, s.reps, s.estimated_one_rep_max
        from workout_strength_sets s
        join workout_notes n on n.id = s.note_id
        where n.deleted_at is null
          and s.exercise_key = ?
        order by n.workout_date desc, s.estimated_one_rep_max desc;
        """

        var rows: [(date: Date, load: Double, reps: Int, estimatedOneRepMax: Double)] = []
        try database.withStatement(sql) { statement in
            try database.bind(exercise.exerciseKey, to: 1, in: statement)
            while try database.step(statement) {
                guard let dayKey = database.string(at: 0, in: statement),
                      let date = Self.date(from: dayKey),
                      let load = database.double(at: 1, in: statement),
                      let reps = database.int(at: 2, in: statement),
                      let estimated = database.double(at: 3, in: statement)
                else { continue }
                rows.append((date, load, reps, estimated))
            }
        }

        let grouped = Dictionary(grouping: rows) { Self.dayKey(for: $0.date) }
        let sessions = grouped.compactMap { _, rows -> ExerciseHistorySession? in
            guard let best = rows.max(by: { $0.estimatedOneRepMax < $1.estimatedOneRepMax }) else { return nil }
            let volume = rows.reduce(0) { total, row in
                total + Int(row.load) * row.reps
            }
            return ExerciseHistorySession(
                id: UUID(),
                date: best.date,
                bestSetText: "\(Self.loadText(best.load)) x \(best.reps)",
                estimatedOneRepMax: best.estimatedOneRepMax,
                volume: volume
            )
        }
        .sorted { $0.date > $1.date }

        guard !sessions.isEmpty else { return exercise.history }

        let bestSession = sessions.max(by: { $0.estimatedOneRepMax < $1.estimatedOneRepMax })
        let goals = (try? await trainingGoalsProfile()) ?? TrainingGoalsProfile()
        let suggestion = LocalSuggestionEngine.exerciseSuggestion(
            exerciseKey: exercise.exerciseKey,
            sessions: sessions,
            goals: goals
        )
        return ExerciseHistorySummary(
            id: UUID(),
            exerciseKey: exercise.exerciseKey,
            displayName: exercise.displayName,
            estimatedOneRepMax: bestSession?.estimatedOneRepMax,
            bestSetText: bestSession?.bestSetText,
            recentDates: sessions.map(\.date),
            recentSessions: Array(sessions.prefix(8)),
            recommendation: suggestion.text,
            primarySuggestion: suggestion
        )
    }

    func cardioHistory(for activityType: String) async throws -> CardioHistorySummary {
        let sql = """
        select c.id, n.workout_date, c.activity_type, c.duration_minutes,
               c.distance_value, c.distance_unit, c.average_heart_rate,
               c.active_energy_calories
        from workout_cardio_entries c
        join workout_notes n on n.id = c.note_id
        where n.deleted_at is null
          and lower(c.activity_type) = lower(?)
        order by n.workout_date desc, c.line_index desc;
        """

        let goals = (try? await trainingGoalsProfile()) ?? TrainingGoalsProfile()
        var sessions: [CardioHistorySession] = []
        try database.withStatement(sql) { statement in
            try database.bind(activityType, to: 1, in: statement)
            while try database.step(statement) {
                guard let idString = database.string(at: 0, in: statement),
                      let id = UUID(uuidString: idString),
                      let dayKey = database.string(at: 1, in: statement),
                      let date = Self.date(from: dayKey),
                      let activity = database.string(at: 2, in: statement)
                else { continue }

                let duration = database.int(at: 3, in: statement)
                let distance = database.double(at: 4, in: statement)
                let distanceUnit = database.string(at: 5, in: statement)
                let heartRate = database.int(at: 6, in: statement)
                let savedEnergy = database.int(at: 7, in: statement)
                let estimatedEnergy = savedEnergy ?? Self.estimatedCardioCalories(
                    activityType: activity,
                    durationMinutes: duration,
                    goals: goals
                )

                sessions.append(
                    CardioHistorySession(
                        id: id,
                        date: date,
                        activityType: activity,
                        durationMinutes: duration,
                        distance: distance,
                        distanceUnit: distanceUnit,
                        estimatedCalories: estimatedEnergy,
                        averageHeartRate: heartRate
                    )
                )
            }
        }

        guard !sessions.isEmpty else {
            return CardioHistorySummary(activityType: activityType)
        }

        let durations = sessions.compactMap(\.durationMinutes).filter { $0 > 0 }
        let calories = sessions.compactMap(\.estimatedCalories).filter { $0 > 0 }
        let bestDistance = sessions
            .filter { ($0.distance ?? 0) > 0 }
            .max { ($0.distance ?? 0) < ($1.distance ?? 0) }
        let recent = Array(sessions.prefix(8))
        let averageDuration = durations.isEmpty ? nil : Int((Double(durations.reduce(0, +)) / Double(durations.count)).rounded())
        let averageCalories = calories.isEmpty ? nil : Int((Double(calories.reduce(0, +)) / Double(calories.count)).rounded())
        let recommendation = Self.cardioRecommendation(activityType: activityType, sessions: sessions)

        return CardioHistorySummary(
            activityType: activityType,
            recentSessions: recent,
            averageDurationMinutes: averageDuration,
            bestDistanceText: CardioHistorySummary.distanceText(value: bestDistance?.distance, unit: bestDistance?.distanceUnit),
            estimatedCaloriesText: averageCalories.map { "\($0)" } ?? "--",
            recommendation: recommendation
        )
    }

    func save(_ note: DailyWorkoutNote) async throws {
        try saveSync(note)
        var result = await interpreter.interpret(note: note)
        result.metrics = await energyAdjustedMetrics(result.metrics, for: note)
        result = try scorePRsAgainstExerciseHistory(note: note, result: result)
        try saveInterpretation(for: note, result: result)
        try updateBodyweightFromNoteIfNeeded(note)
    }

    func save(_ profile: TrainingGoalsProfile) async throws {
        try saveSync(profile)
        try saveBodyweightObservationIfPresent(profile)
    }

    func onboardingDraft() async throws -> OnboardingDraft {
        try onboardingDraftSync()
    }

    func save(_ draft: OnboardingDraft) async throws {
        try saveSync(draft)
    }

    func clearOnboardingDraft() async throws {
        try database.execute("delete from onboarding_draft where id = 'local';")
    }

    func save(_ metric: HealthDailyMetric) async throws {
        try saveSync(metric)
        try updateBodyweightFromHealthIfNeeded(metric)
    }

    func save(_ workouts: [HealthWorkoutSample]) async throws {
        for workout in workouts {
            try saveSync(workout)
        }
    }

    func save(_ match: HealthWorkoutMatch) async throws {
        try saveSync(match)
    }

    func delete(_ note: DailyWorkoutNote) async throws {
        let sql = """
        update workout_notes
        set deleted_at = ?, sync_state = ?, updated_at = ?
        where id = ?;
        """
        let now = Date()
        try database.withStatement(sql) { statement in
            try database.bind(now, to: 1, in: statement)
            try database.bind(WorkoutSyncState.deleted.rawValue, to: 2, in: statement)
            try database.bind(now, to: 3, in: statement)
            try database.bind(note.id.uuidString, to: 4, in: statement)
            _ = try database.step(statement)
        }
    }

    func pendingWorkoutSyncPayloads(limit: Int = 25) async throws -> [WorkoutSyncPayload] {
        let sql = """
        select id, remote_id, user_id, workout_date, timezone_identifier, body,
               created_at, updated_at, deleted_at, sync_state, last_sync_error
        from workout_notes
        where sync_state <> ?
          and (body <> '' or deleted_at is not null)
        order by updated_at asc
        limit ?;
        """
        var notes: [DailyWorkoutNote] = []
        try database.withStatement(sql) { statement in
            try database.bind(WorkoutSyncState.synced.rawValue, to: 1, in: statement)
            try database.bind(limit, to: 2, in: statement)
            while try database.step(statement) {
                notes.append(makeNote(from: statement))
            }
        }

        return try notes.map { note in
            WorkoutSyncPayload(
                note: note,
                metrics: try workoutMetricSnapshotSync(noteId: note.id),
                strengthSets: try strengthSetsSync(noteId: note.id),
                cardioEntries: try cardioEntriesSync(noteId: note.id),
                prEvents: try prEventsSync(noteId: note.id),
                healthDailyMetric: try healthDailyMetricSync(for: note.date),
                healthWorkoutMatch: try healthWorkoutMatchSync(noteId: note.id)
            )
        }
    }

    func markWorkoutSynced(localNoteId: UUID, remoteId: UUID, userId: UUID) async throws {
        let sql = """
        update workout_notes
        set remote_id = ?, user_id = ?, sync_state = ?, last_sync_error = null
        where id = ?;
        """
        try database.withStatement(sql) { statement in
            try database.bind(remoteId.uuidString, to: 1, in: statement)
            try database.bind(userId.uuidString, to: 2, in: statement)
            try database.bind(WorkoutSyncState.synced.rawValue, to: 3, in: statement)
            try database.bind(localNoteId.uuidString, to: 4, in: statement)
            _ = try database.step(statement)
        }
    }

    func markWorkoutSyncFailed(localNoteId: UUID, errorMessage: String) async throws {
        let sql = """
        update workout_notes
        set sync_state = ?, last_sync_error = ?
        where id = ?;
        """
        try database.withStatement(sql) { statement in
            try database.bind(WorkoutSyncState.failed.rawValue, to: 1, in: statement)
            try database.bind(errorMessage, to: 2, in: statement)
            try database.bind(localNoteId.uuidString, to: 3, in: statement)
            _ = try database.step(statement)
        }
    }

    func clearLocalAccountData() async throws {
        try database.execute("""
        delete from health_workout_matches;
        delete from health_workout_samples;
        delete from health_daily_metrics;
        delete from workout_pr_events;
        delete from workout_cardio_entries;
        delete from workout_strength_sets;
        delete from workout_daily_metrics;
        delete from workout_notes;
        delete from onboarding_draft;
        delete from training_goals_profile;
        """)
    }

    private func saveSync(_ note: DailyWorkoutNote) throws {
        let now = Date()
        let state = note.syncState == .synced ? WorkoutSyncState.pendingUpload : note.syncState
        let sql = """
        insert into workout_notes (
          id, remote_id, user_id, workout_date, timezone_identifier, body,
          created_at, updated_at, deleted_at, sync_state, last_sync_error
        )
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        on conflict(id) do update set
          remote_id = excluded.remote_id,
          user_id = excluded.user_id,
          workout_date = excluded.workout_date,
          timezone_identifier = excluded.timezone_identifier,
          body = excluded.body,
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at,
          sync_state = excluded.sync_state,
          last_sync_error = excluded.last_sync_error;
        """

        try database.withStatement(sql) { statement in
            try database.bind(note.id.uuidString, to: 1, in: statement)
            try database.bind(note.remoteId?.uuidString, to: 2, in: statement)
            try database.bind(note.userId?.uuidString, to: 3, in: statement)
            try database.bind(Self.dayKey(for: note.date), to: 4, in: statement)
            try database.bind(note.timezoneIdentifier, to: 5, in: statement)
            try database.bind(note.body, to: 6, in: statement)
            try database.bind(note.createdAt, to: 7, in: statement)
            try database.bind(now, to: 8, in: statement)
            try database.bind(note.deletedAt, to: 9, in: statement)
            try database.bind(state.rawValue, to: 10, in: statement)
            try database.bind(note.lastSyncError, to: 11, in: statement)
            _ = try database.step(statement)
        }
    }

    private func saveSync(_ profile: TrainingGoalsProfile) throws {
        let profile = profile.sanitized
        let sql = """
        insert into training_goals_profile (
          id, primary_goal, weekly_training_days, session_length_minutes,
          training_styles, equipment, height_value, current_weight_value,
          target_weight_value, current_weight_logged_at, current_weight_source,
          sex, sex_self_description, preferred_units, estimated_daily_calories, updated_at
        )
        values ('local', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        on conflict(id) do update set
          primary_goal = excluded.primary_goal,
          weekly_training_days = excluded.weekly_training_days,
          session_length_minutes = excluded.session_length_minutes,
          training_styles = excluded.training_styles,
          equipment = excluded.equipment,
          height_value = excluded.height_value,
          current_weight_value = excluded.current_weight_value,
          target_weight_value = excluded.target_weight_value,
          current_weight_logged_at = excluded.current_weight_logged_at,
          current_weight_source = excluded.current_weight_source,
          sex = excluded.sex,
          sex_self_description = excluded.sex_self_description,
          preferred_units = excluded.preferred_units,
          estimated_daily_calories = excluded.estimated_daily_calories,
          updated_at = excluded.updated_at;
        """

        try database.withStatement(sql) { statement in
            try database.bind(profile.primaryGoal.rawValue, to: 1, in: statement)
            try database.bind(profile.weeklyTrainingDays, to: 2, in: statement)
            try database.bind(profile.sessionLengthMinutes, to: 3, in: statement)
            try database.bind(Self.encodeSet(profile.trainingStyles), to: 4, in: statement)
            try database.bind(Self.encodeSet(profile.equipment), to: 5, in: statement)
            try database.bind(profile.heightValue, to: 6, in: statement)
            try database.bind(profile.currentWeightValue, to: 7, in: statement)
            try database.bind(profile.targetWeightValue, to: 8, in: statement)
            try database.bind(profile.currentWeightLoggedAt, to: 9, in: statement)
            try database.bind(profile.currentWeightSource?.rawValue, to: 10, in: statement)
            try database.bind(profile.sex?.rawValue, to: 11, in: statement)
            try database.bind(profile.sexSelfDescription.nilIfEmpty, to: 12, in: statement)
            try database.bind(profile.preferredUnits.rawValue, to: 13, in: statement)
            try database.bind(profile.estimatedDailyCalories, to: 14, in: statement)
            try database.bind(profile.updatedAt, to: 15, in: statement)
            _ = try database.step(statement)
        }
    }

    private func onboardingDraftSync() throws -> OnboardingDraft {
        let sql = """
        select first_name, current_step, updated_at
        from onboarding_draft
        where id = 'local'
        limit 1;
        """

        var draft: OnboardingDraft?
        try database.withStatement(sql) { statement in
            if try database.step(statement) {
                draft = OnboardingDraft(
                    firstName: database.string(at: 0, in: statement) ?? "",
                    step: database.int(at: 1, in: statement).flatMap(OnboardingStep.init(rawValue:)) ?? .name,
                    updatedAt: database.date(at: 2, in: statement) ?? .now
                )
            }
        }

        return draft ?? OnboardingDraft()
    }

    private func saveSync(_ draft: OnboardingDraft) throws {
        let draft = draft.sanitized
        let sql = """
        insert into onboarding_draft (
          id, first_name, current_step, updated_at
        )
        values ('local', ?, ?, ?)
        on conflict(id) do update set
          first_name = excluded.first_name,
          current_step = excluded.current_step,
          updated_at = excluded.updated_at;
        """

        try database.withStatement(sql) { statement in
            try database.bind(draft.firstName, to: 1, in: statement)
            try database.bind(draft.step.rawValue, to: 2, in: statement)
            try database.bind(draft.updatedAt, to: 3, in: statement)
            _ = try database.step(statement)
        }
    }

    private func updateBodyweightFromNoteIfNeeded(_ note: DailyWorkoutNote) throws {
        var profile = try trainingGoalsProfileSync()
        guard let observation = BodyweightNoteExtractor.extract(from: note, existingWeight: profile.currentWeightValue),
              shouldReplaceBodyweight(currentLoggedAt: profile.currentWeightLoggedAt, candidateLoggedAt: observation.loggedAt)
        else { return }

        profile.currentWeightValue = observation.value
        profile.currentWeightLoggedAt = observation.loggedAt
        profile.currentWeightSource = observation.source
        try saveSync(profile)
        try saveBodyweightObservation(observation)
    }

    private func updateBodyweightFromHealthIfNeeded(_ metric: HealthDailyMetric) throws {
        guard let bodyweight = metric.bodyweightValue else { return }
        var profile = try reconciledTrainingGoalsProfileSync()
        guard shouldReplaceBodyweight(currentLoggedAt: profile.currentWeightLoggedAt, candidateLoggedAt: metric.date) else { return }

        profile.currentWeightValue = bodyweight
        profile.currentWeightLoggedAt = metric.date
        profile.currentWeightSource = .appleHealth
        try saveSync(profile)
    }

    private func shouldReplaceBodyweight(currentLoggedAt: Date?, candidateLoggedAt: Date) -> Bool {
        guard let currentLoggedAt else { return true }
        return candidateLoggedAt >= currentLoggedAt
    }

    private func reconciledTrainingGoalsProfileSync() throws -> TrainingGoalsProfile {
        var profile = try trainingGoalsProfileSync()
        guard let latestHealthBodyweight = try latestHealthBodyweightObservation(),
              shouldReplaceBodyweight(currentLoggedAt: profile.currentWeightLoggedAt, candidateLoggedAt: latestHealthBodyweight.loggedAt)
        else { return profile }

        profile.currentWeightValue = latestHealthBodyweight.value
        profile.currentWeightLoggedAt = latestHealthBodyweight.loggedAt
        profile.currentWeightSource = latestHealthBodyweight.source
        try saveSync(profile)
        return profile
    }

    private func latestHealthBodyweightObservation() throws -> BodyweightObservation? {
        let sql = """
        select metric_date, bodyweight_value, bodyweight_unit
        from health_daily_metrics
        where bodyweight_value is not null
        order by metric_date desc
        limit 1;
        """
        var observation: BodyweightObservation?
        try database.withStatement(sql) { statement in
            if try database.step(statement),
               let dayKey = database.string(at: 0, in: statement),
               let date = Self.date(from: dayKey),
               let value = database.double(at: 1, in: statement) {
                observation = BodyweightObservation(
                    value: value,
                    unit: database.string(at: 2, in: statement) ?? "lb",
                    loggedAt: date,
                    source: .appleHealth
                )
            }
        }
        return observation
    }

    private func saveBodyweightObservationIfPresent(_ profile: TrainingGoalsProfile) throws {
        guard let value = profile.currentWeightValue,
              let loggedAt = profile.currentWeightLoggedAt
        else { return }
        try saveBodyweightObservation(
            BodyweightObservation(
                value: value,
                unit: profile.preferredUnits.weightUnit,
                loggedAt: loggedAt,
                source: profile.currentWeightSource ?? .manual
            )
        )
    }

    private func saveBodyweightObservation(_ observation: BodyweightObservation) throws {
        let sql = """
        insert into health_daily_metrics (
          metric_date, bodyweight_value, bodyweight_unit, source, updated_at
        )
        values (?, ?, ?, ?, ?)
        on conflict(metric_date) do update set
          bodyweight_value = excluded.bodyweight_value,
          bodyweight_unit = excluded.bodyweight_unit,
          source = excluded.source,
          updated_at = excluded.updated_at;
        """
        try database.withStatement(sql) { statement in
            try database.bind(Self.dayKey(for: observation.loggedAt), to: 1, in: statement)
            try database.bind(observation.value, to: 2, in: statement)
            try database.bind(observation.unit, to: 3, in: statement)
            try database.bind(observation.source.rawValue, to: 4, in: statement)
            try database.bind(observation.loggedAt, to: 5, in: statement)
            _ = try database.step(statement)
        }
    }

    private func trainingGoalsProfileSync() throws -> TrainingGoalsProfile {
        let sql = """
        select primary_goal, weekly_training_days, session_length_minutes,
               training_styles, equipment, height_value, current_weight_value,
               target_weight_value, current_weight_logged_at, current_weight_source,
               sex, sex_self_description, preferred_units, estimated_daily_calories, updated_at
        from training_goals_profile
        where id = 'local'
        limit 1;
        """

        var profile: TrainingGoalsProfile?
        try database.withStatement(sql) { statement in
            if try database.step(statement) {
                profile = makeTrainingGoalsProfile(from: statement)
            }
        }

        if let profile { return profile }
        let defaultProfile = TrainingGoalsProfile()
        try saveSync(defaultProfile)
        return defaultProfile
    }

    private func saveSync(_ metric: HealthDailyMetric) throws {
        let sql = """
        insert into health_daily_metrics (
          metric_date, active_energy_calories, average_heart_rate, max_heart_rate,
          bodyweight_value, bodyweight_unit, workout_duration_minutes, source, updated_at
        )
        values (?, ?, ?, ?, ?, ?, ?, ?, ?)
        on conflict(metric_date) do update set
          active_energy_calories = excluded.active_energy_calories,
          average_heart_rate = excluded.average_heart_rate,
          max_heart_rate = excluded.max_heart_rate,
          bodyweight_value = excluded.bodyweight_value,
          bodyweight_unit = excluded.bodyweight_unit,
          workout_duration_minutes = excluded.workout_duration_minutes,
          source = excluded.source,
          updated_at = excluded.updated_at;
        """
        try database.withStatement(sql) { statement in
            try database.bind(Self.dayKey(for: metric.date), to: 1, in: statement)
            try database.bind(metric.activeEnergyCalories, to: 2, in: statement)
            try database.bind(metric.averageHeartRate, to: 3, in: statement)
            try database.bind(metric.maxHeartRate, to: 4, in: statement)
            try database.bind(metric.bodyweightValue, to: 5, in: statement)
            try database.bind(metric.bodyweightUnit, to: 6, in: statement)
            try database.bind(metric.workoutDurationMinutes, to: 7, in: statement)
            try database.bind(metric.source, to: 8, in: statement)
            try database.bind(metric.updatedAt, to: 9, in: statement)
            _ = try database.step(statement)
        }
    }

    private func saveSync(_ workout: HealthWorkoutSample) throws {
        let sql = """
        insert into health_workout_samples (
          health_workout_id, activity_type, start_date, end_date, duration_minutes,
          active_energy_calories, distance_value, distance_unit, average_heart_rate, max_heart_rate
        )
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        on conflict(health_workout_id) do update set
          activity_type = excluded.activity_type,
          start_date = excluded.start_date,
          end_date = excluded.end_date,
          duration_minutes = excluded.duration_minutes,
          active_energy_calories = excluded.active_energy_calories,
          distance_value = excluded.distance_value,
          distance_unit = excluded.distance_unit,
          average_heart_rate = excluded.average_heart_rate,
          max_heart_rate = excluded.max_heart_rate;
        """
        try database.withStatement(sql) { statement in
            try database.bind(workout.healthWorkoutId, to: 1, in: statement)
            try database.bind(workout.activityType, to: 2, in: statement)
            try database.bind(workout.startDate, to: 3, in: statement)
            try database.bind(workout.endDate, to: 4, in: statement)
            try database.bind(workout.durationMinutes, to: 5, in: statement)
            try database.bind(workout.activeEnergyCalories, to: 6, in: statement)
            try database.bind(workout.distanceValue, to: 7, in: statement)
            try database.bind(workout.distanceUnit, to: 8, in: statement)
            try database.bind(workout.averageHeartRate, to: 9, in: statement)
            try database.bind(workout.maxHeartRate, to: 10, in: statement)
            _ = try database.step(statement)
        }
    }

    private func saveSync(_ match: HealthWorkoutMatch) throws {
        let sql = """
        insert into health_workout_matches (
          id, note_id, note_date, health_workout_id, match_quality, matched_at
        )
        values (?, ?, ?, ?, ?, ?)
        on conflict(note_id) do update set
          health_workout_id = excluded.health_workout_id,
          match_quality = excluded.match_quality,
          matched_at = excluded.matched_at;
        """
        try database.withStatement(sql) { statement in
            try database.bind(match.id.uuidString, to: 1, in: statement)
            try database.bind(match.noteId.uuidString, to: 2, in: statement)
            try database.bind(Self.dayKey(for: match.noteDate), to: 3, in: statement)
            try database.bind(match.healthWorkoutId, to: 4, in: statement)
            try database.bind(match.matchQuality.rawValue, to: 5, in: statement)
            try database.bind(match.matchedAt, to: 6, in: statement)
            _ = try database.step(statement)
        }
    }

    private func scorePRsAgainstExerciseHistory(note: DailyWorkoutNote, result: WorkoutInterpretationResult) throws -> WorkoutInterpretationResult {
        var output = result
        let candidateSets = bestCurrentSetsByExercise(result.strengthSets)
        var prSets: [StrengthSetRecord] = []
        for set in candidateSets {
            guard set.load > 0 else { continue }
            guard let previousBest = try historicalEstimatedOneRepMax(for: set.exerciseKey, excluding: note.id) else {
                prSets.append(set)
                continue
            }
            if set.estimatedOneRepMax > previousBest {
                prSets.append(set)
            }
        }

        let prSetIds = Set(prSets.map(\.id))
        output.prEvents = prSets.map { set in
            WorkoutPREvent(
                id: UUID(),
                noteId: note.id,
                exerciseName: set.exerciseName,
                kind: PRKind.estimatedOneRepMax.rawValue,
                value: set.estimatedOneRepMax,
                unit: set.unit,
                achievedAt: set.performedAt
            )
        }
        output.metrics.prCount = output.prEvents.count
        output.lines = linesByApplyingHistoricalPRBadges(lines: output.lines, sets: output.strengthSets, prSetIds: prSetIds)
        output.suggestion = suggestionByApplyingHistoricalPRs(output.suggestion, prCount: output.metrics.prCount)
        return output
    }

    private func bestCurrentSetsByExercise(_ sets: [StrengthSetRecord]) -> [StrengthSetRecord] {
        Dictionary(grouping: sets, by: \.exerciseKey).compactMap { _, sets in
            sets.max(by: { $0.estimatedOneRepMax < $1.estimatedOneRepMax })
        }
    }

    private func historicalEstimatedOneRepMax(for exerciseKey: String, excluding noteId: UUID) throws -> Double? {
        let sql = """
        select max(estimated_one_rep_max)
        from workout_strength_sets
        where exercise_key = ?
          and note_id <> ?;
        """
        var best: Double?
        try database.withStatement(sql) { statement in
            try database.bind(exerciseKey, to: 1, in: statement)
            try database.bind(noteId.uuidString, to: 2, in: statement)
            if try database.step(statement) {
                best = database.double(at: 0, in: statement)
            }
        }
        return best
    }

    private func linesByApplyingHistoricalPRBadges(
        lines: [InterpretedWorkoutLine],
        sets: [StrengthSetRecord],
        prSetIds: Set<UUID>
    ) -> [InterpretedWorkoutLine] {
        let prLineIndexes = Set(sets.filter { prSetIds.contains($0.id) }.compactMap(\.lineIndex))
        let prExerciseKeysByLine = sets
            .filter { prSetIds.contains($0.id) }
            .reduce(into: [Int: String]()) { result, set in
                guard let lineIndex = set.lineIndex else { return }
                result[lineIndex] = set.exerciseKey
            }

        return lines.map { line in
            var cleaned = line
            cleaned.badges.removeAll { $0.kind == .pr }
            cleaned.segments.removeAll { $0.kind == .badge && $0.text == "PR" }
            if cleaned.chipText == "PR" {
                cleaned.chipText = ""
            }

            guard prLineIndexes.contains(line.lineIndex) else { return cleaned }
            let exerciseKey = prExerciseKeysByLine[line.lineIndex] ?? line.exerciseAnchor?.exerciseKey
            let badge = WorkoutLineBadge(kind: .pr, label: "PR", colorRole: .violet)
            cleaned.badges.append(badge)
            cleaned.segments.append(InterpretedLineSegment(kind: .badge, text: badge.label, exerciseKey: exerciseKey))
            cleaned.chipText = "PR"
            return cleaned
        }
    }

    private func suggestionByApplyingHistoricalPRs(_ suggestion: WorkoutSuggestion?, prCount: Int) -> WorkoutSuggestion? {
        if prCount > 0 {
            return WorkoutSuggestion(kind: .progression, text: "Nice record. Keep the next session steady before pushing load again.")
        }
        guard suggestion?.kind == .progression else { return suggestion }
        return nil
    }

    private func saveInterpretation(for note: DailyWorkoutNote, result: WorkoutInterpretationResult) throws {
        try deleteStructuredWorkoutRows(noteId: note.id)
        try saveDailyMetrics(noteId: note.id, metrics: result.metrics)
        try saveStrengthSets(noteId: note.id, sets: result.strengthSets)
        try saveCardioEntries(noteId: note.id, entries: result.cardioEntries)
        try savePREvents(noteId: note.id, events: result.prEvents)
    }

    private func deleteStructuredWorkoutRows(noteId: UUID) throws {
        for table in ["workout_strength_sets", "workout_cardio_entries", "workout_pr_events"] {
            try database.withStatement("delete from \(table) where note_id = ?;") { statement in
                try database.bind(noteId.uuidString, to: 1, in: statement)
                _ = try database.step(statement)
            }
        }
    }

    private func saveDailyMetrics(noteId: UUID, metrics: WorkoutMetricSnapshot) throws {
        let sql = """
        insert into workout_daily_metrics (
          note_id, total_sets, hard_sets, estimated_volume, pr_count,
          cardio_minutes, active_energy_calories, energy_is_estimated,
          average_heart_rate, workout_duration_minutes, updated_at
        )
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        on conflict(note_id) do update set
          total_sets = excluded.total_sets,
          hard_sets = excluded.hard_sets,
          estimated_volume = excluded.estimated_volume,
          pr_count = excluded.pr_count,
          cardio_minutes = excluded.cardio_minutes,
          active_energy_calories = excluded.active_energy_calories,
          energy_is_estimated = excluded.energy_is_estimated,
          average_heart_rate = excluded.average_heart_rate,
          workout_duration_minutes = excluded.workout_duration_minutes,
          updated_at = excluded.updated_at;
        """
        try database.withStatement(sql) { statement in
            try database.bind(noteId.uuidString, to: 1, in: statement)
            try database.bind(metrics.totalSets, to: 2, in: statement)
            try database.bind(metrics.hardSets, to: 3, in: statement)
            try database.bind(metrics.estimatedVolume, to: 4, in: statement)
            try database.bind(metrics.prCount, to: 5, in: statement)
            try database.bind(metrics.cardioMinutes, to: 6, in: statement)
            try database.bind(metrics.activeEnergyCalories, to: 7, in: statement)
            try database.bind(metrics.energyIsEstimated ? 1 : 0, to: 8, in: statement)
            try database.bind(metrics.averageHeartRate, to: 9, in: statement)
            try database.bind(metrics.workoutDurationMinutes, to: 10, in: statement)
            try database.bind(Date(), to: 11, in: statement)
            _ = try database.step(statement)
        }
    }

    private func saveStrengthSets(noteId: UUID, sets: [StrengthSetRecord]) throws {
        let sql = """
        insert into workout_strength_sets (
          id, note_id, exercise_key, exercise_name, muscle_group, line_index,
          set_number, reps, load_value, load_unit, estimated_one_rep_max, performed_at
        )
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        for set in sets {
            try database.withStatement(sql) { statement in
                try database.bind(set.id.uuidString, to: 1, in: statement)
                try database.bind(noteId.uuidString, to: 2, in: statement)
                try database.bind(set.exerciseKey, to: 3, in: statement)
                try database.bind(set.exerciseName, to: 4, in: statement)
                try database.bind(Self.muscleGroup(for: set.exerciseKey), to: 5, in: statement)
                try database.bind(set.lineIndex, to: 6, in: statement)
                try database.bind(set.setNumber, to: 7, in: statement)
                try database.bind(set.reps, to: 8, in: statement)
                try database.bind(set.load, to: 9, in: statement)
                try database.bind(set.unit, to: 10, in: statement)
                try database.bind(set.estimatedOneRepMax, to: 11, in: statement)
                try database.bind(set.performedAt, to: 12, in: statement)
                _ = try database.step(statement)
            }
        }
    }

    private func saveCardioEntries(noteId: UUID, entries: [CardioEntry]) throws {
        let sql = """
        insert into workout_cardio_entries (
          id, note_id, line_index, session_index, session_name, activity_type,
          duration_minutes, distance_value, distance_unit, average_heart_rate,
          active_energy_calories
        )
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        for entry in entries {
            try database.withStatement(sql) { statement in
                try database.bind(entry.id.uuidString, to: 1, in: statement)
                try database.bind(noteId.uuidString, to: 2, in: statement)
                try database.bind(entry.lineIndex, to: 3, in: statement)
                try database.bind(entry.sessionIndex, to: 4, in: statement)
                try database.bind(entry.sessionName, to: 5, in: statement)
                try database.bind(entry.activityType, to: 6, in: statement)
                try database.bind(entry.durationMinutes, to: 7, in: statement)
                try database.bind(entry.distance, to: 8, in: statement)
                try database.bind(entry.distanceUnit, to: 9, in: statement)
                try database.bind(entry.averageHeartRate, to: 10, in: statement)
                try database.bind(entry.activeEnergyCalories, to: 11, in: statement)
                _ = try database.step(statement)
            }
        }
    }

    private func savePREvents(noteId: UUID, events: [WorkoutPREvent]) throws {
        let sql = """
        insert into workout_pr_events (id, note_id, exercise_name, kind, value, unit, achieved_at)
        values (?, ?, ?, ?, ?, ?, ?);
        """
        for event in events {
            try database.withStatement(sql) { statement in
                try database.bind(event.id.uuidString, to: 1, in: statement)
                try database.bind(noteId.uuidString, to: 2, in: statement)
                try database.bind(event.exerciseName, to: 3, in: statement)
                try database.bind(event.kind, to: 4, in: statement)
                try database.bind(event.value, to: 5, in: statement)
                try database.bind(event.unit, to: 6, in: statement)
                try database.bind(event.achievedAt, to: 7, in: statement)
                _ = try database.step(statement)
            }
        }
    }

    private func currentStreak(from workoutDays: Set<String>) -> Int {
        var streak = 0
        var cursor = workoutDays.compactMap(Self.date(from:)).max() ?? Date()
        while workoutDays.contains(Self.dayKey(for: cursor)) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private func longestStreak(from workoutDays: Set<String>) -> Int {
        let dates = workoutDays.compactMap(Self.date(from:)).sorted()
        guard !dates.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for pair in zip(dates, dates.dropFirst()) {
            let gap = Calendar.current.dateComponents([.day], from: pair.0, to: pair.1).day ?? 0
            if gap == 1 {
                current += 1
            } else {
                longest = max(longest, current)
                current = 1
            }
        }
        return max(longest, current)
    }

    private func streakRepairsAvailable(from workoutDays: Set<String>) -> Int {
        let dates = workoutDays.compactMap(Self.date(from:)).sorted()
        guard dates.count >= 2 else { return 0 }
        return zip(dates, dates.dropFirst()).reduce(0) { count, pair in
            let gap = Calendar.current.dateComponents([.day], from: pair.0, to: pair.1).day ?? 0
            return count + (gap == 2 ? 1 : 0)
        }
    }

    private func workoutDayCount(from startKey: String, to endKey: String) throws -> Int {
        let sql = """
        select count(distinct n.workout_date)
        from workout_notes n
        where n.deleted_at is null
          and n.workout_date between ? and ?
          and (
            exists (select 1 from workout_strength_sets s where s.note_id = n.id)
            or exists (select 1 from workout_cardio_entries c where c.note_id = n.id)
          );
        """
        var count = 0
        try database.withStatement(sql) { statement in
            try database.bind(startKey, to: 1, in: statement)
            try database.bind(endKey, to: 2, in: statement)
            if try database.step(statement) {
                count = database.int(at: 0, in: statement) ?? 0
            }
        }
        return count
    }

    private func setsByMuscle(from startKey: String, to endKey: String) throws -> [String: Int] {
        let sql = """
        select coalesce(s.muscle_group, 'Other'), count(*)
        from workout_strength_sets s
        join workout_notes n on n.id = s.note_id
        where n.deleted_at is null
          and n.workout_date between ? and ?
        group by coalesce(s.muscle_group, 'Other');
        """
        var setsByMuscle: [String: Int] = [:]
        try database.withStatement(sql) { statement in
            try database.bind(startKey, to: 1, in: statement)
            try database.bind(endKey, to: 2, in: statement)
            while try database.step(statement) {
                guard let muscle = database.string(at: 0, in: statement) else { continue }
                setsByMuscle[muscle] = database.int(at: 1, in: statement) ?? 0
            }
        }
        return setsByMuscle
    }

    private func prLabels(from startKey: String, to endKey: String) throws -> [String] {
        let sql = """
        select p.exercise_name
        from workout_pr_events p
        join workout_notes n on n.id = p.note_id
        where n.deleted_at is null
          and n.workout_date between ? and ?
        order by p.achieved_at desc;
        """
        var labels: [String] = []
        try database.withStatement(sql) { statement in
            try database.bind(startKey, to: 1, in: statement)
            try database.bind(endKey, to: 2, in: statement)
            while try database.step(statement) {
                if let name = database.string(at: 0, in: statement), !name.isEmpty {
                    labels.append(name)
                }
            }
        }
        return labels
    }

    private static func colorRole(for muscle: String) -> MetricColorRole {
        switch muscle.lowercased() {
        case "chest":
            .chest
        case "legs":
            .legs
        case "back":
            .back
        case "shoulders":
            .shoulders
        case "abs":
            .abs
        case "biceps":
            .biceps
        case "triceps":
            .triceps
        case "forearms":
            .forearms
        case "quads":
            .quads
        case "hamstrings":
            .hamstrings
        case "glutes":
            .glutes
        case "calves":
            .calves
        case "lats":
            .lats
        case "traps":
            .traps
        case "rhomboids":
            .rhomboids
        case "erectors":
            .erectors
        case "arms":
            .biceps
        case "other":
            .other
        default:
            .violet
        }
    }

    private static func macroMuscleSets(from detailedSets: [String: Int]) -> [String: Int] {
        detailedSets.reduce(into: [String: Int]()) { result, item in
            result[macroMuscleGroup(for: item.key), default: 0] += item.value
        }
    }

    private static func macroMuscleGroup(for muscle: String) -> String {
        switch muscle.lowercased() {
        case "biceps", "triceps", "forearms", "arms":
            "Arms"
        case "quads", "hamstrings", "glutes", "calves", "legs":
            "Legs"
        case "lats", "traps", "rhomboids", "erectors", "back":
            "Back"
        case "chest":
            "Chest"
        case "shoulders":
            "Shoulders"
        case "abs":
            "Abs"
        default:
            muscle
        }
    }

    private static func topChangedMuscle(current: [String: Int], previous: [String: Int]) -> (muscle: String, delta: Int)? {
        let muscles = Set(current.keys).union(previous.keys)
        return muscles
            .map { muscle in (muscle, current[muscle, default: 0] - previous[muscle, default: 0]) }
            .filter { $0.1 != 0 }
            .max { abs($0.1) < abs($1.1) }
    }

    private static func progressSignals(
        prCount: Int,
        workoutDays: Int,
        weeklyTarget: Int,
        setVolumeDelta: Int,
        topChangedMuscle: (muscle: String, delta: Int)?
    ) -> [ProgressSignal] {
        var signals = [
            ProgressSignal(label: "PRs", value: "\(prCount)", colorRole: prCount > 0 ? .violet : .other),
            ProgressSignal(label: "Workouts", value: "\(workoutDays)/\(weeklyTarget)", colorRole: workoutDays >= weeklyTarget ? .recovery : .violet)
        ]
        if let topChangedMuscle {
            let sign = topChangedMuscle.delta > 0 ? "+" : ""
            signals.append(
                ProgressSignal(
                    label: topChangedMuscle.muscle,
                    value: "\(sign)\(topChangedMuscle.delta) sets",
                    colorRole: colorRole(for: topChangedMuscle.muscle)
                )
            )
        } else if setVolumeDelta != 0 {
            let sign = setVolumeDelta > 0 ? "+" : ""
            signals.append(ProgressSignal(label: "Sets", value: "\(sign)\(setVolumeDelta)", colorRole: .cool))
        }
        return signals
    }

    private static func statsInsight(
        prLabels: [String],
        macroSets: [MuscleSetMetric],
        workoutDays: Int,
        weeklyTarget: Int,
        bodyweightTrend: [BodyweightTrendPoint],
        targetWeight: Double?
    ) -> StatsInsight? {
        if let firstPR = prLabels.first {
            let extra = prLabels.count > 1 ? " and \(prLabels.count - 1) more" : ""
            return StatsInsight(
                kind: .progression,
                text: "\(firstPR)\(extra) moved up this period; keep the next session steady before pushing again.",
                colorRole: .violet
            )
        }

        if let topMuscle = macroSets.max(by: { $0.sets < $1.sets }),
           topMuscle.sets >= 10,
           let lowMuscle = macroSets.filter({ $0.sets > 0 }).min(by: { $0.sets < $1.sets }),
           topMuscle.sets - lowMuscle.sets >= 6 {
            return StatsInsight(
                kind: .balance,
                text: "\(topMuscle.muscleGroup) is carrying this period; add 2-3 \(lowMuscle.muscleGroup.lowercased()) sets if recovery feels normal.",
                colorRole: topMuscle.colorRole
            )
        }

        if workoutDays > 0 && workoutDays < weeklyTarget {
            let remaining = weeklyTarget - workoutDays
            return StatsInsight(
                kind: .consistency,
                text: "You hit \(workoutDays) of \(weeklyTarget) planned sessions; \(remaining) more keeps this period on target.",
                colorRole: .violet
            )
        }

        if let targetWeight,
           let first = bodyweightTrend.first?.value,
           let latest = bodyweightTrend.last?.value,
           bodyweightTrend.count >= 2 {
            let movedTowardTarget = abs(latest - targetWeight) < abs(first - targetWeight)
            return StatsInsight(
                kind: .bodyweight,
                text: movedTowardTarget ? "Bodyweight is moving toward target; keep logging it weekly." : "Bodyweight is holding steady; keep logging before changing the plan.",
                colorRole: movedTowardTarget ? .recovery : .cool
            )
        }

        return nil
    }

    private static func streakTitle(workoutDays: Int, weeklyTarget: Int) -> String {
        if workoutDays >= weeklyTarget {
            return "On track"
        }
        if workoutDays > 0 {
            return "Keep the week alive"
        }
        return "Start the week"
    }

    private static func streakSubtitle(workoutDays: Int, weeklyTarget: Int) -> String {
        let remaining = max(weeklyTarget - workoutDays, 0)
        if remaining == 0 {
            return "\(workoutDays) of \(weeklyTarget) workouts logged. Planned rest days stay neutral."
        }
        if workoutDays == 0 {
            return "\(weeklyTarget) workouts keeps this week on target."
        }
        return "\(remaining) more workout\(remaining == 1 ? "" : "s") keeps this week on target."
    }

    private static func streakAwards(
        workoutDays: Int,
        weeklyTarget: Int,
        currentStreak: Int,
        prCount: Int,
        macroSets: [MuscleSetMetric],
        bodyweightTrend: [BodyweightTrendPoint],
        repairCount: Int
    ) -> [StreakAward] {
        let trainedGroups = macroSets.filter { $0.sets > 0 }.count
        return [
            StreakAward(
                title: "On Track",
                subtitle: "\(workoutDays)/\(weeklyTarget) workouts",
                systemImage: "target",
                colorRole: workoutDays >= weeklyTarget ? .recovery : .violet,
                isUnlocked: workoutDays >= weeklyTarget
            ),
            StreakAward(
                title: "Record Spark",
                subtitle: prCount == 1 ? "1 PR hit" : "\(prCount) PRs hit",
                systemImage: "sparkles",
                colorRole: .violet,
                isUnlocked: prCount > 0
            ),
            StreakAward(
                title: "Balanced Build",
                subtitle: "\(trainedGroups) muscle groups",
                systemImage: "scale.3d",
                colorRole: .cool,
                isUnlocked: trainedGroups >= 3
            ),
            StreakAward(
                title: "Weight Logged",
                subtitle: bodyweightTrend.isEmpty ? "No check-in yet" : "Bodyweight check-in",
                systemImage: "scalemass",
                colorRole: .recovery,
                isUnlocked: !bodyweightTrend.isEmpty
            ),
            StreakAward(
                title: "Comeback Ready",
                subtitle: repairCount == 0 ? "No repair needed" : "\(repairCount) repair\(repairCount == 1 ? "" : "s") available",
                systemImage: repairCount == 0 ? "checkmark.seal" : "bandage.fill",
                colorRole: repairCount == 0 ? .recovery : .energy,
                isUnlocked: repairCount > 0 || currentStreak > 0
            )
        ]
    }

    private static func muscleGroup(for exerciseKey: String) -> String? {
        if exerciseKey.contains("crunch") || exerciseKey.contains("ab") || exerciseKey.contains("plank") || exerciseKey.contains("sit_up") || exerciseKey.contains("leg_raise") { return "Abs" }
        if exerciseKey.contains("calf") { return "Calves" }
        if exerciseKey.contains("rdl") || exerciseKey.contains("deadlift") || exerciseKey.contains("leg_curl") || exerciseKey.contains("nordic") { return "Hamstrings" }
        if exerciseKey.contains("glute") || exerciseKey.contains("hip_thrust") { return "Glutes" }
        if exerciseKey.contains("quad") || exerciseKey.contains("sissy") || exerciseKey.contains("leg_extension") { return "Quads" }
        if exerciseKey.contains("squat") || exerciseKey.contains("leg") { return "Legs" }
        if exerciseKey.contains("forearm") || exerciseKey.contains("wrist") || exerciseKey.contains("grip") { return "Forearms" }
        if exerciseKey.contains("tricep") || exerciseKey.contains("triceps") || exerciseKey.contains("dip") || exerciseKey.contains("pushdown") { return "Triceps" }
        if exerciseKey.contains("curl") || exerciseKey.contains("preacher") || exerciseKey.contains("bicep") || exerciseKey.contains("biceps") { return "Biceps" }
        if exerciseKey.contains("delt") || exerciseKey.contains("lateral_raise") || exerciseKey.contains("shoulder") { return "Shoulders" }
        if exerciseKey.contains("bench") || exerciseKey.contains("chest") || exerciseKey.contains("fly") || exerciseKey.contains("press") { return "Chest" }
        if exerciseKey.contains("lat") || exerciseKey.contains("pulldown") || exerciseKey.contains("row") { return "Lats" }
        if exerciseKey.contains("trap") || exerciseKey.contains("shrug") { return "Traps" }
        if exerciseKey.contains("erector") || exerciseKey.contains("back_extension") { return "Erectors" }
        if exerciseKey.contains("pullup") || exerciseKey.contains("pullover") { return "Back" }
        return nil
    }

    private func bodyweightTrend(from start: Date, to end: Date, goals: TrainingGoalsProfile) throws -> [BodyweightTrendPoint] {
        let trendStart = min(start, Calendar.current.date(byAdding: .day, value: -90, to: end) ?? start)
        let sql = """
        select metric_date, bodyweight_value, source
        from health_daily_metrics
        where bodyweight_value is not null
          and metric_date between ? and ?
        order by metric_date asc;
        """
        var points: [BodyweightTrendPoint] = []
        try database.withStatement(sql) { statement in
            try database.bind(Self.dayKey(for: trendStart), to: 1, in: statement)
            try database.bind(Self.dayKey(for: end), to: 2, in: statement)
            while try database.step(statement) {
                guard let dayKey = database.string(at: 0, in: statement),
                      let date = Self.date(from: dayKey),
                      let value = database.double(at: 1, in: statement)
                else { continue }
                let source = database.string(at: 2, in: statement).flatMap(BodyweightSource.init(rawValue:)) ?? .appleHealth
                points.append(BodyweightTrendPoint(date: date, value: value, source: source))
            }
        }

        if let value = goals.currentWeightValue {
            let loggedAt = goals.currentWeightLoggedAt ?? points.last?.date ?? Date()
            if !points.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: loggedAt) && abs($0.value - value) < 0.05 }) {
                points.append(
                    BodyweightTrendPoint(
                        date: loggedAt,
                        value: value,
                        source: goals.currentWeightSource ?? .manual
                    )
                )
            }
        }

        return points.sorted { $0.date < $1.date }
    }

    private static func loadText(_ load: Double) -> String {
        guard load > 0 else { return "BW" }
        return load.rounded() == load ? "\(Int(load))" : String(format: "%.1f", load)
    }

    private static func estimatedCardioCalories(
        activityType: String,
        durationMinutes: Int?,
        goals: TrainingGoalsProfile
    ) -> Int? {
        guard let durationMinutes, durationMinutes > 0 else { return nil }
        let calories = cardioMET(for: activityType) * 3.5 * bodyMassKg(from: goals) / 200 * Double(durationMinutes)
        return max(Int(calories.rounded()), 0)
    }

    private static func cardioMET(for activityType: String) -> Double {
        let lower = activityType.lowercased()
        if lower.contains("walk") { return 3.5 }
        if lower.contains("cycle") || lower.contains("bike") { return 7.5 }
        if lower.contains("row") { return 7.0 }
        if lower.contains("stair") { return 8.0 }
        if lower.contains("elliptical") { return 5.5 }
        return 7.0
    }

    private static func bodyMassKg(from goals: TrainingGoalsProfile) -> Double {
        guard let weight = goals.currentWeightValue, weight > 0 else {
            return HealthEnergyEstimator.fallbackBodyMassKg
        }
        switch goals.preferredUnits {
        case .imperial:
            return weight / 2.20462
        case .metric:
            return weight
        }
    }

    private static func cardioRecommendation(activityType: String, sessions: [CardioHistorySession]) -> String {
        let sorted = sessions.sorted { $0.date > $1.date }
        guard let latest = sorted.first else {
            return "Log one more session to build a useful \(activityType.lowercased()) trend."
        }

        if let latestDistance = latest.distance, latestDistance > 0 {
            let amount = latestDistance.rounded() == latestDistance ? "\(Int(latestDistance))" : String(format: "%.1f", latestDistance)
            return "Next time, repeat \(amount) \(latest.distanceUnit ?? "mi") and make the effort feel a little smoother."
        }

        if let minutes = latest.durationMinutes, minutes > 0 {
            return "Next time, repeat \(minutes) minutes or add 2-5 easy minutes if recovery feels good."
        }

        return "Keep the next \(activityType.lowercased()) entry simple: time, distance, or both."
    }

    private static func recommendation(for sessions: [ExerciseHistorySession]) -> String {
        guard let latest = sessions.first else {
            return "Log a few clean exposures, then Bram can suggest a tighter next target."
        }

        let isBodyweightOrNoLoad = latest.bestSetText.hasPrefix("BW")
        guard sessions.count >= 2 else {
            if isBodyweightOrNoLoad {
                return "Repeat this movement once more, then aim to add one clean rep to the best set."
            }
            return "Repeat this load once more, then add a rep before increasing weight."
        }

        let previous = sessions[1]
        if latest.estimatedOneRepMax > previous.estimatedOneRepMax {
            if isBodyweightOrNoLoad {
                return "You moved this forward last time. Keep the same setup and add one clean rep if it is there."
            }
            return "You are trending up. Keep the first working set steady, then try a small load jump on the top set."
        }

        if isBodyweightOrNoLoad {
            return "Hold the same setup and match your best reps before adding another set or harder variation."
        }
        return "Keep the same load next time and try to match or add one rep before pushing weight again."
    }

    private static func statsInterval(for period: StatsPeriod, containing date: Date, calendar: Calendar) -> DateInterval {
        switch period {
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
        case .month:
            calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 30 * 86_400)
        case .year:
            calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, duration: 365 * 86_400)
        }
    }

    private static func loadMetrics(
        for period: StatsPeriod,
        interval: DateInterval,
        volumeByDay: [String: Int],
        energyByDay: [String: Int],
        energyEstimateByDay: [String: Bool],
        durationByDay: [String: Int],
        heartRateByDay: [String: Int],
        setBreakdownByDay: [String: [String: Int]],
        calendar: Calendar
    ) -> [DailyLoadMetric] {
        switch period {
        case .week:
            return (0..<7).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
                let dayKey = dayKey(for: date)
                return DailyLoadMetric(
                    weekday: date.formatted(.dateTime.weekday(.narrow)),
                    energyCalories: energyByDay[dayKey],
                    energyIsEstimated: energyEstimateByDay[dayKey] ?? (energyByDay[dayKey] == nil),
                    volume: volumeByDay[dayKey] ?? 0,
                    durationMinutes: durationByDay[dayKey],
                    averageHeartRate: heartRateByDay[dayKey],
                    muscleBreakdown: muscleMetrics(from: setBreakdownByDay[dayKey] ?? [:])
                )
            }
        case .month:
            var buckets = Array(repeating: 0, count: 5)
            var energyBuckets = Array(repeating: 0, count: 5)
            var energyEstimateBuckets = Array(repeating: false, count: 5)
            var durationBuckets = Array(repeating: 0, count: 5)
            var heartRateBuckets = Array(repeating: [Int](), count: 5)
            var breakdownBuckets = Array(repeating: [String: Int](), count: 5)
            for (dayKey, volume) in volumeByDay {
                guard let date = date(from: dayKey) else { continue }
                let day = calendar.component(.day, from: date)
                let index = min((day - 1) / 7, 4)
                buckets[index] += volume
                energyBuckets[index] += energyByDay[dayKey] ?? max(volume / 50, 0)
                energyEstimateBuckets[index] = energyEstimateBuckets[index] || (energyEstimateByDay[dayKey] ?? (energyByDay[dayKey] == nil))
                durationBuckets[index] += durationByDay[dayKey] ?? 0
                if let heartRate = heartRateByDay[dayKey] { heartRateBuckets[index].append(heartRate) }
                for (muscle, sets) in setBreakdownByDay[dayKey] ?? [:] {
                    breakdownBuckets[index][muscle, default: 0] += sets
                }
            }
            return buckets.enumerated().map { index, volume in
                DailyLoadMetric(
                    weekday: "W\(index + 1)",
                    energyCalories: energyBuckets[index],
                    energyIsEstimated: energyEstimateBuckets[index],
                    volume: volume,
                    durationMinutes: durationBuckets[index] > 0 ? durationBuckets[index] : nil,
                    averageHeartRate: average(heartRateBuckets[index]),
                    muscleBreakdown: muscleMetrics(from: breakdownBuckets[index])
                )
            }
        case .year:
            var buckets = Array(repeating: 0, count: 12)
            var energyBuckets = Array(repeating: 0, count: 12)
            var energyEstimateBuckets = Array(repeating: false, count: 12)
            var durationBuckets = Array(repeating: 0, count: 12)
            var heartRateBuckets = Array(repeating: [Int](), count: 12)
            var breakdownBuckets = Array(repeating: [String: Int](), count: 12)
            for (dayKey, volume) in volumeByDay {
                guard let date = date(from: dayKey) else { continue }
                let index = calendar.component(.month, from: date) - 1
                buckets[index] += volume
                energyBuckets[index] += energyByDay[dayKey] ?? max(volume / 50, 0)
                energyEstimateBuckets[index] = energyEstimateBuckets[index] || (energyEstimateByDay[dayKey] ?? (energyByDay[dayKey] == nil))
                durationBuckets[index] += durationByDay[dayKey] ?? 0
                if let heartRate = heartRateByDay[dayKey] { heartRateBuckets[index].append(heartRate) }
                for (muscle, sets) in setBreakdownByDay[dayKey] ?? [:] {
                    breakdownBuckets[index][muscle, default: 0] += sets
                }
            }
            return buckets.enumerated().map { index, volume in
                let date = calendar.date(from: DateComponents(year: 2026, month: index + 1, day: 1)) ?? .now
                return DailyLoadMetric(
                    weekday: date.formatted(.dateTime.month(.narrow)),
                    energyCalories: energyBuckets[index],
                    energyIsEstimated: energyEstimateBuckets[index],
                    volume: volume,
                    durationMinutes: durationBuckets[index] > 0 ? durationBuckets[index] : nil,
                    averageHeartRate: average(heartRateBuckets[index]),
                    muscleBreakdown: muscleMetrics(from: breakdownBuckets[index])
                )
            }
        }
    }

    private static func average(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    private static func muscleMetrics(from setsByMuscle: [String: Int]) -> [MuscleSetMetric] {
        setsByMuscle
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { muscle, sets in
                MuscleSetMetric(muscleGroup: muscle, sets: sets, colorRole: colorRole(for: muscle))
            }
    }

    private static func rangeTitle(for period: StatsPeriod, start: Date, end: Date) -> String {
        switch period {
        case .week:
            return "\(start.formatted(.dateTime.month(.abbreviated).day())) - \(end.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return start.formatted(.dateTime.month(.wide).year())
        case .year:
            return start.formatted(.dateTime.year())
        }
    }

    private func interpreted(_ note: DailyWorkoutNote) async -> DailyWorkoutNote {
        var output = note
        var result = await interpreter.interpret(note: note)
        output.interpretedLines = result.lines
        result.metrics = await energyAdjustedMetrics(result.metrics, for: note)
        if let historicalResult = try? scorePRsAgainstExerciseHistory(note: note, result: result) {
            result = historicalResult
        }
        output.interpretedLines = result.lines
        output.metrics = result.metrics
        output.suggestion = result.suggestion
        output.parsedSummary = nil
        return output
    }

    private func energyAdjustedMetrics(_ metrics: WorkoutMetricSnapshot, for note: DailyWorkoutNote) async -> WorkoutMetricSnapshot {
        let goals = (try? await trainingGoalsProfile()) ?? TrainingGoalsProfile()
        let dailyHealth = try? healthDailyMetricSync(for: note.date)
        let matchedWorkout: HealthWorkoutSample?
        if let match = try? await healthWorkoutMatch(for: note.id) {
            matchedWorkout = (try? healthWorkoutSamplesSync(on: note.date))?.first { $0.healthWorkoutId == match.healthWorkoutId }
        } else {
            matchedWorkout = nil
        }
        return HealthEnergyEstimator.applyingEnergy(
            to: metrics,
            goals: goals,
            dailyHealth: dailyHealth,
            matchedWorkout: matchedWorkout,
            note: note
        )
    }

    private func makeNote(from statement: OpaquePointer?) -> DailyWorkoutNote {
        let id = database.string(at: 0, in: statement).flatMap(UUID.init(uuidString:)) ?? UUID()
        let remoteId = database.string(at: 1, in: statement).flatMap(UUID.init(uuidString:))
        let userId = database.string(at: 2, in: statement).flatMap(UUID.init(uuidString:))
        let date = database.string(at: 3, in: statement).flatMap(Self.date(from:)) ?? .now
        let timezone = database.string(at: 4, in: statement) ?? TimeZone.current.identifier
        let body = database.string(at: 5, in: statement) ?? ""
        let createdAt = database.date(at: 6, in: statement) ?? .now
        let updatedAt = database.date(at: 7, in: statement) ?? createdAt
        let deletedAt = database.date(at: 8, in: statement)
        let syncState = database.string(at: 9, in: statement).flatMap(WorkoutSyncState.init(rawValue:)) ?? .localOnly
        let lastSyncError = database.string(at: 10, in: statement)

        return DailyWorkoutNote(
            id: id,
            remoteId: remoteId,
            userId: userId,
            date: date,
            timezoneIdentifier: timezone,
            body: body,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            syncState: syncState,
            lastSyncError: lastSyncError
        )
    }

    private func workoutMetricSnapshotSync(noteId: UUID) throws -> WorkoutMetricSnapshot? {
        let sql = """
        select total_sets, hard_sets, estimated_volume, pr_count, cardio_minutes,
               active_energy_calories, energy_is_estimated, average_heart_rate,
               workout_duration_minutes
        from workout_daily_metrics
        where note_id = ?
        limit 1;
        """
        var metrics: WorkoutMetricSnapshot?
        try database.withStatement(sql) { statement in
            try database.bind(noteId.uuidString, to: 1, in: statement)
            if try database.step(statement) {
                metrics = WorkoutMetricSnapshot(
                    totalSets: database.int(at: 0, in: statement) ?? 0,
                    hardSets: database.int(at: 1, in: statement) ?? 0,
                    estimatedVolume: database.int(at: 2, in: statement) ?? 0,
                    prCount: database.int(at: 3, in: statement) ?? 0,
                    streakDays: 0,
                    cardioMinutes: database.int(at: 4, in: statement) ?? 0,
                    activeEnergyCalories: database.int(at: 5, in: statement),
                    energyIsEstimated: (database.int(at: 6, in: statement) ?? 0) == 1,
                    averageHeartRate: database.int(at: 7, in: statement),
                    workoutDurationMinutes: database.int(at: 8, in: statement),
                    parseState: .parsed
                )
            }
        }
        return metrics
    }

    private func strengthSetsSync(noteId: UUID) throws -> [StrengthSetRecord] {
        let sql = """
        select id, exercise_key, exercise_name, line_index, set_number, reps,
               load_value, load_unit, performed_at
        from workout_strength_sets
        where note_id = ?
        order by line_index asc, set_number asc;
        """
        var sets: [StrengthSetRecord] = []
        try database.withStatement(sql) { statement in
            try database.bind(noteId.uuidString, to: 1, in: statement)
            while try database.step(statement) {
                sets.append(
                    StrengthSetRecord(
                        id: database.string(at: 0, in: statement).flatMap(UUID.init(uuidString:)) ?? UUID(),
                        exerciseKey: database.string(at: 1, in: statement) ?? "unknown",
                        exerciseName: database.string(at: 2, in: statement) ?? "Unknown",
                        lineIndex: database.int(at: 3, in: statement),
                        setNumber: database.int(at: 4, in: statement),
                        reps: database.int(at: 5, in: statement) ?? 0,
                        load: database.double(at: 6, in: statement) ?? 0,
                        unit: database.string(at: 7, in: statement) ?? "lb",
                        performedAt: database.date(at: 8, in: statement) ?? .now
                    )
                )
            }
        }
        return sets
    }

    private func cardioEntriesSync(noteId: UUID) throws -> [CardioEntry] {
        let sql = """
        select id, line_index, session_index, session_name, activity_type,
               duration_minutes, distance_value, distance_unit, average_heart_rate,
               active_energy_calories
        from workout_cardio_entries
        where note_id = ?
        order by line_index asc;
        """
        var entries: [CardioEntry] = []
        try database.withStatement(sql) { statement in
            try database.bind(noteId.uuidString, to: 1, in: statement)
            while try database.step(statement) {
                entries.append(
                    CardioEntry(
                        id: database.string(at: 0, in: statement).flatMap(UUID.init(uuidString:)) ?? UUID(),
                        noteId: noteId,
                        lineIndex: database.int(at: 1, in: statement),
                        sessionIndex: database.int(at: 2, in: statement),
                        sessionName: database.string(at: 3, in: statement),
                        activityType: database.string(at: 4, in: statement) ?? "Cardio",
                        durationMinutes: database.int(at: 5, in: statement),
                        distance: database.double(at: 6, in: statement),
                        distanceUnit: database.string(at: 7, in: statement),
                        averageHeartRate: database.int(at: 8, in: statement),
                        activeEnergyCalories: database.int(at: 9, in: statement)
                    )
                )
            }
        }
        return entries
    }

    private func prEventsSync(noteId: UUID) throws -> [WorkoutPREvent] {
        let sql = """
        select id, exercise_name, kind, value, unit, achieved_at
        from workout_pr_events
        where note_id = ?
        order by achieved_at asc;
        """
        var events: [WorkoutPREvent] = []
        try database.withStatement(sql) { statement in
            try database.bind(noteId.uuidString, to: 1, in: statement)
            while try database.step(statement) {
                events.append(
                    WorkoutPREvent(
                        id: database.string(at: 0, in: statement).flatMap(UUID.init(uuidString:)) ?? UUID(),
                        noteId: noteId,
                        exerciseName: database.string(at: 1, in: statement) ?? "Unknown",
                        kind: database.string(at: 2, in: statement) ?? "estimated_one_rep_max",
                        value: database.double(at: 3, in: statement) ?? 0,
                        unit: database.string(at: 4, in: statement) ?? "lb",
                        achievedAt: database.date(at: 5, in: statement) ?? .now
                    )
                )
            }
        }
        return events
    }

    private func makeTrainingGoalsProfile(from statement: OpaquePointer?) -> TrainingGoalsProfile {
        TrainingGoalsProfile(
            primaryGoal: database.string(at: 0, in: statement).flatMap(TrainingPrimaryGoal.init(rawValue:)) ?? .buildMuscle,
            weeklyTrainingDays: database.int(at: 1, in: statement) ?? 4,
            sessionLengthMinutes: database.int(at: 2, in: statement) ?? 60,
            trainingStyles: Self.decodeSet(database.string(at: 3, in: statement), as: TrainingStyle.self),
            equipment: Self.decodeSet(database.string(at: 4, in: statement), as: EquipmentContext.self),
            heightValue: database.double(at: 5, in: statement),
            currentWeightValue: database.double(at: 6, in: statement),
            targetWeightValue: database.double(at: 7, in: statement),
            currentWeightLoggedAt: database.date(at: 8, in: statement),
            currentWeightSource: database.string(at: 9, in: statement).flatMap(BodyweightSource.init(rawValue:)),
            sex: database.string(at: 10, in: statement).flatMap(BodySex.init(rawValue:)),
            sexSelfDescription: database.string(at: 11, in: statement) ?? "",
            preferredUnits: database.string(at: 12, in: statement).flatMap(MeasurementUnitPreference.init(rawValue:)) ?? .imperial,
            estimatedDailyCalories: database.int(at: 13, in: statement),
            updatedAt: database.date(at: 14, in: statement) ?? .now
        ).sanitized
    }

    private func healthDailyMetricSync(for date: Date) throws -> HealthDailyMetric? {
        let sql = """
        select metric_date, active_energy_calories, average_heart_rate, max_heart_rate,
               bodyweight_value, bodyweight_unit, workout_duration_minutes, source, updated_at
        from health_daily_metrics
        where metric_date = ?
        limit 1;
        """
        var metric: HealthDailyMetric?
        try database.withStatement(sql) { statement in
            try database.bind(Self.dayKey(for: date), to: 1, in: statement)
            if try database.step(statement) {
                metric = makeHealthDailyMetric(from: statement)
            }
        }
        return metric
    }

    private func healthWorkoutSamplesSync(on date: Date) throws -> [HealthWorkoutSample] {
        let dayKey = Self.dayKey(for: date)
        let sql = """
        select health_workout_id, activity_type, start_date, end_date, duration_minutes,
               active_energy_calories, distance_value, distance_unit, average_heart_rate, max_heart_rate
        from health_workout_samples
        where date(start_date) = date(?)
        order by start_date asc;
        """
        var workouts: [HealthWorkoutSample] = []
        try database.withStatement(sql) { statement in
            try database.bind(dayKey, to: 1, in: statement)
            while try database.step(statement) {
                workouts.append(makeHealthWorkoutSample(from: statement))
            }
        }
        return workouts
    }

    private func makeHealthDailyMetric(from statement: OpaquePointer?) -> HealthDailyMetric {
        HealthDailyMetric(
            date: database.string(at: 0, in: statement).flatMap(Self.date(from:)) ?? .now,
            activeEnergyCalories: database.int(at: 1, in: statement),
            averageHeartRate: database.int(at: 2, in: statement),
            maxHeartRate: database.int(at: 3, in: statement),
            bodyweightValue: database.double(at: 4, in: statement),
            bodyweightUnit: database.string(at: 5, in: statement),
            workoutDurationMinutes: database.int(at: 6, in: statement),
            source: database.string(at: 7, in: statement) ?? "APPLE_HEALTH",
            updatedAt: database.date(at: 8, in: statement) ?? .now
        )
    }

    private func makeHealthWorkoutSample(from statement: OpaquePointer?) -> HealthWorkoutSample {
        HealthWorkoutSample(
            healthWorkoutId: database.string(at: 0, in: statement) ?? UUID().uuidString,
            activityType: database.string(at: 1, in: statement) ?? "Workout",
            startDate: database.date(at: 2, in: statement) ?? .now,
            endDate: database.date(at: 3, in: statement) ?? .now,
            durationMinutes: database.int(at: 4, in: statement) ?? 0,
            activeEnergyCalories: database.int(at: 5, in: statement),
            distanceValue: database.double(at: 6, in: statement),
            distanceUnit: database.string(at: 7, in: statement),
            averageHeartRate: database.int(at: 8, in: statement),
            maxHeartRate: database.int(at: 9, in: statement)
        )
    }

    private func makeHealthWorkoutMatch(from statement: OpaquePointer?) -> HealthWorkoutMatch {
        HealthWorkoutMatch(
            id: database.string(at: 0, in: statement).flatMap(UUID.init(uuidString:)) ?? UUID(),
            noteId: database.string(at: 1, in: statement).flatMap(UUID.init(uuidString:)) ?? UUID(),
            noteDate: database.string(at: 2, in: statement).flatMap(Self.date(from:)) ?? .now,
            healthWorkoutId: database.string(at: 3, in: statement) ?? "",
            matchQuality: database.string(at: 4, in: statement).flatMap(HealthWorkoutMatchQuality.init(rawValue:)) ?? .possible,
            matchedAt: database.date(at: 5, in: statement) ?? .now
        )
    }

    private static func migrate(_ database: SQLiteDatabase) throws {
        try database.execute("""
        create table if not exists training_goals_profile (
          id text primary key,
          primary_goal text not null,
          weekly_training_days integer not null,
          session_length_minutes integer not null,
          training_styles text not null,
          equipment text not null,
          height_value real,
          current_weight_value real,
          target_weight_value real,
          current_weight_logged_at text,
          current_weight_source text,
          sex text,
          sex_self_description text,
          preferred_units text not null,
          estimated_daily_calories integer,
          updated_at text not null
        );

        create table if not exists onboarding_draft (
          id text primary key,
          first_name text not null default '',
          current_step integer not null default 0,
          updated_at text not null
        );

        create table if not exists workout_notes (
          id text primary key,
          remote_id text,
          user_id text,
          workout_date text not null unique,
          timezone_identifier text not null,
          body text not null default '',
          created_at text not null,
          updated_at text not null,
          deleted_at text,
          sync_state text not null,
          last_sync_error text
        );

        create index if not exists workout_notes_workout_date_idx
        on workout_notes(workout_date);

        create index if not exists workout_notes_sync_state_idx
        on workout_notes(sync_state)
        where sync_state <> 'SYNCED';

        create table if not exists workout_daily_metrics (
          note_id text primary key references workout_notes(id) on delete cascade,
          total_sets integer not null default 0,
          hard_sets integer not null default 0,
          estimated_volume integer not null default 0,
          pr_count integer not null default 0,
          cardio_minutes integer not null default 0,
          active_energy_calories integer,
          energy_is_estimated integer not null default 0,
          average_heart_rate integer,
          workout_duration_minutes integer,
          updated_at text not null
        );

        create table if not exists workout_strength_sets (
          id text primary key,
          note_id text not null references workout_notes(id) on delete cascade,
          exercise_key text not null,
          exercise_name text not null,
          muscle_group text,
          line_index integer,
          set_number integer,
          reps integer not null,
          load_value real not null,
          load_unit text not null default 'lb',
          estimated_one_rep_max real not null,
          performed_at text not null
        );

        create table if not exists workout_pr_events (
          id text primary key,
          note_id text not null references workout_notes(id) on delete cascade,
          exercise_name text not null,
          kind text not null,
          value real not null,
          unit text not null,
          achieved_at text not null
        );

        create index if not exists workout_strength_sets_note_idx
        on workout_strength_sets(note_id);

        create index if not exists workout_strength_sets_exercise_idx
        on workout_strength_sets(exercise_key, performed_at desc);

        create table if not exists workout_cardio_entries (
          id text primary key,
          note_id text not null references workout_notes(id) on delete cascade,
          line_index integer,
          session_index integer,
          session_name text,
          activity_type text not null,
          duration_minutes integer,
          distance_value real,
          distance_unit text,
          average_heart_rate integer,
          active_energy_calories integer
        );

        create index if not exists workout_cardio_entries_note_idx
        on workout_cardio_entries(note_id);

        create index if not exists workout_pr_events_note_idx
        on workout_pr_events(note_id);

        create table if not exists health_daily_metrics (
          metric_date text primary key,
          active_energy_calories integer,
          average_heart_rate integer,
          max_heart_rate integer,
          bodyweight_value real,
          bodyweight_unit text,
          workout_duration_minutes integer,
          source text not null,
          updated_at text not null
        );

        create table if not exists health_workout_samples (
          health_workout_id text primary key,
          activity_type text not null,
          start_date text not null,
          end_date text not null,
          duration_minutes integer not null,
          active_energy_calories integer,
          distance_value real,
          distance_unit text,
          average_heart_rate integer,
          max_heart_rate integer
        );

        create index if not exists health_workout_samples_start_idx
        on health_workout_samples(start_date);

        create table if not exists health_workout_matches (
          id text primary key,
          note_id text not null references workout_notes(id) on delete cascade,
          note_date text not null,
          health_workout_id text not null references health_workout_samples(health_workout_id) on delete cascade,
          match_quality text not null,
          matched_at text not null,
          unique(note_id),
          unique(health_workout_id)
        );
        """)
        if try !Self.columnExists("energy_is_estimated", in: "workout_daily_metrics", database: database) {
            try database.execute("alter table workout_daily_metrics add column energy_is_estimated integer not null default 0;")
        }
        if try !Self.columnExists("current_weight_logged_at", in: "training_goals_profile", database: database) {
            try database.execute("alter table training_goals_profile add column current_weight_logged_at text;")
        }
        if try !Self.columnExists("current_weight_source", in: "training_goals_profile", database: database) {
            try database.execute("alter table training_goals_profile add column current_weight_source text;")
        }
    }

    private static func columnExists(_ column: String, in table: String, database: SQLiteDatabase) throws -> Bool {
        var exists = false
        try database.withStatement("pragma table_info(\(table));") { statement in
            while try database.step(statement) {
                if database.string(at: 1, in: statement) == column {
                    exists = true
                    break
                }
            }
        }
        return exists
    }

    private static func encodeSet<T: RawRepresentable>(_ values: Set<T>) -> String where T.RawValue == String {
        values.map(\.rawValue).sorted().joined(separator: ",")
    }

    private static func decodeSet<T: RawRepresentable & Hashable>(_ value: String?, as type: T.Type) -> Set<T> where T.RawValue == String {
        let values = value?
            .split(separator: ",")
            .compactMap { T(rawValue: String($0)) } ?? []
        return Set(values)
    }

    static func defaultDatabasePath() -> String {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Bram.sqlite").path
    }

    static func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 1970, components.month ?? 1, components.day ?? 1)
    }

    private static func date(from dayKey: String) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
