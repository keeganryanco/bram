import SwiftUI

struct ExerciseHistorySheetView: View {
    let exercise: ExerciseAnchor

    var body: some View {
        BramPanelChrome(title: exercise.normalizedName) {
            if exercise.isSupersetGroup {
                SupersetHistoryContent(exercise: exercise)
            } else {
                ExerciseHistoryContent(exercise: exercise)
            }
        }
    }
}

private struct ExerciseHistoryContent: View {
    let exercise: ExerciseAnchor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ExerciseMetricCard(title: primaryMetricTitle, value: primaryMetricText)
                ExerciseMetricCard(title: "Best Set", value: exercise.history.bestSetText ?? "--")
                ExerciseMetricCard(title: "Effort", value: exercise.history.recentEffortText ?? "--")
            }

            ExerciseStrengthTrendCard(sessions: exercise.history.recentSessions, title: trendTitle)

            RecentSessionsCard(sessions: exercise.history.recentSessions)

            RecommendationCard(history: exercise.history)

            BramCard {
                HStack {
                    Label("Aliases", systemImage: "link")
                        .font(BramFont.label())
                        .foregroundStyle(BramColor.textSecondary)
                    Spacer()
                    Text(exercise.displayName == exercise.normalizedName ? "None yet" : exercise.displayName)
                        .font(BramFont.label())
                        .foregroundStyle(BramColor.textPrimary)
                }
            }
        }
    }

    private var isBodyweightOrNoLoad: Bool {
        exercise.history.bestSetText?.hasPrefix("BW") == true || (exercise.history.estimatedOneRepMax ?? 0) == 0
    }

    private var primaryMetricTitle: String {
        isBodyweightOrNoLoad ? "Best Reps" : "Est. 1RM"
    }

    private var primaryMetricText: String {
        if isBodyweightOrNoLoad,
           let bestSet = exercise.history.bestSetText,
           let reps = bestSet.split(separator: "x").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return reps
        }
        guard let value = exercise.history.estimatedOneRepMax, value > 0 else { return "--" }
        return "\(Int(value.rounded()))"
    }

    private var trendTitle: String {
        isBodyweightOrNoLoad ? "Rep Trend" : "Strength Trend"
    }
}

private struct SupersetHistoryContent: View {
    let exercise: ExerciseAnchor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BramCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Superset", systemImage: "rectangle.stack")
                        .font(BramFont.label())
                        .foregroundStyle(BramColor.violet)
                    Text("Review each exercise separately, then progress one side of the pairing at a time.")
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textPrimary)
                }
            }

            ForEach(exercise.groupMembers) { member in
                SupersetMemberCard(member: member)
            }
        }
    }
}

private struct SupersetMemberCard: View {
    let member: SupersetExerciseMember

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(member.normalizedName)
                    .font(BramFont.headline())
                    .foregroundStyle(BramColor.textPrimary)

                if let history = member.history {
                    HStack {
                        Text(history.bestSetText ?? "History pending")
                            .font(BramFont.label())
                            .foregroundStyle(BramColor.textPrimary)
                        Spacer()
                        if let latest = history.recentSessions.first {
                            Text(latest.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(BramFont.label(size: 12))
                                .foregroundStyle(BramColor.textSecondary)
                        }
                    }
                    Text(history.primarySuggestion?.text ?? history.recommendation)
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Saved sessions will appear here after you log this superset.")
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textSecondary)
                }
            }
        }
    }
}

private struct RecentSessionsCard: View {
    let sessions: [ExerciseHistorySession]

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent")
                    .font(BramFont.headline())
                    .foregroundStyle(BramColor.textPrimary)

                if sessions.isEmpty {
                    Text("Saved sessions will appear here after you log this exercise.")
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textSecondary)
                } else {
                    ForEach(sessions) { session in
                        HStack {
                            Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(BramFont.label(size: 13))
                                .foregroundStyle(BramColor.textSecondary)
                            Spacer()
                            if let effortText = session.effortText {
                                Text(effortText)
                                    .font(BramFont.label(size: 12))
                                    .foregroundStyle(BramColor.energy)
                                    .lineLimit(1)
                            }
                            Text(session.bestSetText)
                                .font(BramFont.label(size: 15))
                                .monospacedDigit()
                                .foregroundStyle(BramColor.textPrimary)
                        }
                        .frame(minHeight: 24)
                    }
                }
            }
        }
    }
}

private struct RecommendationCard: View {
    let history: ExerciseHistorySummary

