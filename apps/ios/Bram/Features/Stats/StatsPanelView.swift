import SwiftUI

struct StatsPanelView: View {
    let stats: StatsWeekSnapshot
    let selectedDate: Date
    let noteStore: any WorkoutLocalStore
    let healthAuthorizationState: HealthAuthorizationState
    let referralProgram: ReferralProgramStatus?
    let track: (AnalyticsEvent) -> Void
    @State private var selectedMode: StatsMode
    @State private var selectedPeriod: StatsPeriod = .week
    @State private var anchorDate: Date
    @State private var visibleStats: StatsWeekSnapshot

    init(
        stats: StatsWeekSnapshot,
        selectedDate: Date = .now,
        noteStore: any WorkoutLocalStore = SQLiteWorkoutLocalStore.shared,
        healthAuthorizationState: HealthAuthorizationState = .notRequested,
        referralProgram: ReferralProgramStatus? = nil,
        initialMode: StatsMode = .stats,
        track: @escaping (AnalyticsEvent) -> Void = { _ in }
    ) {
        self.stats = stats
        self.selectedDate = selectedDate
        self.noteStore = noteStore
        self.healthAuthorizationState = healthAuthorizationState
        self.referralProgram = referralProgram
        self.track = track
        _selectedMode = State(initialValue: initialMode)
        _anchorDate = State(initialValue: selectedDate)
        _visibleStats = State(initialValue: stats)
    }

    var body: some View {
        BramPanelChrome(title: "Progress") {
            Picker("Mode", selection: $selectedMode) {
                Text("Stats").tag(StatsMode.stats)
                Text("Streaks").tag(StatsMode.streaks)
            }
            .pickerStyle(.segmented)

            if selectedMode == .stats {
                StatsOverview(
                    stats: visibleStats,
                    healthAuthorizationState: healthAuthorizationState,
                    selectedPeriod: $selectedPeriod,
                    previousPeriod: { shiftPeriod(by: -1) },
                    nextPeriod: { shiftPeriod(by: 1) }
                )
            } else {
                StreakOverview(stats: visibleStats, referralProgram: referralProgram, track: track)
            }
        }
        .task(id: "\(selectedPeriod.rawValue)-\(SQLiteWorkoutLocalStore.dayKey(for: anchorDate))") {
            await loadStats()
        }
    }

    private func shiftPeriod(by value: Int) {
        guard let nextDate = Calendar.current.date(byAdding: selectedPeriod.calendarComponent, value: value, to: anchorDate) else { return }
        withAnimation(.snappy) {
            anchorDate = nextDate
        }
    }

    private func loadStats() async {
        if let loaded = try? await noteStore.stats(for: selectedPeriod, containing: anchorDate) {
            await MainActor.run {
                withAnimation(.snappy) {
                    visibleStats = loaded
                }
            }
        }
    }
}

enum StatsMode {
    case stats
    case streaks
}

private struct StatsOverview: View {
    let stats: StatsWeekSnapshot
    let healthAuthorizationState: HealthAuthorizationState
    @Binding var selectedPeriod: StatsPeriod
    let previousPeriod: () -> Void
    let nextPeriod: () -> Void

