import StoreKit
import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @AppStorage("bram.review.prompt_disabled") private var reviewPromptDisabled = false
    @AppStorage("bram.review.prompt_count") private var reviewPromptCount = 0
    @AppStorage("bram.review.last_prompt_at") private var reviewLastPromptAt = 0.0
    @AppStorage("bram.review.first_workout_prompted") private var reviewFirstWorkoutPrompted = false
    @AppStorage("bramWorkoutRemindersEnabled") private var workoutRemindersEnabled = false
    @AppStorage("bram.install.id") private var installId = ""
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
    @State private var activeNoteLineIndex: Int?
    @State private var showingReviewPrompt = false
    @State private var activeSuggestionDraft: SuggestionDraft?
    @State private var coachCards: [WorkoutCoachCard] = []
    @State private var coachCardsShownAt = Date.distantPast
    @State private var pendingCoachCards: [WorkoutCoachCard]?
    @State private var viewedCoachCardKeys = Set<String>()
    @State private var feedbackSubmittedCoachCardKeys = Set<String>()
    @State private var localFeedbackSummary: [String: Int] = [:]
    @State private var coachCardReplacementTask: Task<Void, Never>?
    @State private var backendSuggestionTask: Task<Void, Never>?
    @State private var foregroundHealthRefreshTask: Task<Void, Never>?
    @State private var isRefreshingForegroundHealth = false
    private let noteStore: any WorkoutLocalStore
    private let interpreter: any WorkoutInterpretationService
    private let backendInterpreter: (any WorkoutInterpretationBackendClient)?
    private let suggestionBackend: (any WorkoutSuggestionBackendClient)?
    private let healthService: any AppleHealthProviding
    private let featureAccess: BramFeatureAccess
    private let account: SettingsAccountState
    private let onSignOut: () async -> Void
    private let onDeleteAccount: () async -> Void
    private let onGoalsProfileSave: ((TrainingGoalsProfile) async -> Void)?
    private let onWorkoutDataSaved: (() async -> Void)?
    private let reminderService: (any WorkoutReminderScheduling)?
    private let accessTokenProvider: () async -> String?
    private let track: (AnalyticsEvent) -> Void
    private let reportError: (String, String, String?, Error?, [String: String]) -> Void
    private let submitSupportRequest: (SupportRequestDraft) async throws -> Void

    init(
        note: DailyWorkoutNote = BramPreviewData.populatedNote,
        account: SettingsAccountState = BramPreviewData.account,
        initialGoalsProfile: TrainingGoalsProfile = BramPreviewData.goalsProfile,
        noteStore: any WorkoutLocalStore = SQLiteWorkoutLocalStore.shared,
        interpreter: any WorkoutInterpretationService = HeuristicWorkoutInterpretationService(),
        backendInterpreter: (any WorkoutInterpretationBackendClient)? = BramBackendWorkoutInterpretationClient.configuredFromBundle(),
        suggestionBackend: (any WorkoutSuggestionBackendClient)? = BramBackendWorkoutSuggestionClient.configuredFromBundle(),
        healthService: any AppleHealthProviding = AppleHealthService(),
        featureAccess: BramFeatureAccess = .previewPremium,
        onSignOut: @escaping () async -> Void = {},
        onDeleteAccount: @escaping () async -> Void = {},
        onGoalsProfileSave: ((TrainingGoalsProfile) async -> Void)? = nil,
        onWorkoutDataSaved: (() async -> Void)? = nil,
        reminderService: (any WorkoutReminderScheduling)? = BramNotificationService(),
        accessTokenProvider: @escaping () async -> String? = { nil },
        track: @escaping (AnalyticsEvent) -> Void = { _ in },
        reportError: @escaping (String, String, String?, Error?, [String: String]) -> Void = { _, _, _, _, _ in },
        submitSupportRequest: @escaping (SupportRequestDraft) async throws -> Void = { _ in }
    ) {
        _note = State(initialValue: note)
        _goalsProfile = State(initialValue: initialGoalsProfile)
        self.account = account
        self.noteStore = noteStore
        self.interpreter = interpreter
        self.backendInterpreter = backendInterpreter
        self.suggestionBackend = suggestionBackend
        self.healthService = healthService
        self.featureAccess = featureAccess
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
        self.onGoalsProfileSave = onGoalsProfileSave
        self.onWorkoutDataSaved = onWorkoutDataSaved
        self.reminderService = reminderService
        self.accessTokenProvider = accessTokenProvider
        self.track = track
        self.reportError = reportError
        self.submitSupportRequest = submitSupportRequest
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            BramColor.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeHeader(
                        date: note.date,
                        streakDays: progressStats.currentStreak,
                        openCalendar: {
                            track(AnalyticsEvent(name: "calendar_opened", properties: ["source": "home_header"]))
                            activePanel = .calendar
                        },
                        openProgress: {
                            track(AnalyticsEvent(name: "stats_opened", properties: ["source": "home_header"]))
                            activePanel = .progress
                        },
                        openSettings: {
                            track(AnalyticsEvent(name: "settings_opened", properties: ["source": "home_header"]))
                            activePanel = .settings
                        }
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
                        isEditing: $isEditingNote,
                        activeLineIndex: $activeNoteLineIndex
                    )

                    if featureAccess.canUseSuggestions, !coachCards.isEmpty {
                        WorkoutCoachCardStack(cards: coachCards, onFeedback: handleCoachCardFeedback)
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
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(daySwipeGesture)

            WorkoutLoadBar(metrics: note.metrics) {
                activePanel = featureAccess.canUseStats ? .dayStats : .premiumPrompt
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
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
        .sheet(isPresented: $showingReviewPrompt) {
            ReviewPromptSheet(
                onYes: {
                    track(AnalyticsEvent(name: "review_prompt_accepted", properties: ["source": "first_workout"]))
                    requestReview()
                    showingReviewPrompt = false
                },
                onNotNow: {
                    track(AnalyticsEvent(name: "review_prompt_deferred", properties: ["source": "first_workout"]))
                    showingReviewPrompt = false
                },
                onNever: {
                    reviewPromptDisabled = true
                    track(AnalyticsEvent(name: "review_prompt_disabled", properties: ["source": "first_workout"]))
                    showingReviewPrompt = false
                }
            )
            .presentationDetents([.height(350)])
            .presentationCornerRadius(28)
        }
        .task(id: selectedDayKey) {
            await loadNote(for: note.date)
        }
        .task {
            track(AnalyticsEvent(name: "home_viewed", properties: ["access": featureAccess.canUseInterpretation ? "premium" : "free"]))
            await refreshCalendarDays()
            await refreshProgressStats()
            await loadGoalsProfile()
            startForegroundHealthRefreshIfNeeded()
        }
        .onChange(of: note.body) { _, _ in
            scheduleDraftInterpretation()
            scheduleAutosave()
        }
        .onChange(of: activeNoteLineIndex) { _, _ in
            guard isEditingNote else { return }
            scheduleDraftInterpretation()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                flushAutosave()
                stopForegroundHealthRefresh()
            } else if phase == .active {
                startForegroundHealthRefreshIfNeeded()
            }
        }
        .onChange(of: selectedDayKey) { _, _ in
            restartForegroundHealthRefreshIfNeeded()
        }
        .onDisappear {
            draftInterpretationTask?.cancel()
            backendInterpretationTask?.cancel()
            backendSuggestionTask?.cancel()
            coachCardReplacementTask?.cancel()
            stopForegroundHealthRefresh()
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
                    healthAuthorizationState: healthService.authorizationState(),
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
                    track(AnalyticsEvent(name: "health_data_refreshed", properties: ["source": "settings"]))
                    Task {
                        await loadNote(for: note.date)
                        await refreshProgressStats()
                        await refreshCalendarDays()
                        await loadGoalsProfile()
                    }
                },
                setWorkoutRemindersEnabled: setWorkoutRemindersEnabled,
                submitSupportRequest: submitSupportRequest,
                onSupportOpened: {
                    track(AnalyticsEvent(name: "support_opened", properties: ["source": "settings"]))
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
            reportError("home", "exercise_history_load_failed", nil, error, ["source": "exercise_anchor"])
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
            reportError("home", "cardio_history_load_failed", nil, error, ["source": "cardio_anchor"])
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
                installId: stableInstallId(),
                note: draft,
                result: result,
                goals: goalsProfile,
                store: noteStore,
                activeLineIndex: activeNoteLineIndex,
                recentFeedbackSummary: localFeedbackSummary
            )
            let suggestion = LocalSuggestionEngine.dailySuggestion(context: context) ?? result.suggestion
            let cards = WorkoutCoachCardEngine.cards(
                context: context,
                interpretedLines: result.lines,
                activeLineIndex: activeNoteLineIndex,
                phase: .typing
            )
            await MainActor.run {
                guard note.id == draft.id, note.body == draft.body else { return }
                note.interpretedLines = linesByPreservingAuthoritativePRs(result.lines, currentLines: note.interpretedLines)
                var metrics = result.metrics
                metrics.prCount = note.metrics.prCount
                note.metrics = metrics
                note.suggestion = suggestion ?? note.suggestion
                note.parsedSummary = nil
                applyCoachCards(cards, phase: .typing)
                let targets = backendRepairTargets(for: draft, localResult: result)
                if !targets.isEmpty {
                    scheduleBackendInterpretation(mode: .repair, targetLines: targets, localResult: result)
                }
                scheduleBackendCoachCards(context: context, interpretedLines: result.lines, phase: .typing)
            }
        }
    }

    private func scheduleBackendInterpretation(
        mode: WorkoutInterpretationBackendMode,
        targetLines: [WorkoutInterpretationTargetLine] = [],
        localResult: WorkoutInterpretationResult? = nil
    ) {
        guard featureAccess.canUseInterpretation,
              let backendInterpreter
        else { return }

        backendInterpretationTask?.cancel()
        let draft = note
        let localSummary = localResult.map { backendLocalSummary(for: draft, result: $0, targetLines: targetLines) }
        backendInterpretationTask = Task {
            try? await Task.sleep(for: .milliseconds(mode == .repair ? 900 : 1_400))
            guard !Task.isCancelled else { return }
            let backendResult: WorkoutInterpretationResult
            do {
                backendResult = try await backendInterpreter.interpret(
                    note: draft,
                    mode: mode,
                    targetLines: targetLines,
                    localSummary: localSummary
                )
            } catch {
                reportError("home", "backend_interpretation_failed", nil, error, [
                    "mode": mode.rawValue,
                    "note_length_bucket": Self.noteLengthBucket(draft.body)
                ])
                return
            }
            let result = displaySafeInterpretation(
                mergeBackendInterpretation(
                    backendResult,
                    into: localResult,
                    mode: mode,
                    targetLineIndexes: Set(targetLines.map(\.lineIndex)),
                    note: draft
                )
            )
            guard !Task.isCancelled else { return }
            let context = await SuggestionContextBuilder.build(
                installId: stableInstallId(),
                note: draft,
                result: result,
                goals: goalsProfile,
                store: noteStore,
                activeLineIndex: activeNoteLineIndex,
                recentFeedbackSummary: localFeedbackSummary
            )
            let suggestion = LocalSuggestionEngine.dailySuggestion(context: context) ?? result.suggestion
            let cards = WorkoutCoachCardEngine.cards(
                context: context,
                interpretedLines: result.lines,
                activeLineIndex: activeNoteLineIndex,
                phase: .typing
            )
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
                applyCoachCards(cards, phase: .typing)
                scheduleBackendCoachCards(context: context, interpretedLines: result.lines, phase: .typing)
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

    @MainActor
    private func applyCoachCards(_ cards: [WorkoutCoachCard], phase: WorkoutCoachCardPhase) {
        guard featureAccess.canUseSuggestions else {
            coachCards = []
            pendingCoachCards = nil
            coachCardReplacementTask?.cancel()
            return
        }

        let nextCards = Array(cards.prefix(phase.maximumVisibleCards)).map { card in
            var next = card
            if feedbackSubmittedCoachCardKeys.contains(card.stableDisplayKey) {
                next.feedbackEligible = false
            }
            return next
        }
        guard !nextCards.isEmpty else {
            if phase == .typing,
               let current = coachCards.first,
               WorkoutCoachCardDisplayPolicy.remainingVisibleTime(
                current: current,
                shownAt: coachCardsShownAt
               ) > 0 {
                return
            }
            coachCards = []
            pendingCoachCards = nil
            coachCardReplacementTask?.cancel()
            return
        }

        guard let current = coachCards.first else {
            setVisibleCoachCards(nextCards)
            return
        }

        if sameCoachCardStack(coachCards, nextCards) {
            coachCards = nextCards
            return
        }

        let sameVisibleIdentity = coachCards.map(\.stableDisplayKey) == nextCards.map(\.stableDisplayKey)
        let remaining = WorkoutCoachCardDisplayPolicy.remainingVisibleTime(
            current: current,
            shownAt: coachCardsShownAt
        )
        if phase == .typing,
           sameVisibleIdentity,
           remaining > 0 {
            return
        }

        guard remaining > 0 else {
            setVisibleCoachCards(nextCards)
            return
        }

        pendingCoachCards = nextCards
        coachCardReplacementTask?.cancel()
        coachCardReplacementTask = Task {
            try? await Task.sleep(for: .milliseconds(Int((remaining * 1_000).rounded())))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if let pendingCoachCards {
                    setVisibleCoachCards(pendingCoachCards)
                    self.pendingCoachCards = nil
                }
            }
        }
    }

    @MainActor
    private func setVisibleCoachCards(_ cards: [WorkoutCoachCard]) {
        let previousKeys = Set(coachCards.map(\.stableDisplayKey))
        coachCards = cards
        coachCardsShownAt = Date()
        for card in cards where !viewedCoachCardKeys.contains(card.stableDisplayKey) {
            viewedCoachCardKeys.insert(card.stableDisplayKey)
            track(
                AnalyticsEvent(
                    name: "suggestion_viewed",
                    properties: coachCardAnalyticsProperties(card)
                )
            )
        }
        if !previousKeys.isEmpty,
           previousKeys != Set(cards.map(\.stableDisplayKey)) {
            track(
                AnalyticsEvent(
                    name: "suggestion_replaced",
                    properties: [
                        "count": "\(cards.count)",
                        "next_kind": cards.first?.kind.rawValue ?? "none",
                        "next_source": cards.first?.source.rawValue ?? "none"
                    ]
                )
            )
        }
    }

    private func sameCoachCardStack(_ lhs: [WorkoutCoachCard], _ rhs: [WorkoutCoachCard]) -> Bool {
        lhs.map(coachCardSignature) == rhs.map(coachCardSignature)
    }

    private func coachCardSignature(_ card: WorkoutCoachCard) -> String {
        "\(card.kind.rawValue)|\(card.title)|\(card.metadata ?? "")|\(card.text)|\(card.affectedExerciseKey ?? "")"
    }

    private func coachCardAnalyticsProperties(_ card: WorkoutCoachCard) -> [String: String] {
        [
            "kind": card.kind.rawValue,
            "source": card.source.rawValue,
            "goal": card.coarseContext["goal"] ?? "unknown",
            "set_bucket": card.coarseContext["setBucket"] ?? "unknown",
            "active_set_bucket": card.coarseContext["activeSetBucket"] ?? "unknown",
            "pr_bucket": card.coarseContext["prBucket"] ?? "none",
            "pattern": card.coarseContext["pattern"] ?? "none",
            "feedback_eligible": card.feedbackEligible ? "true" : "false",
            "evidence": card.coarseContext["evidence"] ?? "none"
        ]
    }

    private func scheduleBackendCoachCards(
        context: WorkoutSuggestionRequestContext,
        interpretedLines: [InterpretedWorkoutLine],
        phase: WorkoutCoachCardPhase
    ) {
        guard featureAccess.canUseSuggestions, let suggestionBackend else { return }
        let activeExerciseKey = phase == .typing
            ? WorkoutCoachCardEngine.activeExerciseKey(
                interpretedLines: interpretedLines,
                activeLineIndex: activeNoteLineIndex
            )
            : nil
        backendSuggestionTask?.cancel()
        backendSuggestionTask = Task {
            do {
                let response = try await suggestionBackend.suggestions(
                    for: context,
                    accessToken: await accessTokenProvider()
                )
                let cards = WorkoutCoachCardEngine.cards(
                    from: response,
                    context: context,
                    activeExerciseKey: activeExerciseKey,
                    phase: phase
                )
                guard !Task.isCancelled, !cards.isEmpty else { return }
                await MainActor.run {
                    applyCoachCards(cards, phase: phase)
                }
            } catch {
                reportError("home", "backend_suggestions_failed", nil, error, [
                    "session_kind": context.sessionKind,
                    "set_count_bucket": Self.countBucket(context.metrics.totalSets)
                ])
            }
        }
    }

    private func handleCoachCardFeedback(_ card: WorkoutCoachCard, action: SuggestionFeedbackAction) {
        feedbackSubmittedCoachCardKeys.insert(card.stableDisplayKey)
        for tag in card.coarseContext["evidence"]?.split(separator: ",").map(String.init) ?? [] {
            let key = "\(tag).\(action.rawValue)"
            localFeedbackSummary[key, default: 0] += 1
        }
        track(
            AnalyticsEvent(
                name: "suggestion_feedback_submitted",
                properties: coachCardAnalyticsProperties(card).merging(["action": action.rawValue]) { current, _ in current }
            )
        )

        guard let suggestionBackend else { return }
        let feedback = SuggestionFeedback(
            installId: stableInstallId(),
            suggestionId: card.id,
            suggestionType: "daily",
            action: action,
            source: card.source,
            coarseContext: card.coarseContext
        )
        Task {
            do {
                try await suggestionBackend.sendFeedback(
                    feedback,
                    accessToken: await accessTokenProvider()
                )
            } catch {
                reportError("home", "suggestion_feedback_failed", nil, error, ["kind": card.kind.rawValue])
            }
        }
    }

    private var selectedDayKey: String {
        SQLiteWorkoutLocalStore.dayKey(for: note.date)
    }

    private func stableInstallId() -> String {
        if installId.count >= 8 {
            return installId
        }
        let next = UUID().uuidString.lowercased()
        installId = next
        return next
    }

    private func loadNote(for date: Date) async {
        guard !isLoadingNote else { return }
        isLoadingNote = true
        defer { isLoadingNote = false }
        let store = noteStore
        do {
            let loaded = try await store.note(for: date)
            let coachResult = await coachCardInterpretation(for: loaded)
            let context = await SuggestionContextBuilder.build(
                installId: stableInstallId(),
                note: loaded,
                result: coachResult,
                goals: goalsProfile,
                store: store,
                recentFeedbackSummary: localFeedbackSummary
            )
            let cards = WorkoutCoachCardEngine.cards(
                context: context,
                interpretedLines: loaded.interpretedLines,
                phase: .saved
            )
            await MainActor.run {
                note = loaded
                applyCoachCards(cards, phase: .saved)
                scheduleBackendInterpretation(mode: .audit, localResult: coachResult)
                scheduleBackendCoachCards(context: context, interpretedLines: loaded.interpretedLines, phase: .saved)
            }
        } catch {
            reportError("home", "note_load_failed", nil, error, ["day": SQLiteWorkoutLocalStore.dayKey(for: date)])
            await MainActor.run {
                note.lastSyncError = "Could not load this workout note."
            }
        }
    }

    private func coachCardInterpretation(for note: DailyWorkoutNote) async -> WorkoutInterpretationResult {
        var result = await interpreter.interpret(note: note)
        result.lines = note.interpretedLines.isEmpty ? result.lines : note.interpretedLines
        result.metrics = note.metrics
        result.suggestion = note.suggestion
        return result
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
            do {
                try await store.save(draft)
                track(AnalyticsEvent(name: "note_saved", properties: Self.noteAnalyticsProperties(for: draft)))
                await scheduleWorkoutReminder(after: draft)
                await maybeShowReviewPrompt(afterSaving: draft)
            } catch {
                reportError("home", "note_save_failed", nil, error, ["note_length_bucket": Self.noteLengthBucket(draft.body)])
            }
            await onWorkoutDataSaved?()
            if let refreshed = try? await store.note(for: draft.date), !Task.isCancelled {
                let coachResult = await coachCardInterpretation(for: refreshed)
                let context = await SuggestionContextBuilder.build(
                    installId: stableInstallId(),
                    note: refreshed,
                    result: coachResult,
                    goals: goalsProfile,
                    store: store,
                    recentFeedbackSummary: localFeedbackSummary
                )
                let cards = WorkoutCoachCardEngine.cards(
                    context: context,
                    interpretedLines: refreshed.interpretedLines,
                    phase: .saved
                )
                await MainActor.run {
                    note.interpretedLines = refreshed.interpretedLines
                    note.metrics = refreshed.metrics
                    note.suggestion = refreshed.suggestion
                    note.parsedSummary = nil
                    applyCoachCards(cards, phase: .saved)
                    scheduleBackendInterpretation(mode: .audit, localResult: coachResult)
                    scheduleBackendCoachCards(context: context, interpretedLines: refreshed.interpretedLines, phase: .saved)
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
            do {
                try await store.save(draft)
                track(AnalyticsEvent(name: "note_saved", properties: Self.noteAnalyticsProperties(for: draft).merging(["flush": "true"]) { current, _ in current }))
                await scheduleWorkoutReminder(after: draft)
                await maybeShowReviewPrompt(afterSaving: draft)
            } catch {
                reportError("home", "note_flush_save_failed", nil, error, ["note_length_bucket": Self.noteLengthBucket(draft.body)])
            }
            await onWorkoutDataSaved?()
            if let refreshed = try? await store.note(for: draft.date) {
                let coachResult = await coachCardInterpretation(for: refreshed)
                let context = await SuggestionContextBuilder.build(
                    installId: stableInstallId(),
                    note: refreshed,
                    result: coachResult,
                    goals: goalsProfile,
                    store: store,
                    recentFeedbackSummary: localFeedbackSummary
                )
                let cards = WorkoutCoachCardEngine.cards(
                    context: context,
                    interpretedLines: refreshed.interpretedLines,
                    phase: .saved
                )
                await MainActor.run {
                    note.interpretedLines = refreshed.interpretedLines
                    note.metrics = refreshed.metrics
                    note.suggestion = refreshed.suggestion
                    note.parsedSummary = nil
                    applyCoachCards(cards, phase: .saved)
                    scheduleBackendInterpretation(mode: .audit, localResult: coachResult)
                    scheduleBackendCoachCards(context: context, interpretedLines: refreshed.interpretedLines, phase: .saved)
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
            reportError("home", "calendar_refresh_failed", nil, error, [:])
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
            reportError("home", "progress_stats_refresh_failed", nil, error, [:])
            await MainActor.run {
                note.lastSyncError = "Could not refresh progress stats."
            }
        }
    }

    private func startForegroundHealthRefreshIfNeeded() {
        guard scenePhase == .active,
              featureAccess.canUseHealth,
              healthService.authorizationState().isConnectedLike,
              foregroundHealthRefreshTask == nil
        else { return }

        foregroundHealthRefreshTask = Task {
            while !Task.isCancelled {
                await refreshForegroundHealthData()
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func restartForegroundHealthRefreshIfNeeded() {
        stopForegroundHealthRefresh()
        startForegroundHealthRefreshIfNeeded()
    }

    private func stopForegroundHealthRefresh() {
        foregroundHealthRefreshTask?.cancel()
        foregroundHealthRefreshTask = nil
        isRefreshingForegroundHealth = false
    }

    private func refreshForegroundHealthData() async {
        guard !isRefreshingForegroundHealth else { return }
        isRefreshingForegroundHealth = true
        defer { isRefreshingForegroundHealth = false }

        do {
            let previousMetric = try? await noteStore.healthDailyMetric(for: note.date)
            let previousWorkouts = (try? await noteStore.healthWorkoutSamples(on: note.date)) ?? []
            let previousMatch = try? await noteStore.healthWorkoutMatch(for: note.id)
            let refreshed = try await healthService.refreshHealthData(for: note.date)
            if let metric = refreshed.dailyMetric {
                try await noteStore.save(metric)
            }
            try await noteStore.save(refreshed.workouts)

            let match = healthService.matchWorkout(note: note, workouts: refreshed.workouts)
            if let match {
                try await noteStore.save(match)
            }
            if healthDataChanged(
                previousMetric: previousMetric,
                refreshedMetric: refreshed.dailyMetric,
                previousWorkouts: previousWorkouts,
                refreshedWorkouts: refreshed.workouts,
                previousMatch: previousMatch,
                refreshedMatch: match
            ) {
                try await noteStore.save(note)
                await onWorkoutDataSaved?()
                track(AnalyticsEvent(name: "health_data_refreshed", properties: ["source": "foreground_loop"]))
            }

            let refreshedNote = try await noteStore.note(for: note.date)
            await MainActor.run {
                note.metrics = refreshedNote.metrics
                note.interpretedLines = refreshedNote.interpretedLines
                note.suggestion = refreshedNote.suggestion
                note.parsedSummary = refreshedNote.parsedSummary
                note.lastSyncError = nil
            }
            await refreshProgressStats()
            await refreshCalendarDays()
        } catch {
            reportError(
                "health",
                "foreground_health_refresh_failed",
                nil,
                error,
                ["source": "home_foreground_loop"]
            )
        }
    }

    private func healthDataChanged(
        previousMetric: HealthDailyMetric?,
        refreshedMetric: HealthDailyMetric?,
        previousWorkouts: [HealthWorkoutSample],
        refreshedWorkouts: [HealthWorkoutSample],
        previousMatch: HealthWorkoutMatch?,
        refreshedMatch: HealthWorkoutMatch?
    ) -> Bool {
        let meaningfulMetricChanged: Bool
        if let refreshedMetric, Self.hasHealthMetricValue(refreshedMetric) {
            meaningfulMetricChanged = previousMetric != refreshedMetric
        } else {
            meaningfulMetricChanged = false
        }
        return meaningfulMetricChanged
            || Set(previousWorkouts) != Set(refreshedWorkouts)
            || previousMatch != refreshedMatch
    }

    private static func hasHealthMetricValue(_ metric: HealthDailyMetric) -> Bool {
        metric.activeEnergyCalories != nil
            || metric.averageHeartRate != nil
            || metric.maxHeartRate != nil
            || metric.bodyweightValue != nil
            || metric.workoutDurationMinutes != nil
    }

    private func loadGoalsProfile() async {
        do {
            let profile = try await noteStore.trainingGoalsProfile()
            await MainActor.run {
                goalsProfile = profile
            }
        } catch {
            reportError("home", "goals_profile_load_failed", nil, error, [:])
            await MainActor.run {
                goalsProfile = BramPreviewData.goalsProfile
            }
        }
    }

    private func saveGoalsProfile(_ profile: TrainingGoalsProfile) {
        goalsProfile = profile
        let store = noteStore
        Task {
            do {
                try await store.save(profile)
            } catch {
                reportError("settings", "local_goals_save_failed", nil, error, [:])
            }
            await onGoalsProfileSave?(profile)
        }
    }

    private static func noteAnalyticsProperties(for note: DailyWorkoutNote) -> [String: String] {
        [
            "note_length_bucket": noteLengthBucket(note.body),
            "set_count_bucket": countBucket(note.metrics.totalSets),
            "interpreted_line_count_bucket": countBucket(note.interpretedLines.count),
            "cardio_minutes_bucket": countBucket(note.metrics.cardioMinutes),
            "has_pr": note.metrics.prCount > 0 ? "true" : "false"
        ]
    }

    private func backendRepairTargets(
        for note: DailyWorkoutNote,
        localResult: WorkoutInterpretationResult
    ) -> [WorkoutInterpretationTargetLine] {
        guard backendInterpreter != nil else { return [] }
        let interpretedLineIndexes = Set(localResult.lines.map(\.lineIndex))
        let lowConfidenceLineIndexes = Set(
            localResult.lines
                .filter { $0.confidence < 0.72 && ($0.kind == .strength || $0.kind == .cardio) }
                .map(\.lineIndex)
        )
        let rawLines = note.body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        return rawLines.enumerated().compactMap { index, rawLine in
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if interpretedLineIndexes.contains(index), lowConfidenceLineIndexes.contains(index) == false {
                return nil
            }
            guard Self.looksLikeUnresolvedWorkoutLine(trimmed) else { return nil }
            return WorkoutInterpretationTargetLine(lineIndex: index, text: trimmed)
        }
    }

    private func backendLocalSummary(
        for note: DailyWorkoutNote,
        result: WorkoutInterpretationResult,
        targetLines: [WorkoutInterpretationTargetLine]
    ) -> WorkoutInterpretationLocalSummary {
        WorkoutInterpretationLocalSummary(
            interpretedLineIndexes: result.lines.map(\.lineIndex).sorted(),
            lowConfidenceLineIndexes: result.lines
                .filter { $0.confidence < 0.72 && ($0.kind == .strength || $0.kind == .cardio) }
                .map(\.lineIndex)
                .sorted(),
            totalSets: result.metrics.totalSets,
            cardioMinutes: result.metrics.cardioMinutes,
            unresolvedLineCount: targetLines.count
        )
    }

    private func mergeBackendInterpretation(
        _ backend: WorkoutInterpretationResult,
        into local: WorkoutInterpretationResult?,
        mode: WorkoutInterpretationBackendMode,
        targetLineIndexes: Set<Int>,
        note: DailyWorkoutNote
    ) -> WorkoutInterpretationResult {
        guard let local, mode == .repair else {
            return backend.lines.isEmpty ? (local ?? backend) : recomputedMetrics(for: backend, note: note)
        }

        guard !backend.lines.isEmpty else { return local }
        let backendLinesByIndex = backend.lines.reduce(into: [Int: InterpretedWorkoutLine]()) { result, line in
            result[line.lineIndex] = line
        }
        let localNonTargetLines = local.lines.filter { targetLineIndexes.contains($0.lineIndex) == false }
        let mergedLines = (localNonTargetLines + backendLinesByIndex.values)
            .sorted { $0.lineIndex < $1.lineIndex }
        let mergedStrengthSets = local.strengthSets.filter { set in
            guard let lineIndex = set.lineIndex else { return true }
            return targetLineIndexes.contains(lineIndex) == false
        } + backend.strengthSets.filter { set in
            guard let lineIndex = set.lineIndex else { return true }
            return targetLineIndexes.contains(lineIndex)
        }
        let mergedCardioEntries = local.cardioEntries.filter { entry in
            guard let lineIndex = entry.lineIndex else { return true }
            return targetLineIndexes.contains(lineIndex) == false
        } + backend.cardioEntries.filter { entry in
            guard let lineIndex = entry.lineIndex else { return true }
            return targetLineIndexes.contains(lineIndex)
        }

        return recomputedMetrics(
            for: WorkoutInterpretationResult(
                lines: mergedLines,
                metrics: local.metrics,
                suggestion: backend.suggestion ?? local.suggestion,
                strengthSets: mergedStrengthSets,
                cardioEntries: mergedCardioEntries,
                prEvents: []
            ),
            note: note
        )
    }

    private func recomputedMetrics(
        for result: WorkoutInterpretationResult,
        note: DailyWorkoutNote
    ) -> WorkoutInterpretationResult {
        var output = result
        let cardioMinutes = result.cardioEntries.reduce(0) { total, entry in
            total + (entry.durationMinutes ?? 0)
        }
        output.metrics = WorkoutMetricSnapshot(
            totalSets: result.strengthSets.count,
            hardSets: result.strengthSets.filter { Self.isHardEffort($0.effort) }.count,
            estimatedVolume: result.strengthSets.reduce(0) { $0 + Int($1.load) * $1.reps },
            prCount: result.metrics.prCount,
            streakDays: note.metrics.streakDays,
            cardioMinutes: cardioMinutes,
            activeEnergyCalories: result.metrics.activeEnergyCalories,
            energyIsEstimated: result.metrics.energyIsEstimated,
            averageHeartRate: result.metrics.averageHeartRate,
            workoutDurationMinutes: cardioMinutes > 0 ? cardioMinutes : result.metrics.workoutDurationMinutes,
            parseState: note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .parsed
        )
        return output
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

    private static func looksLikeUnresolvedWorkoutLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.count < 5 { return false }
        if lower.contains("@") { return false }
        if lower.range(of: #"^\s*[a-z]{3,9}\s+\d{1,2}\b"#, options: .regularExpression) != nil {
            return false
        }

        let hasTrainingTerm = [
            "bench", "press", "squat", "deadlift", "curl", "row", "raise",
            "run", "ran", "jog", "walk", "bike", "cycle", "rowed", "cardio",
            "set", "sets", "reps", "rpe", "rir", "failure"
        ].contains { lower.contains($0) }
        let hasTrainingNumber = lower.range(
            of: #"\b\d+(?:\.\d+)?\s*(?:x|for|min|mins|minutes|mi|mile|miles|km|k|lb|lbs|s\b)"#,
            options: .regularExpression
        ) != nil

        return hasTrainingTerm && hasTrainingNumber
    }

    private func setWorkoutRemindersEnabled(_ isEnabled: Bool) async -> Bool {
        guard let reminderService else { return false }
        if !isEnabled {
            workoutRemindersEnabled = false
            await reminderService.cancelReminders()
            track(
                AnalyticsEvent(
                    name: "workout_reminders_preference_set",
                    properties: ["enabled": "false"]
                )
            )
            return false
        }

        do {
            let granted = try await reminderService.requestAuthorization()
            workoutRemindersEnabled = granted
            track(
                AnalyticsEvent(
                    name: "workout_reminders_permission_set",
                    properties: ["granted": granted ? "true" : "false"]
                )
            )
            if granted {
                await reminderService.scheduleReminder(after: note, goals: goalsProfile)
            }
            return granted
        } catch {
            reportError("settings", "workout_reminders_permission_failed", nil, error, [:])
            workoutRemindersEnabled = false
            return false
        }
    }

    private func scheduleWorkoutReminder(after draft: DailyWorkoutNote) async {
        guard workoutRemindersEnabled else { return }
        guard isWorkoutLike(draft) else { return }
        await reminderService?.scheduleReminder(after: draft, goals: goalsProfile)
    }

    @MainActor
    private func maybeShowReviewPrompt(afterSaving draft: DailyWorkoutNote) {
        guard shouldShowReviewPrompt(for: draft) else { return }
        reviewPromptCount += 1
        reviewLastPromptAt = Date().timeIntervalSince1970
        reviewFirstWorkoutPrompted = true
        showingReviewPrompt = true
        track(AnalyticsEvent(name: "review_prompt_viewed", properties: ["source": "first_workout"]))
    }

    private func shouldShowReviewPrompt(for draft: DailyWorkoutNote) -> Bool {
        guard !reviewPromptDisabled,
              !reviewFirstWorkoutPrompted,
              reviewPromptCount < 2,
              !showingReviewPrompt,
              isWorkoutLike(draft)
        else { return false }

        let minimumSpacing: TimeInterval = 60 * 60 * 24 * 90
        return reviewLastPromptAt == 0 || Date().timeIntervalSince1970 - reviewLastPromptAt > minimumSpacing
    }

    private func isWorkoutLike(_ draft: DailyWorkoutNote) -> Bool {
        let trimmedLength = draft.body.trimmingCharacters(in: .whitespacesAndNewlines).count
        return trimmedLength >= 20
            || draft.metrics.totalSets > 0
            || draft.metrics.cardioMinutes > 0
            || !draft.interpretedLines.isEmpty
    }

    private static func noteLengthBucket(_ body: String) -> String {
        let count = body.trimmingCharacters(in: .whitespacesAndNewlines).count
        switch count {
        case 0: return "empty"
        case 1..<80: return "short"
        case 80..<300: return "medium"
        case 300..<900: return "long"
        default: return "very_long"
        }
    }

    private static func countBucket(_ count: Int) -> String {
        switch count {
        case 0: "0"
        case 1...2: "1_2"
        case 3...5: "3_5"
        case 6...10: "6_10"
        default: "11_plus"
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

private struct ReviewPromptSheet: View {
    let onYes: () -> Void
    let onNotNow: () -> Void
    let onNever: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                BramLogoMark(size: 38)
                Spacer()
                Button(action: onNotNow) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BramColor.textTertiary)
                        .frame(width: 34, height: 34)
                        .background(BramColor.cardSurface, in: Circle())
                }
                .accessibilityLabel("Close")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Is Bram working for you?")
                    .font(BramFont.largeTitle(size: 30))
                    .foregroundStyle(BramColor.textPrimary)
                Text("A quick App Store review helps more lifters find Bram.")
                    .font(BramFont.body(size: 16))
                    .foregroundStyle(BramColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Button(action: onYes) {
                Text("Yes, leave a review")
                    .font(BramFont.button(size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(BramColor.violet, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 18) {
                Button("Not now", action: onNotNow)
                Button("Don't ask again", action: onNever)
            }
            .font(BramFont.label(size: 13))
            .foregroundStyle(BramColor.textTertiary)
            .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(BramColor.appBackground)
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
