import SwiftUI

struct CardioHistorySheetView: View {
    let history: CardioHistorySummary

    var body: some View {
        BramPanelChrome(title: history.activityType) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    CardioMetricCard(
                        title: "Avg Time",
                        value: history.averageDurationMinutes.map { "\($0)m" } ?? "--"
                    )
                    CardioMetricCard(
                        title: "Best Distance",
                        value: history.bestDistanceText ?? "--"
                    )
                    CardioMetricCard(
                        title: "Avg Pace",
                        value: history.averagePaceText ?? "--"
                    )
                }

                CardioTrendCard(sessions: history.recentSessions)
                CardioRecentSessionsCard(sessions: history.recentSessions)

                BramCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Next time", systemImage: "arrow.up.right")
                            .font(BramFont.label())
                            .foregroundStyle(BramColor.violet)
                        Text(history.recommendation)
                            .font(BramFont.callout())
                            .foregroundStyle(BramColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct CardioMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        BramCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(value)
                    .font(BramFont.headline(size: 22))
                    .monospacedDigit()
                    .foregroundStyle(BramColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(BramFont.label(size: 11))
                    .foregroundStyle(BramColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
    }
}

private struct CardioTrendCard: View {
    let sessions: [CardioHistorySession]
    @State private var selectedSession: CardioHistorySession?

    private var sortedSessions: [CardioHistorySession] {
        sessions
            .filter { metricValue(for: $0) > 0 }
            .sorted { $0.date < $1.date }
    }

    private var usesDistance: Bool {
        sessions.contains { ($0.distance ?? 0) > 0 }
    }

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(usesDistance ? "Distance Trend" : "Time Trend", systemImage: "figure.run")
                        .font(BramFont.label())
                        .foregroundStyle(BramColor.cool)
                    Spacer()
                    Text(usesDistance ? "distance" : "minutes")
                        .font(BramFont.label(size: 12))
                        .foregroundStyle(BramColor.textTertiary)
                }

                if sortedSessions.count >= 2 {
                    CardioTrendGraph(
                        sessions: sortedSessions,
                        usesDistance: usesDistance,
                        selectedSession: $selectedSession
                    )
                    .frame(height: 96)
                    .animation(.snappy, value: selectedSession?.id)

                    if let selectedSession {
                        CardioTrendSelection(session: selectedSession)
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

    private func metricValue(for session: CardioHistorySession) -> Double {
        if usesDistance, let distance = session.distance {
            return distance
        }
        return Double(session.durationMinutes ?? 0)
    }
}

private struct CardioTrendGraph: View {
    let sessions: [CardioHistorySession]
    let usesDistance: Bool
    @Binding var selectedSession: CardioHistorySession?

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
                .stroke(BramColor.cool, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(zip(sessions, points)), id: \.0.id) { session, point in
                    Button {
                        selectedSession = session
                    } label: {
                        ZStack {
                            Circle()
                                .fill(BramColor.cool.opacity(selectedSession?.id == session.id ? 0.18 : 0))
                                .frame(width: 32, height: 32)
                            Circle()
                                .fill(BramColor.cool)
                                .frame(width: selectedSession?.id == session.id ? 11 : 8, height: selectedSession?.id == session.id ? 11 : 8)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(point)
                    .accessibilityLabel(accessibilityLabel(for: session))
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
        let values = sessions.map(metricValue)
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

    private func metricValue(for session: CardioHistorySession) -> Double {
        if usesDistance, let distance = session.distance {
            return distance
        }
        return Double(session.durationMinutes ?? 0)
    }

    private func accessibilityLabel(for session: CardioHistorySession) -> String {
        let date = session.date.formatted(.dateTime.month(.wide).day())
        let metric = usesDistance ? session.distanceText : session.durationText
        return "\(date), \(metric), \(session.caloriesText) estimated calories"
    }
}

private struct CardioTrendSelection: View {
    let session: CardioHistorySession

    var body: some View {
        HStack(spacing: 10) {
            Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.textSecondary)
            Spacer()
            Text(session.distanceText)
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.cool)
            Text(session.paceText)
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.textPrimary)
            Text(session.durationText)
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.textSecondary)
            Text("\(session.caloriesText) cal")
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(BramColor.cool.opacity(0.08), in: Capsule())
    }
}

private struct CardioRecentSessionsCard: View {
    let sessions: [CardioHistorySession]

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent")
                    .font(BramFont.headline())
                    .foregroundStyle(BramColor.textPrimary)

                if sessions.isEmpty {
                    Text("Saved sessions will appear here after you log this cardio.")
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textSecondary)
                } else {
                    ForEach(sessions) { session in
                        HStack(spacing: 12) {
                            Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(BramFont.label(size: 13))
                                .foregroundStyle(BramColor.textSecondary)
                                .frame(width: 48, alignment: .leading)
                            Text(session.durationText)
                                .font(BramFont.label(size: 14))
                                .monospacedDigit()
                                .foregroundStyle(BramColor.textPrimary)
                            Spacer()
                            Text(session.distanceText)
                                .font(BramFont.label(size: 14))
                                .monospacedDigit()
                                .foregroundStyle(BramColor.textPrimary)
                            Text(session.paceText)
                                .font(BramFont.label(size: 13))
                                .monospacedDigit()
                                .foregroundStyle(BramColor.textSecondary)
                        }
                        .frame(minHeight: 24)
                    }
                }
            }
        }
    }
}

#Preview {
    CardioHistorySheetView(
        history: CardioHistorySummary(
            activityType: "Running",
            recentSessions: [
                CardioHistorySession(date: .now.addingTimeInterval(-14 * 86_400), activityType: "Running", durationMinutes: 12, distance: 1, distanceUnit: "mi", estimatedCalories: 120),
                CardioHistorySession(date: .now.addingTimeInterval(-7 * 86_400), activityType: "Running", durationMinutes: 22, distance: 2, distanceUnit: "mi", estimatedCalories: 220),
                CardioHistorySession(date: .now, activityType: "Running", durationMinutes: 30, distance: 3, distanceUnit: "mi", estimatedCalories: 310)
            ],
            averageDurationMinutes: 21,
            bestDistanceText: "3 mi",
            estimatedCaloriesText: "217",
            recommendation: "Next time, repeat 3 mi and make the effort feel a little smoother."
        )
    )
    .preferredColorScheme(.dark)
}