    private var healthPresentation: AppleHealthProgressPresentation {
        .make(state: healthAuthorizationState, stats: stats)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(stats.dateRangeTitle)
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .foregroundStyle(BramColor.textPrimary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 2) {
                    Button(action: previousPeriod) {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous \(selectedPeriod.accessibilityPeriodName)")
                    Button(action: nextPeriod) {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Next \(selectedPeriod.accessibilityPeriodName)")
                }
                .buttonStyle(PlainProgressButtonStyle())

                HStack(spacing: 12) {
                    ForEach(StatsPeriod.allCases) { period in
                        Button {
                            withAnimation(.snappy) {
                                selectedPeriod = period
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text(period.shortLabel)
                                    .font(BramFont.button(size: 13))
                                Circle()
                                    .fill(selectedPeriod == period ? BramColor.violet : .clear)
                                    .frame(width: 4, height: 4)
                            }
                            .foregroundStyle(selectedPeriod == period ? BramColor.violet : BramColor.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(period.accessibilityPeriodName.capitalized)
                        .accessibilityValue(selectedPeriod == period ? "Selected" : "")
                    }
                }
            }

            ProgressSummaryCard(stats: stats)
            MuscleSetCard(stats: stats)
            BodyweightProgressCard(stats: stats)
            AppleHealthProgressCard(stats: stats, presentation: healthPresentation)
        }
    }
}

private struct ProgressSummaryCard: View {
    let stats: StatsWeekSnapshot
    @State private var selectedMetric: DailyLoadMetric?

    private var maxEnergy: Int {
        max(stats.loadByDay.map(\.energyCalories).max() ?? 1, 1)
    }

    var body: some View {
        BramCard {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                        .font(BramFont.headline())
                        .foregroundStyle(BramColor.textPrimary)

                    HStack(spacing: 8) {
                        ForEach(stats.progressSignals.prefix(3)) { signal in
                            ProgressSignalPill(signal: signal)
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .trailing) {
                            Text(energyLabel(maxEnergy))
                            Spacer()
                            Text(energyLabel(maxEnergy / 2))
                            Spacer()
                            Text("0")
                        }
                        .font(BramFont.label(size: 9))
                        .foregroundStyle(BramColor.textTertiary)
                        .frame(width: 32, height: 132)

                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(stats.loadByDay) { day in
                                VStack(spacing: 8) {
                                    WorkoutLoadStackedBar(
                                        metric: day,
                                        maxEnergy: maxEnergy,
                                        isSelected: selectedMetric?.id == day.id
                                    )
                                    .onTapGesture {
                                        withAnimation(.snappy) {
                                            selectedMetric = selectedMetric?.id == day.id ? nil : day
                                        }
                                    }
                                    Text(day.weekday)
                                        .font(BramFont.label(size: 11))
                                        .foregroundStyle(BramColor.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 150, alignment: .bottom)
                    }
                }

                if let selectedMetric {
                    LoadMetricPopover(metric: selectedMetric)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                }
            }
        }
    }

    private func energyLabel(_ energy: Int) -> String {
        if energy >= 1000 { return "\(energy / 1000)k" }
        return "\(energy)"
    }
}

private struct ProgressSignalPill: View {
    let signal: ProgressSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(signal.value)
                .font(BramFont.headline(size: 16))
                .foregroundStyle(BramColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(signal.label)
                .font(BramFont.label(size: 10))
                .foregroundStyle(BramColor.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(signal.colorRole.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StatsInsightCard: View {
    let insight: StatsInsight

    var body: some View {
        BramCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(insight.colorRole.color.opacity(0.14))
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(insight.colorRole.color)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.kind.rawValue)
                        .font(BramFont.label(size: 12))
                        .foregroundStyle(insight.colorRole.color)
                    Text(insight.text)
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var iconName: String {
        switch insight.kind {
        case .progression:
            "arrow.up.right"
        case .effort:
            "flame.fill"
        case .balance:
            "scale.3d"
        case .consistency:
            "calendar.badge.checkmark"
        case .bodyweight:
            "scalemass"
        }
    }
}

private struct WorkoutLoadStackedBar: View {
    let metric: DailyLoadMetric
    let maxEnergy: Int
    let isSelected: Bool

    private var barHeight: CGFloat {
        metric.energyCalories == 0 ? 10 : max(16, CGFloat(metric.energyCalories) / CGFloat(maxEnergy) * 120)
    }

    private var totalSets: Int {
        max(metric.muscleBreakdown.reduce(0) { $0 + $1.sets }, 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            if metric.muscleBreakdown.isEmpty {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(BramColor.energy.opacity(metric.energyCalories == 0 ? 0.18 : 0.85))
            } else {
                ForEach(metric.muscleBreakdown.reversed()) { muscle in
                    Rectangle()
                        .fill(muscle.colorRole.color.opacity(0.9))
                        .frame(height: max(4, barHeight * CGFloat(muscle.sets) / CGFloat(totalSets)))
                }
            }
        }
        .frame(height: barHeight)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(isSelected ? BramColor.textPrimary.opacity(0.28) : .clear, lineWidth: 1.5)
        }
        .contentShape(Rectangle())
    }
}

private struct LoadMetricPopover: View {
    let metric: DailyLoadMetric

    private var totalSets: Int {
        metric.muscleBreakdown.reduce(0) { $0 + $1.sets }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(metric.weekday)
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.textPrimary)
            Text("\(metric.energyCalories) \(metric.energyUnitLabel)")
                .font(BramFont.label(size: 11))
                .foregroundStyle(BramColor.textSecondary)
                .accessibilityLabel(metric.energyAccessibilityLabel)
            if let duration = metric.durationMinutes {
                Text("\(duration) min")
                    .font(BramFont.label(size: 11))
                    .foregroundStyle(BramColor.textSecondary)
            }
            if let heartRate = metric.averageHeartRate {
                Text("HR \(heartRate)")
                    .font(BramFont.label(size: 11))
                    .foregroundStyle(BramColor.textSecondary)
            }
            if metric.volume > 0 {
                Text("\(metric.volume) lb volume")
                    .font(BramFont.label(size: 11))
                    .foregroundStyle(BramColor.textTertiary)
            }
            if totalSets > 0 {
                Text("\(totalSets) sets")
                    .font(BramFont.label(size: 11))
                    .foregroundStyle(BramColor.textSecondary)
            }
            ForEach(metric.muscleBreakdown.prefix(3)) { muscle in
                HStack(spacing: 6) {
                    Circle()
                        .fill(muscle.colorRole.color)
                        .frame(width: 6, height: 6)
                    Text("\(muscle.muscleGroup) \(muscle.sets)")
                        .font(BramFont.label(size: 10))
                        .foregroundStyle(BramColor.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BramColor.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BramColor.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}

private struct MuscleSetCard: View {
    let stats: StatsWeekSnapshot
    @State private var showsDetail = false
    @State private var showsPercentages = false

    private var visibleMetrics: [MuscleSetMetric] {
        if showsDetail { return stats.setVolumeByMuscle }
        return stats.macroSetVolumeByMuscle.isEmpty ? stats.setVolumeByMuscle : stats.macroSetVolumeByMuscle
    }

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Set Volume")
                        .font(BramFont.headline())
                        .foregroundStyle(BramColor.textPrimary)
                    Spacer()
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(.snappy) {
                                showsDetail.toggle()
                            }
                        } label: {
                            Text(showsDetail ? "detail" : "macro")
                                .foregroundStyle(BramColor.violet)
                        }
                        .buttonStyle(.plain)

                        Circle()
                            .fill(BramColor.textTertiary.opacity(0.45))
                            .frame(width: 3, height: 3)

                        Button {
                            withAnimation(.snappy) {
                                showsPercentages.toggle()
                            }
                        } label: {
                            Text(showsPercentages ? "%" : "sets")
                                .foregroundStyle(BramColor.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(BramFont.label(size: 12))
                }

                if visibleMetrics.isEmpty {
                    Text("Set volume will build as you log workouts.")
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textSecondary)
                } else {
                    MuscleSetPieBreakdown(metrics: visibleMetrics, showsPercentages: showsPercentages)
                        .transition(.opacity)
                }
            }
        }
    }
}

private struct MuscleSetPieBreakdown: View {
    let metrics: [MuscleSetMetric]
    let showsPercentages: Bool

    private var totalSets: Int {
        max(metrics.reduce(0) { $0 + $1.sets }, 1)
    }

    var body: some View {
        HStack(spacing: 18) {
            SetVolumePieChart(metrics: metrics)
                .frame(width: 118, height: 118)
                .contentShape(Rectangle())

            VStack(alignment: .leading, spacing: 9) {
                ForEach(metrics) { metric in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(metric.colorRole.color)
                            .frame(width: 8, height: 8)
                        Text(metric.muscleGroup)
                            .font(BramFont.label(size: 12))
                            .foregroundStyle(BramColor.textPrimary)
                        Spacer()
                        Text(valueText(for: metric))
                            .font(BramFont.label(size: 12))
                            .foregroundStyle(BramColor.textSecondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func valueText(for metric: MuscleSetMetric) -> String {
        guard showsPercentages else { return "\(metric.sets)" }
        let percent = Double(metric.sets) / Double(totalSets) * 100
        return "\(Int(percent.rounded()))%"
    }
}

private struct BodyweightProgressCard: View {
    let stats: StatsWeekSnapshot

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Bodyweight", systemImage: "scalemass")
                        .font(BramFont.headline())
                        .foregroundStyle(BramColor.textPrimary)
                    Spacer()
                    Text(statusText)
                        .font(BramFont.label(size: 12))
                        .foregroundStyle(statusColor)
                }

                if stats.bodyweightTrend.isEmpty {
                    Text("Log bodyweight in notes or connect Health to build this trend.")
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textSecondary)
                } else {
                    BodyweightLineChart(points: stats.bodyweightTrend, target: stats.targetWeight)
                        .frame(height: 110)

                    HStack {
                        if let latest = stats.bodyweightTrend.last {
                            Text("\(weightText(latest.value)) \(stats.preferredWeightUnit)")
                                .font(BramFont.headline(size: 18))
                                .foregroundStyle(BramColor.textPrimary)
                        }
                        Spacer()
                        if let target = stats.targetWeight {
                            Text("Target \(weightText(target))")
                                .font(BramFont.label(size: 12))
                                .foregroundStyle(BramColor.textSecondary)
                        }
                    }

                    if stats.hasAppleHealthBodyweight {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(BramColor.cool)
                                .frame(width: 7, height: 7)
                            Text("Apple Health")
                                .font(BramFont.label(size: 11))
                                .foregroundStyle(BramColor.textTertiary)
                        }
                        .accessibilityLabel("Bodyweight includes Apple Health data")
                    }
                }
            }
        }
    }

    private var statusText: String {
        guard let target = stats.targetWeight,
              let first = stats.bodyweightTrend.first?.value,
              let latest = stats.bodyweightTrend.last?.value
        else { return stats.targetWeight == nil ? "no target" : "holding steady" }

        let startGap = abs(first - target)
        let currentGap = abs(latest - target)
        if currentGap <= 1 { return "on target" }
        if abs(currentGap - startGap) < 0.2 { return "holding steady" }
        return currentGap < startGap ? "on track" : "moving away"
    }

    private var statusColor: Color {
        switch statusText {
        case "moving away":
            BramColor.energy
        case "holding steady", "no target":
            BramColor.textTertiary
        default:
            BramColor.recovery
        }
    }

    private func weightText(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

private struct BodyweightLineChart: View {
    let points: [BodyweightTrendPoint]
    let target: Double?

    var body: some View {
        GeometryReader { proxy in
            let chartPoints = mappedPoints(in: proxy.size)
            ZStack {
                if let targetY = targetY(in: proxy.size) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: targetY))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: targetY))
                    }
                    .stroke(BramColor.recovery.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                }

                if chartPoints.count >= 2 {
                    Path { path in
                        path.move(to: chartPoints[0])
                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(BramColor.violet, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                } else if let point = chartPoints.first {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: point.y))
                        path.addLine(to: point)
                    }
                    .stroke(BramColor.violet.opacity(0.22), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5]))
                }

