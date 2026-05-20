import SwiftUI

struct HealthConnectionView: View {
    let note: DailyWorkoutNote
    let noteStore: any WorkoutLocalStore
    let healthService: any AppleHealthProviding
    let onUpdated: () -> Void

    init(
        note: DailyWorkoutNote,
        noteStore: any WorkoutLocalStore = SQLiteWorkoutLocalStore.shared,
        healthService: any AppleHealthProviding = AppleHealthService(),
        onUpdated: @escaping () -> Void = {}
    ) {
        self.note = note
        self.noteStore = noteStore
        self.healthService = healthService
        self.onUpdated = onUpdated
    }

    var body: some View {
        BramPanelChrome(title: "Apple Health") {
            HealthConnectionContent(
                note: note,
                noteStore: noteStore,
                healthService: healthService,
                onUpdated: onUpdated
            )
        }
    }
}

struct HealthConnectionContent: View {
    let note: DailyWorkoutNote
    let noteStore: any WorkoutLocalStore
    let healthService: any AppleHealthProviding
    let onUpdated: () -> Void

    @State private var authorizationState: HealthAuthorizationState
    @State private var dailyMetric: HealthDailyMetric?
    @State private var workouts: [HealthWorkoutSample] = []
    @State private var match: HealthWorkoutMatch?
    @State private var isRefreshing = false
    @State private var message: String?

    init(
        note: DailyWorkoutNote,
        noteStore: any WorkoutLocalStore = SQLiteWorkoutLocalStore.shared,
        healthService: any AppleHealthProviding = AppleHealthService(),
        onUpdated: @escaping () -> Void = {}
    ) {
        self.note = note
        self.noteStore = noteStore
        self.healthService = healthService
        self.onUpdated = onUpdated
        _authorizationState = State(initialValue: healthService.authorizationState())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusCard

            if hasConnectedMetrics {
                metricGrid
            }

            Button(action: refreshTapped) {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(primaryButtonTitle)
                        .font(BramFont.button())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(BramColor.violet, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing || !authorizationState.canAttemptRefresh)

            if let message {
                Text(message)
                    .font(BramFont.callout(size: 13))
                    .foregroundStyle(BramColor.textSecondary)
            }
        }
        .task {
            await loadLocalHealthState()
        }
    }