    private var suggestion: ExerciseSuggestion? {
        history.primarySuggestion
    }

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Coach", systemImage: "arrow.up.right")
                        .font(BramFont.label())
                        .foregroundStyle(BramColor.violet)
                    Spacer()
                    if let latest = history.recentSessions.first {
                        Text("Last \(latest.bestSetText)")
                            .font(BramFont.label(size: 12))
                            .foregroundStyle(BramColor.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(BramColor.violet.opacity(0.08), in: Capsule())
                    }
                    if let target = suggestion?.target {
                        Text(target)
                            .font(BramFont.label(size: 12))
                            .foregroundStyle(BramColor.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(BramColor.violet.opacity(0.12), in: Capsule())
                        }
                }
                Text(suggestion?.text ?? history.recommendation)
                    .font(BramFont.callout())
                    .foregroundStyle(BramColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ExerciseStrengthTrendCard: View {
    let sessions: [ExerciseHistorySession]
    var title = "Strength Trend"
    @State private var selectedSession: ExerciseHistorySession?

    private var sortedSessions: [ExerciseHistorySession] {
        sessions
            .filter { $0.estimatedOneRepMax > 0 }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(title, systemImage: "chart.xyaxis.line")
                        .font(BramFont.label())
                        .foregroundStyle(BramColor.violet)
                    Spacer()
                    Text("Est. 1RM")
                        .font(BramFont.label(size: 12))
                        .foregroundStyle(BramColor.textTertiary)
                }

                if sortedSessions.count >= 2 {
                    ExerciseTrendGraph(sessions: sortedSessions, selectedSession: $selectedSession)
                        .frame(height: 96)
                        .animation(.snappy, value: selectedSession?.id)
                    if let selectedSession {
                        ExerciseTrendSelection(session: selectedSession)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } else {
                    Text("More logged sessions will build this trend.")
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                }
            }
        }
    }
}

private struct ExerciseTrendGraph: View {
    let sessions: [ExerciseHistorySession]
    @Binding var selectedSession: ExerciseHistorySession?

    var body: some View {
        GeometryReader { proxy in
            let points = graphPoints(in: proxy.size)

            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(BramColor.violet, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(zip(sessions, points)), id: \.0.id) { session, point in
                    Button {
                        selectedSession = session
                    } label: {
                        ZStack {
                            Circle()
                                .fill(BramColor.violet.opacity(selectedSession?.id == session.id ? 0.18 : 0))
                                .frame(width: 32, height: 32)
                            Circle()
                                .fill(BramColor.violet)
                                .frame(width: selectedSession?.id == session.id ? 11 : 8, height: selectedSession?.id == session.id ? 11 : 8)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(point)
                    .accessibilityLabel("\(session.date.formatted(.dateTime.month(.wide).day())), \(Int(session.estimatedOneRepMax.rounded())) estimated one rep max, \(session.bestSetText)")
                }

                VStack {
                    Spacer()
                    HStack {
                        ForEach(sessions) { session in
                            Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(BramFont.label(size: 10))
                                .foregroundStyle(BramColor.textTertiary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func graphPoints(in size: CGSize) -> [CGPoint] {
        let values = sessions.map(\.estimatedOneRepMax)
        guard let minValue = values.min(), let maxValue = values.max() else { return [] }
        let range = max(maxValue - minValue, 1)
        let graphHeight = max(size.height - 24, 1)
        let graphWidth = max(size.width - 16, 1)

        return values.enumerated().map { index, value in
            let xStep = sessions.count > 1 ? graphWidth / CGFloat(sessions.count - 1) : 0
            let progress = (value - minValue) / range
            let x = 8 + CGFloat(index) * xStep
            let y = 4 + graphHeight * CGFloat(1 - progress)
            return CGPoint(x: x, y: y)
        }
    }
}

private struct ExerciseTrendSelection: View {
    let session: ExerciseHistorySession

    var body: some View {
        HStack(spacing: 10) {
            Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.textSecondary)
            Spacer()
            Text("\(Int(session.estimatedOneRepMax.rounded())) est.")
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.violet)
            Text(session.bestSetText)
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(BramColor.violet.opacity(0.08), in: Capsule())
    }
}

private struct ExerciseMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        BramCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(value)
                    .font(BramFont.headline(size: 24))
                    .foregroundStyle(BramColor.textPrimary)
                Text(title)
                    .font(BramFont.label(size: 12))
                    .foregroundStyle(BramColor.textSecondary)
            }
        }
    }
}

#Preview {
    ExerciseHistorySheetView(exercise: BramPreviewData.populatedNote.interpretedLines[0].exerciseAnchor!)
        .preferredColorScheme(.dark)
}
