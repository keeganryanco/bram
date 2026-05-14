import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var note: DailyWorkoutNote
    @State private var selectedExercise: ExerciseAnchor?
    @State private var selectedCardioHistory: CardioHistorySummary?
    @State private var activePanel: HomePanel?
    @State private var calendarDays: [CalendarWorkoutDay] = []
    @State private var progressStats = BramPreviewData.stats
    @State private var goalsProfile = BramPreviewData.goalsProfile
    @State private var draftInterpretationTask: Task<Void, Never>?
    @State private var backendInterpretationTask: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?
    @State private var loadTask: Task<Void, Never>?
    @State private var isLoadingNote = false
    @State private var isEditingNote = false
    @State private var activeSuggestionDraft: SuggestionDraft?
    private let noteStore: any WorkoutLocalStore
    private let interpreter: any WorkoutInterpretationService
    private let backendInterpreter: (any WorkoutInterpretationBackendClient)?
    private let featureAccess: BramFeatureAccess
    private let account: SettingsAccountState
    private let onSignOut: () async -> Void
    private let onDeleteAccount: () async -> Void
    private let onGoalsProfileSave: ((TrainingGoalsProfile) async -> Void)?
    private let onWorkoutDataSaved: (() async -> Void)?

    init(
        note: DailyWorkoutNote = BramPreviewData.populatedNote,
        account: SettingsAccountState = BramPreviewData.account,
        initialGoalsProfile: TrainingGoalsProfile = BramPreviewData.goalsProfile,
        noteStore: any WorkoutLocalStore = SQLiteWorkoutLocalStore.shared,
        interpreter: any WorkoutInterpretationService = HeuristicWorkoutInterpretationService(),
        backendInterpreter: (any WorkoutInterpretationBackendClient)? = BramBackendWorkoutInterpretationClient.configuredFromBundle(),
        featureAccess: BramFeatureAccess = .previewPremium,
        onSignOut: @escaping () async -> Void = {},
        onDeleteAccount: @escaping () async -> Void = {},
        onGoalsProfileSave: ((TrainingGoalsProfile) async -> Void)? = nil,
        onWorkoutDataSaved: (() async -> Void)? = nil
    ) {
        _note = State(initialValue: note)
        _goalsProfile = State(initialValue: initialGoalsProfile)
        self.account = account
        self.noteStore = noteStore
        self.interpreter = interpreter
        self.backendInterpreter = backendInterpreter
        self.featureAccess = featureAccess
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
        self.onGoalsProfileSave = onGoalsProfileSave
        self.onWorkoutDataSaved = onWorkoutDataSaved
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            BramColor.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeHeader(
                        date: note.date,
                        streakDays: note.metrics.streakDays,
                        openCalendar: { activePanel = .calendar },
                        openProgress: { activePanel = .progress },
                        openSettings: { activePanel = .settings }
                    )

                    WorkoutNoteEditor(
                        noteBody: $note.body,
                        interpretedLines: featureAccess.canUseInterpretation ? note.interpretedLines : [],
                        interpretationEnabled: featureAccess.canUseInterpretation,
                        onSelectExercise: { exercise in
                            Task {
                                await selectExercise(exercise)
                            }
                        },
                        onSelectCardio: { entry in
                            Task {
                                await selectCardio(entry)
                            }
                        },
                        isEditing: $isEditingNote
                    )

                    if featureAccess.canUseSuggestions, let suggestion = note.suggestion {
                        WorkoutSuggestionCard(suggestion: suggestion)
                    }

                    if featureAccess.canUseSuggestions,
                       let activeSuggestionDraft,
                       note.body.contains(activeSuggestionDraft.text) {
                        SuggestionDraftControls(
                            draft: activeSuggestionDraft,
                            onDelete: { handleSuggestionDraft(.deleted) },
                            onThumbsUp: { handleSuggestionDraft(.thumbsUp) },
                            onThumbsDown: { handleSuggestionDraft(.thumbsDown) }
                        )
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(daySwipeGesture)

            WorkoutLoadBar(metrics: note.metrics) {
                activePanel = featureAccess.canUseStats ? .dayStats : .premiumPrompt
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .font(BramFont.body())
        .sheet(item: $activePanel) { panel in
            panelView(for: panel)
                .presentationDetents(detents(for: panel))
                .presentationCornerRadius(30)
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseHistorySheetView(exercise: exercise)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(30)
        }
        .sheet(item: $selectedCardioHistory) { history in
            CardioHistorySheetView(history: history)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(30)
        }
        .task(id: selectedDayKey) {
            await loadNote(for: note.date)
        }
        .task {
            await refreshCalendarDays()
            await refreshProgressStats()
            await loadGoalsProfile()
        }
        .onChange(of: note.body) { _, _ in
            scheduleDraftInterpretation()
            scheduleBackendInterpretation()
            scheduleAutosave()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                flushAutosave()
            }
        }
        .onDisappear {
            draftInterpretationTask?.cancel()
            backendInterpretationTask?.cancel()
            flushAutosave()
            loadTask?.cancel()
        }
    }

    @ViewBuilder
    private func panelView(for panel: HomePanel) -> some View {
        switch panel {
        case .calendar:
            CalendarPanelView(days: calendarDays, selectedDate: selectedDateBinding)
        case .dayStats:
            DailyWorkoutStatsPanelView(note: note)
        case .progress:
            if featureAccess.canUseStats {
                StatsPanelView(
                    stats: progressStats,
                    selectedDate: note.date,
                    noteStore: noteStore,
                    initialMode: .stats
                )
            } else {
                PremiumFeaturePromptView(feature: "Progress")
            }
        case .premiumPrompt:
            PremiumFeaturePromptView(feature: "Workout stats")
        case .settings:
            SettingsView(
                account: account,
                goalsProfile: goalsProfile,
                healthConnected: progressStats.healthMetricsConnected,
                note: note,
                noteStore: noteStore,
                canUseHealth: featureAccess.canUseHealth,
                onGoalsSave: saveGoalsProfile,
                onSignOut: onSignOut,
                onDeleteAccount: onDeleteAccount,
                onHealthUpdated: {
                    Task {
                        await loadNote(for: note.date)
                        await refreshProgressStats()
                        await refreshCalendarDays()
                        await loadGoalsProfile()
                    }
                }
            )
        case .goals:
            GoalsSettingsView(profile: goalsProfile, onSave: saveGoalsProfile)
        case .health:
            HealthConnectionView(
                note: note,
                noteStore: noteStore,
                onUpdated: {
                    Task {
                        await loadNote(for: note.date)
                        await refreshProgressStats()
                        await refreshCalendarDays()
                    }
                }
            )
        }
    }

    private func detents(for panel: HomePanel) -> Set<PresentationDetent> {
        switch panel {
        case .calendar:
            [.medium, .large]
        case .dayStats, .premiumPrompt:
            [.medium]
        case .progress, .settings, .goals, .health:
            [.large]
        }
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { note.date },
            set: { newDate in
                withAnimation(.snappy) {
                    note.date = newDate
                }
            }
        )
    }

    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 55)
            .onEnded { value in
                guard !isEditingNote else { return }
                guard abs(value.translation.width) > abs(value.translation.height) * 2.2 else { return }
                guard abs(value.translation.width) > 110 else { return }
                guard abs(value.predictedEndTranslation.width) > 150 else { return }
                navigateDay(by: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func navigateDay(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: note.date) else { return }
        withAnimation(.snappy) {
            note.date = newDate
        }
    }

    private func selectExercise(_ exercise: ExerciseAnchor) async {
        saveTask?.cancel()
        let store = noteStore
        let draft = note

        do {
            try await store.save(draft)
            var enrichedExercise = exercise
            if exercise.isSupersetGroup {
                var enrichedMembers: [SupersetExerciseMember] = []
                for member in exercise.groupMembers {
                    let memberAnchor = ExerciseAnchor(
                        id: member.id,
                        displayName: member.displayName,
                        normalizedName: member.normalizedName,
                        exerciseKey: member.exerciseKey,
                        history: .supersetPlaceholder(members: [])
                    )
                    let history = try await store.exerciseHistory(for: memberAnchor)
                    enrichedMembers.append(
                        SupersetExerciseMember(
                            id: member.id,
                            displayName: history.displayName,
                            normalizedName: member.normalizedName,
                            exerciseKey: member.exerciseKey,
                            history: history
                        )
                    )
                }
                enrichedExercise.groupMembers = enrichedMembers
            } else {
                let history = try await store.exerciseHistory(for: exercise)
                enrichedExercise.history = history
            }
            await MainActor.run {
                selectedExercise = enrichedExercise
            }
        } catch {
            await MainActor.run {
                selectedExercise = exercise
            }
        }
    }

    private func selectCardio(_ entry: CardioEntry) async {
        saveTask?.cancel()
        let store = noteStore
        let draft = note

        do {
            try await store.save(draft)
            let history = try await store.cardioHistory(for: entry.activityType)
            await MainActor.run {
                selectedCardioHistory = history
            }
        } catch {
            await MainActor.run {
                selectedCardioHistory = .placeholder(for: entry)
            }
        }
    }

    private func scheduleDraftInterpretation() {
        guard !isLoadingNote, featureAccess.canUseInterpretation else { return }
        draftInterpretationTask?.cancel()
        let draft = note
        let interpreter = interpreter
        draftInterpretationTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let result = displaySafeInterpretation(await interpreter.interpret(note: draft))
            guard !Task.isCancelled else { return }
            let context = await SuggestionContextBuilder.build(
                note: draft,
                result: result,
                goals: goalsProfile,
                store: noteStore
            )
            let suggestion = LocalSuggestionEngine.dailySuggestion(context: context) ?? result.suggestion
            await MainActor.run {
                guard note.id == draft.id, note.body == draft.body else { return }
                note.interpretedLines = linesByPreservingAuthoritativePRs(result.lines, currentLines: note.interpretedLines)
                var metrics = result.metrics
                metrics.prCount = note.metrics.prCount
                note.metrics = metrics
                note.suggestion = suggestion ?? note.suggestion
                note.parsedSummary = nil
            }
        }
    }

    private func scheduleBackendInterpretation() {
        guard !isLoadingNote,
              featureAccess.canUseInterpretation,
              let backendInterpreter
        else { return }

        backendInterpretationTask?.cancel()
        let draft = note
        backendInterpretationTask = Task {
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled else { return }
            guard let backendResult = try? await backendInterpreter.interpret(note: draft) else { return }
            let result = displaySafeInterpretation(backendResult)
            guard !Task.isCancelled else { return }
            let context = await SuggestionContextBuilder.build(
                note: draft,
                result: result,
                goals: goalsProfile,
                store: noteStore
            )
            let suggestion = LocalSuggestionEngine.dailySuggestion(context: context) ?? result.suggestion
            await MainActor.run {
                guard note.id == draft.id, note.body == draft.body else { return }
                note.interpretedLines = result.lines.isEmpty
                    ? note.interpretedLines
                    : linesByPreservingAuthoritativePRs(result.lines, currentLines: note.interpretedLines)
                var metrics = result.metrics
                metrics.prCount = note.metrics.prCount
                note.metrics = metrics
                note.suggestion = suggestion ?? note.suggestion
                note.parsedSummary = nil
            }
        }
    }

    private func displaySafeInterpretation(_ result: WorkoutInterpretationResult) -> WorkoutInterpretationResult {
        var safe = result
        safe.prEvents = []
        safe.metrics.prCount = 0
        safe.lines = result.lines.map { line in
            var cleaned = line
            cleaned.badges.removeAll { $0.kind == .pr }
            cleaned.segments.removeAll { $0.kind == .badge && $0.text == "PR" }
            if cleaned.chipText == "PR" {
                cleaned.chipText = ""
            }
            return cleaned
        }
        if safe.suggestion?.kind == .progression {
            safe.suggestion = nil
        }
        return safe
    }

    private func linesByPreservingAuthoritativePRs(
        _ incomingLines: [InterpretedWorkoutLine],
        currentLines: [InterpretedWorkoutLine]
    ) -> [InterpretedWorkoutLine] {
        let prStateByLine = currentLines.reduce(into: [Int: (rawText: String, badges: [WorkoutLineBadge], segments: [InterpretedLineSegment], chipText: String)]()) { result, line in
            let badges = line.badges.filter { $0.kind == .pr }
            let segments = line.segments.filter { $0.kind == .badge && $0.text == "PR" }
            guard !badges.isEmpty || !segments.isEmpty else { return }
            result[line.lineIndex] = (line.rawText, badges, segments, line.chipText == "PR" ? "PR" : "")
        }

        return incomingLines.map { line in
            guard let prState = prStateByLine[line.lineIndex],
                  prState.rawText == line.rawText,
                  !prState.badges.isEmpty || !prState.segments.isEmpty
            else {
                return line
            }

            var merged = line
            merged.badges.append(contentsOf: prState.badges)
            merged.segments.append(contentsOf: prState.segments)
            merged.chipText = prState.chipText
            return merged
        }
    }

    private func maybeInsertSuggestionDraft(from result: WorkoutInterpretationResult) {
        guard featureAccess.canUseSuggestions,
              activeSuggestionDraft == nil,
              let draft = LocalSuggestionEngine.draft(
                for: DailyWorkoutNote(
                    id: note.id,
                    remoteId: note.remoteId,
                    userId: note.userId,
                    date: note.date,
                    timezoneIdentifier: note.timezoneIdentifier,
                    body: note.body,
                    createdAt: note.createdAt,
                    updatedAt: note.updatedAt,
                    deletedAt: note.deletedAt,
                    syncState: note.syncState,
                    lastSyncError: note.lastSyncError,
                    interpretedLines: result.lines,
                    parsedSummary: nil,
                    suggestion: result.suggestion,
                    metrics: result.metrics
                ),
                goals: goalsProfile
              )
        else { return }

        activeSuggestionDraft = draft
        let separator = note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
        note.body = note.body + separator + draft.text
    }

    private func handleSuggestionDraft(_ action: SuggestionFeedbackAction) {
        guard let draft = activeSuggestionDraft else { return }

        switch action {
        case .deleted, .dismissed, .thumbsDown:
            note.body = note.body
                .components(separatedBy: .newlines)
                .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines) != draft.text }
                .joined(separator: "\n")
                .replacingOccurrences(of: "\n\n\n", with: "\n\n")
        case .thumbsUp, .accepted:
            break
        case .modified:
            break
        }

        activeSuggestionDraft = nil
        scheduleAutosave()
    }

    private var selectedDayKey: String {
        SQLiteWorkoutLocalStore.dayKey(for: note.date)
    }

    private func loadNote(for date: Date) async {
        guard !isLoadingNote else { return }
        isLoadingNote = true
        defer { isLoadingNote = false }
        let store = noteStore
        do {
            let loaded = try await store.note(for: date)
            await MainActor.run {
                note = loaded
            }
        } catch {
            await MainActor.run {
                note.lastSyncError = "Could not load this workout note."
            }
        }
    }

    private func scheduleAutosave() {
        guard !isLoadingNote else { return }
        saveTask?.cancel()
        var draft = note
        draft.updatedAt = .now
        draft.syncState = draft.remoteId == nil ? .localOnly : .pendingUpload
        note = draft
        let store = noteStore
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            try? await store.save(draft)
            await onWorkoutDataSaved?()
            if let refreshed = try? await store.note(for: draft.date), !Task.isCancelled {
                await MainActor.run {
                    note.interpretedLines = refreshed.interpretedLines
                    note.metrics = refreshed.metrics
                    note.suggestion = refreshed.suggestion
                    note.parsedSummary = nil
                    upsertCalendarDay(for: refreshed)
                    Task { await refreshProgressStats() }
                }
            }
        }
    }

    private func flushAutosave() {
        guard !isLoadingNote else { return }
        saveTask?.cancel()
        var draft = note
        draft.updatedAt = .now
        draft.syncState = draft.remoteId == nil ? .localOnly : .pendingUpload
        let store = noteStore
        Task {
            try? await store.save(draft)
            await onWorkoutDataSaved?()
            if let refreshed = try? await store.note(for: draft.date) {
                await MainActor.run {
                    note.interpretedLines = refreshed.interpretedLines
                    note.metrics = refreshed.metrics
                    note.suggestion = refreshed.suggestion
                    note.parsedSummary = nil
                    upsertCalendarDay(for: refreshed)
                    Task { await refreshProgressStats() }
                }
            }
        }
    }

    private func refreshCalendarDays() async {
        do {
            let days = try await noteStore.calendarWorkoutDays()
            await MainActor.run {
                calendarDays = days
            }
        } catch {
            await MainActor.run {
                note.lastSyncError = "Could not refresh calendar markers."
            }
        }
    }

    private func refreshProgressStats() async {
        do {
            let stats = try await noteStore.statsWeek(containing: note.date)
            await MainActor.run {
                progressStats = stats
            }
        } catch {
            await MainActor.run {
                note.lastSyncError = "Could not refresh progress stats."
            }
        }
    }

    private func loadGoalsProfile() async {
        do {
            let profile = try await noteStore.trainingGoalsProfile()
            await MainActor.run {
                goalsProfile = profile
            }
        } catch {
            await MainActor.run {
                goalsProfile = BramPreviewData.goalsProfile
            }
        }
    }

    private func saveGoalsProfile(_ profile: TrainingGoalsProfile) {
        goalsProfile = profile
        let store = noteStore
        Task {
            try? await store.save(profile)
            await onGoalsProfileSave?(profile)
        }
    }

    private func upsertCalendarDay(for note: DailyWorkoutNote) {
        let hasWorkout = !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        calendarDays.removeAll { Calendar.current.isDate($0.date, inSameDayAs: note.date) }

        guard hasWorkout else { return }
        calendarDays.append(
            CalendarWorkoutDay(
                date: note.date,
                isSelected: false,
                isToday: Calendar.current.isDateInToday(note.date),
                hasWorkout: true,
                hadPR: note.metrics.prCount > 0
            )
        )
        calendarDays.sort { $0.date < $1.date }
    }
}

#Preview("Home Dark") {
    HomeView()
        .preferredColorScheme(.dark)
}

#Preview("Home Empty Light") {
    HomeView(note: BramPreviewData.emptyNote, featureAccess: .free)
        .preferredColorScheme(.light)
}