    private var statusCard: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(statusColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusTitle)
                            .font(BramFont.headline())
                            .foregroundStyle(BramColor.textPrimary)
                        Text(statusSubtitle)
                            .font(BramFont.callout())
                            .foregroundStyle(BramColor.textSecondary)
                    }
                }

                Text("Bram reads workouts, energy, heart rate, distance, and bodyweight to connect notes to progress. Health data is not used for ads, marketing, or analytics profiling.")
                    .font(BramFont.callout(size: 13))
                    .foregroundStyle(BramColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            HealthMetricTile(title: "Energy", value: energyText, icon: "flame.fill", color: BramColor.energy)
            HealthMetricTile(title: "Heart Rate", value: heartRateText, icon: "heart.fill", color: BramColor.recovery)
            HealthMetricTile(title: "Duration", value: durationText, icon: "clock.fill", color: BramColor.cool)
            HealthMetricTile(title: "Match", value: match?.matchQuality.label ?? "none", icon: "link", color: BramColor.violet)
        }
    }

    private var hasConnectedMetrics: Bool {
        dailyMetric != nil || !workouts.isEmpty || match != nil
    }

    private var primaryButtonTitle: String {
        switch authorizationState {
        case .unavailable:
            "Health unavailable"
        case .notRequested:
            "Continue"
        case .requested, .connected, .connectedNoRecentData:
            "Refresh Health Data"
        case .accessNeedsReview, .error:
            "Try Again"
        }
    }

    private var statusTitle: String {
        switch authorizationState {
        case .unavailable:
            "Health is unavailable"
        case .notRequested:
            "Connect when you want Health-backed stats"
        case .requested:
            "Health access is ready"
        case .connected, .connectedNoRecentData:
            "Health is connected"
        case .accessNeedsReview:
            "Health access needs review"
        case .error:
            "Health could not refresh"
        }
    }

    private var statusSubtitle: String {
        switch authorizationState {
        case .unavailable:
            "HealthKit needs a supported iPhone."
        case .notRequested:
            "Permissions are requested only from this screen."
        case .requested:
            "Refresh to import recent workouts and daily metrics."
        case .connected:
            "Energy, duration, heart rate, and bodyweight can improve progress."
        case .connectedNoRecentData:
            "No recent Health workouts were found yet."
        case .accessNeedsReview:
            "Check Bram in iOS Health data access, then refresh."
        case .error:
            "Try again. If this continues, check Health permissions."
        }
    }

    private var statusIcon: String {
        switch authorizationState {
        case .unavailable, .accessNeedsReview, .error:
            "heart.slash"
        case .notRequested, .requested:
            "heart"
        case .connected, .connectedNoRecentData:
            "heart.fill"
        }
    }

    private var statusColor: Color {
        switch authorizationState {
        case .connected:
            BramColor.recovery
        case .connectedNoRecentData, .accessNeedsReview:
            BramColor.energy
        case .unavailable, .notRequested, .requested, .error:
            BramColor.textTertiary
        }
    }

    private var energyText: String {
        if let energy = dailyMetric?.activeEnergyCalories { return "\(energy) cal" }
        if let energy = workouts.compactMap(\.activeEnergyCalories).reduceOptional(+) { return "\(energy) cal" }
        return "--"
    }

    private var heartRateText: String {
        if let heartRate = dailyMetric?.averageHeartRate { return "\(heartRate) bpm" }
        if let heartRate = workouts.compactMap(\.averageHeartRate).average { return "\(heartRate) bpm" }
        return "--"
    }

    private var durationText: String {
        let minutes = dailyMetric?.workoutDurationMinutes ?? workouts.reduce(0) { $0 + $1.durationMinutes }
        return minutes > 0 ? "\(minutes) min" : "--"
    }

    private func refreshTapped() {
        Task {
            await connectAndRefresh()
        }
    }

    private func loadLocalHealthState() async {
        let store = noteStore
        let metric = try? await store.healthDailyMetric(for: note.date)
        let samples = (try? await store.healthWorkoutSamples(on: note.date)) ?? []
        let storedMatch = try? await store.healthWorkoutMatch(for: note.id)
        let hasLocalHealthData = metric != nil || !samples.isEmpty || storedMatch != nil
        await MainActor.run {
            dailyMetric = metric
            workouts = samples
            match = storedMatch
            authorizationState = .afterLocalLoad(
                currentState: authorizationState,
                hasLocalHealthData: hasLocalHealthData
            )
        }
    }

    private func connectAndRefresh() async {
        guard !isRefreshing else { return }
        await MainActor.run {
            isRefreshing = true
            message = nil
        }
        defer {
            Task { @MainActor in isRefreshing = false }
        }

        do {
            _ = try await healthService.requestAuthorization()
            let range = recentImportRange()
            async let recentMetrics = healthService.dailyMetrics(from: range.start, to: range.end)
            async let recentWorkouts = healthService.workouts(from: range.start, to: range.end)
            let refreshedMetrics = try await recentMetrics
            let refreshedWorkouts = try await recentWorkouts
            for metric in refreshedMetrics {
                try await noteStore.save(metric)
            }
            try await noteStore.save(refreshedWorkouts)

            let noteMetric = metric(for: note.date, in: refreshedMetrics)
            let noteWorkouts = samples(on: note.date, in: refreshedWorkouts)
            let newMatch = healthService.matchWorkout(note: note, workouts: noteWorkouts)
            if let newMatch {
                try await noteStore.save(newMatch)
            }
            try await noteStore.save(note)

            let hasImportedHealthData = refreshedMetrics.contains(where: hasMetricValue) || !refreshedWorkouts.isEmpty
            let state = HealthAuthorizationState.afterSuccessfulRefresh(hasImportedHealthData: hasImportedHealthData)
            await MainActor.run {
                authorizationState = state
                dailyMetric = noteMetric
                workouts = noteWorkouts
                match = newMatch
                message = refreshMessage(
                    hasImportedHealthData: hasImportedHealthData,
                    hasNoteHealthData: noteMetric != nil || !noteWorkouts.isEmpty || newMatch != nil
                )
                onUpdated()
            }
        } catch {
#if DEBUG
            print("Bram Health refresh failed: \(error.localizedDescription)")
#endif
            await MainActor.run {
                authorizationState = .accessNeedsReview
#if DEBUG
                message = "Bram could not read Health data: \(error.localizedDescription)"
#else
                message = "Bram could not read Health data. Check Bram in iOS Health data access, then try again."
#endif
            }
        }
    }

    private func recentImportRange() -> DateInterval {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? note.date.addingTimeInterval(-30 * 86_400)
        return DateInterval(start: start, end: end)
    }

    private func metric(for date: Date, in metrics: [HealthDailyMetric]) -> HealthDailyMetric? {
        metrics.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func samples(on date: Date, in samples: [HealthWorkoutSample]) -> [HealthWorkoutSample] {
        samples.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    private func hasMetricValue(_ metric: HealthDailyMetric) -> Bool {
        metric.activeEnergyCalories != nil ||
            metric.averageHeartRate != nil ||
            metric.maxHeartRate != nil ||
            metric.bodyweightValue != nil ||
            metric.workoutDurationMinutes != nil
    }

    private func refreshMessage(hasImportedHealthData: Bool, hasNoteHealthData: Bool) -> String {
        if hasNoteHealthData {
            return "Health data refreshed for this day."
        }
        if hasImportedHealthData {
            return "Health is connected. No Health data was found for this day yet."
        }
        return "Health is connected. No recent Health workouts were found yet."
    }
}

private struct HealthMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        BramCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(BramFont.label(size: 15))
                    .foregroundStyle(BramColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(BramFont.label(size: 11))
                    .foregroundStyle(BramColor.textTertiary)
            }
        }
    }
}

private extension Array where Element == Int {
    var average: Int? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / count
    }

    func reduceOptional(_ combine: (Int, Int) -> Int) -> Int? {
        guard let first else { return nil }
        return dropFirst().reduce(first, combine)
    }
}

#Preview {
    HealthConnectionView(note: BramPreviewData.populatedNote)
        .preferredColorScheme(.dark)
}