                ForEach(Array(zip(points, chartPoints)), id: \.0.id) { point, location in
                    Circle()
                        .fill(point.source == .appleHealth ? BramColor.cool : BramColor.violet)
                        .frame(width: 8, height: 8)
                        .position(location)
                }
            }
        }
    }

    private var values: [Double] {
        points.map(\.value) + [target].compactMap { $0 }
    }

    private func mappedPoints(in size: CGSize) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        let xPadding: CGFloat = 8
        let yPadding: CGFloat = 8
        let usableWidth = max(size.width - xPadding * 2, 1)
        let usableHeight = max(size.height - yPadding * 2, 1)
        let minValue = (values.min() ?? 0) - 1
        let maxValue = (values.max() ?? 1) + 1
        let span = max(maxValue - minValue, 1)
        let xStep = points.count > 1 ? usableWidth / CGFloat(points.count - 1) : 0
        return points.enumerated().map { index, point in
            CGPoint(
                x: points.count > 1 ? xPadding + CGFloat(index) * xStep : size.width - xPadding,
                y: yPadding + usableHeight - CGFloat((point.value - minValue) / span) * usableHeight
            )
        }
    }

    private func targetY(in size: CGSize) -> CGFloat? {
        guard let target else { return nil }
        let yPadding: CGFloat = 8
        let usableHeight = max(size.height - yPadding * 2, 1)
        let minValue = (values.min() ?? 0) - 1
        let maxValue = (values.max() ?? 1) + 1
        let span = max(maxValue - minValue, 1)
        return yPadding + usableHeight - CGFloat((target - minValue) / span) * usableHeight
    }
}

private struct SetVolumePieChart: View {
    let metrics: [MuscleSetMetric]

    private var total: Double {
        Double(max(metrics.reduce(0) { $0 + $1.sets }, 1))
    }

    var body: some View {
        ZStack {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                PieSlice(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index)
                )
                .fill(metric.colorRole.color)
            }
            Circle()
                .fill(BramColor.elevated)
                .frame(width: 54, height: 54)
        }
    }

    private func startAngle(for index: Int) -> Angle {
        .degrees(-90 + metrics.prefix(index).reduce(0) { $0 + Double($1.sets) } / total * 360)
    }

    private func endAngle(for index: Int) -> Angle {
        .degrees(-90 + metrics.prefix(index + 1).reduce(0) { $0 + Double($1.sets) } / total * 360)
    }
}

private struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(
            center: center,
            radius: min(rect.width, rect.height) / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct PlainProgressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? BramColor.violet : BramColor.textPrimary)
            .frame(width: 22, height: 28)
    }
}

private struct StreakOverview: View {
    let stats: StatsWeekSnapshot
    let referralProgram: ReferralProgramStatus?
    let track: (AnalyticsEvent) -> Void
    @State private var trackedViewedKeys = Set<String>()
    @State private var trackedEarnedKeys = Set<String>()
    @State private var selectedAward: StreakAward?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BramCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 14) {
                        RiveMascotPlaceholder(moment: .streak, showsLabel: false)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stats.streakTitle)
                                .font(BramFont.headline())
                                .foregroundStyle(BramColor.textPrimary)
                            Text(stats.streakSubtitle)
                                .font(BramFont.callout())
                                .foregroundStyle(BramColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 10) {
                        StreakMetric(value: "\(stats.currentStreak)", label: "goal run", colorRole: .energy)
                        StreakMetric(value: "\(stats.highestStreak)", label: "best", colorRole: .violet)
                        StreakMetric(value: "\(stats.workoutDaysInPeriod)/\(stats.weeklyTarget)", label: "target", colorRole: stats.workoutDaysInPeriod >= stats.weeklyTarget ? .recovery : .violet)
                    }
                }
            }

            BramCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(BramColor.violet)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weekly target")
                                .font(BramFont.headline())
                                .foregroundStyle(BramColor.textPrimary)
                            Text("\(stats.workoutDaysInPeriod) of \(stats.weeklyTarget) workouts logged")
                                .font(BramFont.callout())
                                .foregroundStyle(BramColor.textSecondary)
                        }
                    }

                    ProgressView(value: min(Double(stats.workoutDaysInPeriod), Double(stats.weeklyTarget)), total: Double(max(stats.weeklyTarget, 1)))
                        .tint(BramColor.violet)
                }
            }

            if stats.launchChallenge.isVisible {
                LaunchChallengeCard(progress: stats.launchChallenge)
                    .onAppear {
                        trackLaunchChallengeIfNeeded(stats.launchChallenge)
                    }
                    .onChange(of: stats.launchChallenge) { _, progress in
                        trackLaunchChallengeIfNeeded(progress)
                    }
            }

            BramCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Awards")
                        .font(BramFont.headline())
                        .foregroundStyle(BramColor.textPrimary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(visibleAwards) { award in
                            Button {
                                selectedAward = award
                                track(
                                    AnalyticsEvent(
                                        name: "badge_opened",
                                        properties: [
                                            "badge_key": award.key,
                                            "status": award.isUnlocked ? "unlocked" : "locked"
                                        ]
                                    )
                                )
                            } label: {
                                StreakAwardTile(award: award)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            BramCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: stats.streakRepairCount > 0 ? "bandage.fill" : "checkmark.seal")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(stats.streakRepairCount > 0 ? BramColor.energy : BramColor.recovery)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repairs")
                            .font(BramFont.headline())
                            .foregroundStyle(BramColor.textPrimary)
                        Text(repairText)
                            .font(BramFont.callout())
                            .foregroundStyle(BramColor.textSecondary)
                    }
                }
            }
        }
        .sheet(item: $selectedAward) { award in
            BadgeDetailSheet(
                award: award,
                launchChallenge: award.title == stats.launchChallenge.badgeTitle ? stats.launchChallenge : nil,
                referralProgram: referralProgram,
                track: track
            )
            .presentationDetents([.medium])
            .presentationCornerRadius(28)
        }
    }

    private var visibleAwards: [StreakAward] {
        var awards = stats.streakAwards
        if stats.launchChallenge.isVisible {
            awards.append(
                StreakAward(
                    title: stats.launchChallenge.badgeTitle,
                    subtitle: "4 launch workouts",
                    systemImage: "rosette",
                    assetName: "BramBadgeFoundingLifters",
                    colorRole: .energy,
                    isUnlocked: stats.launchChallenge.isEarned
                )
            )
        }
        awards.append(
            StreakAward(
                title: "Share with a friend",
                subtitle: referralSubtitle,
                systemImage: "person.2.fill",
                assetName: "BramBadgeShareFriend",
                colorRole: .violet,
                isUnlocked: (referralProgram?.successfulRedemptions ?? 0) > 0
            )
        )
        return awards
    }

    private var referralSubtitle: String {
        let count = referralProgram?.successfulRedemptions ?? 0
        if count == 0 {
            return "Give 1 month free"
        }
        if count == 1 {
            return "1 friend joined"
        }
        return "\(count) friends joined"
    }

    private func trackLaunchChallengeIfNeeded(_ progress: LaunchChallengeProgress) {
        guard progress.isVisible else { return }
        let viewedKey = "\(progress.eventKey)-\(progress.state.rawValue)-\(progress.clampedProgress)"
        if !trackedViewedKeys.contains(viewedKey) {
            trackedViewedKeys.insert(viewedKey)
            track(
                AnalyticsEvent(
                    name: "launch_challenge_viewed",
                    properties: [
                        "event_key": progress.eventKey,
                        "state": progress.state.rawValue,
                        "progress_bucket": progress.progressText
                    ]
                )
            )
        }

        guard progress.isEarned else { return }
        let earnedKey = "\(progress.eventKey)-earned"
        if !trackedEarnedKeys.contains(earnedKey) {
            trackedEarnedKeys.insert(earnedKey)
            track(
                AnalyticsEvent(
                    name: "launch_challenge_badge_earned",
                    properties: [
                        "event_key": progress.eventKey,
                        "state": progress.state.rawValue,
                        "progress_bucket": progress.progressText
                    ]
                )
            )
        }
    }

    private var repairText: String {
        if stats.streakRepairCount == 0 {
            return "No repair needed for this range."
        }
        if stats.streakRepairCount == 1 {
            return "1 repair available for a single missed day between workouts."
        }
        return "\(stats.streakRepairCount) repairs available for single missed days between workouts."
    }
}

private struct LaunchChallengeCard: View {
    let progress: LaunchChallengeProgress

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BramColor.energy.opacity(progress.isEarned ? 0.2 : 0.14))
                        Image(systemName: progress.isEarned ? "rosette" : "flag.checkered")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(BramColor.energy)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(progress.title)
                                .font(BramFont.headline())
                                .foregroundStyle(BramColor.textPrimary)
                            Spacer()
                            Text(progress.stateLabel)
                                .font(BramFont.label(size: 11))
                                .foregroundStyle(BramColor.energy)
                                .lineLimit(1)
                        }

                        Text(progress.subtitle)
                            .font(BramFont.callout())
                            .foregroundStyle(BramColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(progress.progressText)
                            .font(BramFont.label(size: 12))
                            .foregroundStyle(BramColor.textPrimary)
                            .monospacedDigit()
                        Spacer()
                        Text("Challenge")
                            .font(BramFont.label(size: 11))
                            .foregroundStyle(BramColor.textTertiary)
                    }
                    ProgressView(value: Double(progress.clampedProgress), total: Double(progress.goalCount))
                        .tint(BramColor.energy)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progress.title). \(progress.stateLabel). \(progress.progressText). \(progress.subtitle)")
    }
}

private struct StreakMetric: View {
    let value: String
    let label: String
    let colorRole: MetricColorRole

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(BramFont.headline(size: 18))
                .foregroundStyle(BramColor.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(BramFont.label(size: 10))
                .foregroundStyle(BramColor.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(colorRole.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StreakAwardTile: View {
    let award: StreakAward

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            BadgeArtwork(award: award, size: 40, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(award.title)
                    .font(BramFont.label(size: 11))
                    .foregroundStyle(award.isUnlocked ? BramColor.textPrimary : BramColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(award.subtitle)
                    .font(BramFont.label(size: 9))
                    .foregroundStyle(BramColor.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .background(BramColor.elevated.opacity(award.isUnlocked ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BadgeDetailSheet: View {
    let award: StreakAward
    let launchChallenge: LaunchChallengeProgress?
    let referralProgram: ReferralProgramStatus?
    let track: (AnalyticsEvent) -> Void

    private var isReferralBadge: Bool {
        award.title == "Share with a friend"
    }

    private var description: String {
        if isReferralBadge {
            if award.isUnlocked {
                return "You shared Bram and a friend joined with your code. Each successful referral gives your friend one month free and records your share badge."
            }
            return "Share Bram with a friend. They get one month free when they redeem your code, and you unlock this badge after the first successful signup."
        }

        if let launchChallenge {
            return launchChallenge.isEarned
                ? "You logged four workouts during Founding Lifters Week and earned the limited launch badge."
                : "Log four qualifying workouts by May 30 to earn this limited launch badge. Lifts and cardio count; bodyweight-only notes do not."
        }

        return award.isUnlocked
            ? "You earned this badge through consistent workout logging in Bram."
            : "Keep logging workouts to unlock this badge."
    }

    private var statusText: String {
        if let launchChallenge {
            return "\(launchChallenge.progressText) • \(award.isUnlocked ? "Unlocked" : "Locked")"
        }
        if isReferralBadge, let referralProgram {
            let count = referralProgram.successfulRedemptions
            return count == 1 ? "1 successful share" : "\(count) successful shares"
        }
        return award.isUnlocked ? "Unlocked" : "Locked"
    }

    private var shareText: String? {
        if isReferralBadge, let code = referralProgram?.code {
            let shareURL = referralProgram?.shareURL ?? "https://trybram.app"
            return "Try Bram free for a month. Use my invite \(code): \(shareURL)"
        }
        guard award.isUnlocked else { return nil }
        return "I earned \(award.title) in Bram: Workout Notes. https://trybram.app"
    }

    var body: some View {
        BramPanelChrome(title: award.title) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 12) {
                    BadgeArtwork(award: award, size: 154, cornerRadius: 34)
                        .shadow(color: award.colorRole.color.opacity(award.isUnlocked ? 0.22 : 0), radius: 18, y: 10)

                    VStack(spacing: 5) {
                        Text(statusText)
                            .font(BramFont.label(size: 12))
                            .foregroundStyle(award.isUnlocked ? award.colorRole.color : BramColor.textTertiary)
                        Text(award.subtitle)
                            .font(BramFont.headline())
                            .foregroundStyle(BramColor.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .padding(.bottom, 2)

                Text(description)
                    .font(BramFont.callout())
                    .foregroundStyle(BramColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isReferralBadge, let code = referralProgram?.code {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your code")
                            .font(BramFont.label(size: 11))
                            .foregroundStyle(BramColor.textTertiary)
                        Text(code)
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .foregroundStyle(BramColor.textPrimary)
                            .textSelection(.enabled)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BramColor.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let shareText {
                    ShareLink(item: shareText) {
                        Text(isReferralBadge ? "Share invite" : "Share badge")
                            .font(BramFont.button())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(BramColor.violet, in: Capsule())
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            track(
                                AnalyticsEvent(
                                    name: "badge_shared",
                                    properties: [
                                        "badge_key": award.key,
                                        "status": award.isUnlocked ? "unlocked" : "locked"
                                    ]
                                )
                            )
                        }
                    )
                }
            }
        }
    }
}

private struct BadgeArtwork: View {
    let award: StreakAward
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            artworkContent
                .saturation(award.isUnlocked ? 1 : 0)
                .brightness(award.isUnlocked ? 0 : -0.32)
                .opacity(award.isUnlocked ? 1 : 0.42)

            if !award.isUnlocked {
                Color.black.opacity(0.58)

                Image(systemName: "lock.fill")
                    .font(.system(size: max(13, size * 0.22), weight: .semibold))
                    .foregroundStyle(BramColor.textSecondary)
                    .frame(width: max(28, size * 0.34), height: max(28, size * 0.34))
                    .background(.black.opacity(0.5), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(BramColor.hairline.opacity(0.65), lineWidth: 1)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(BramColor.hairline.opacity(award.isUnlocked ? 1 : 0.7), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artworkContent: some View {
        if let assetName = award.assetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                (award.isUnlocked ? award.colorRole.color : BramColor.textTertiary)
                    .opacity(0.12)
                Image(systemName: award.systemImage)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(award.isUnlocked ? award.colorRole.color : BramColor.textTertiary)
            }
        }
    }
}

private struct AppleHealthProgressCard: View {
    let stats: StatsWeekSnapshot
    let presentation: AppleHealthProgressPresentation

    private var hasMiniCharts: Bool {
        stats.loadByDay.contains { $0.hasHealthDuration || $0.hasHealthHeartRate }
    }

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: presentation.systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(presentation.isConnectedLike ? BramColor.recovery : BramColor.textTertiary)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(presentation.title)
                            .font(BramFont.headline())
                            .foregroundStyle(BramColor.textPrimary)
                        Text(presentation.subtitle)
                            .font(BramFont.callout())
                            .foregroundStyle(BramColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if presentation.showsCharts, hasMiniCharts {
                    HStack(spacing: 10) {
                        if stats.loadByDay.contains(where: { $0.hasHealthDuration }) {
                            HealthMiniChart(
                                title: "Duration",
                                values: stats.loadByDay.map { $0.durationMinutes ?? 0 },
                                unit: "min",
                                color: BramColor.cool,
                                style: .bars
                            )
                        }

                        if stats.loadByDay.contains(where: { $0.hasHealthHeartRate }) {
                            HealthMiniChart(
                                title: "Heart rate",
                                values: stats.loadByDay.map { $0.averageHeartRate ?? 0 },
                                unit: "bpm",
                                color: BramColor.recovery,
                                style: .line
                            )
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.title). \(presentation.subtitle)")
    }
}

private struct HealthMiniChart: View {
    enum Style {
        case bars
        case line
    }

    let title: String
    let values: [Int]
    let unit: String
    let color: Color
    let style: Style

    private var nonZeroValues: [Int] {
        values.filter { $0 > 0 }
    }

    private var latestText: String {
        guard let latest = nonZeroValues.last else { return "--" }
        return "\(latest) \(unit)"
    }

    private var maxValue: Int {
        max(nonZeroValues.max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(BramFont.label(size: 11))
                    .foregroundStyle(BramColor.textTertiary)
                Spacer()
                Text(latestText)
                    .font(BramFont.label(size: 12))
                    .foregroundStyle(BramColor.textPrimary)
                    .monospacedDigit()
            }

            chart
                .frame(height: 58)
        }
        .padding(12)
        .background(BramColor.cardSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), latest \(latestText), from Apple Health")
    }

    @ViewBuilder
    private var chart: some View {
        switch style {
        case .bars:
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(value > 0 ? color.opacity(0.85) : BramColor.hairline.opacity(0.45))
                        .frame(height: value > 0 ? max(7, CGFloat(value) / CGFloat(maxValue) * 54) : 5)
                        .frame(maxWidth: .infinity)
                }
            }
        case .line:
            GeometryReader { proxy in
                let points = mappedPoints(in: proxy.size)
                ZStack {
                    if points.count >= 2 {
                        Path { path in
                            path.move(to: points[0])
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }

                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .position(point)
                    }
                }
            }
        }
    }

    private func mappedPoints(in size: CGSize) -> [CGPoint] {
        let indexed = values.enumerated().filter { $0.element > 0 }
        guard !indexed.isEmpty else { return [] }
        let xPadding: CGFloat = 4
        let yPadding: CGFloat = 5
        let usableWidth = max(size.width - xPadding * 2, 1)
        let usableHeight = max(size.height - yPadding * 2, 1)
        let denominator = max(values.count - 1, 1)
        return indexed.map { index, value in
            CGPoint(
                x: xPadding + CGFloat(index) / CGFloat(denominator) * usableWidth,
                y: yPadding + usableHeight - CGFloat(value) / CGFloat(maxValue) * usableHeight
            )
        }
    }
}

#Preview {
    StatsPanelView(stats: BramPreviewData.stats, healthAuthorizationState: .connected)
        .preferredColorScheme(.dark)
}
