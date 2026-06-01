import SwiftUI

struct DailyWorkoutStatsPanelView: View {
    let note: DailyWorkoutNote

    var body: some View {
        BramPanelChrome(title: note.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), showsCloseButton: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Today's workout")
                    .font(BramFont.headline())
                    .foregroundStyle(BramColor.textPrimary)

                LazyVGrid(columns: columns, spacing: 12) {
                    DayMetricCard(title: "Sets", value: "\(note.metrics.totalSets)", icon: "number", color: BramColor.violet)
                    DayMetricCard(title: energyTitle, value: energyText, icon: "flame.fill", color: BramColor.energy)
                    DayMetricCard(title: "PRs", value: "\(note.metrics.prCount)", icon: "trophy.fill", color: BramColor.warning)
                    DayMetricCard(title: fourthMetricTitle, value: fourthMetricValue, icon: fourthMetricIcon, color: BramColor.recovery)
                }
            }
        }
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private var energyTitle: String {
        note.metrics.energyIsEstimated ? "Est. Energy" : "Energy"
    }

    private var energyText: String {
        guard let energy = note.metrics.activeEnergyCalories else { return "--" }
        return "\(energy)"
    }

    private var fourthMetricTitle: String {
        if note.metrics.averageHeartRate != nil { return "Heart Rate" }
        if note.metrics.cardioMinutes > 0 { return "Cardio" }
        if note.metrics.workoutDurationMinutes != nil { return "Duration" }
        return "Duration"
    }

    private var fourthMetricValue: String {
        if let heartRate = note.metrics.averageHeartRate { return "\(heartRate)" }
        if note.metrics.cardioMinutes > 0 { return "\(note.metrics.cardioMinutes)m" }
        if let duration = note.metrics.workoutDurationMinutes { return "\(duration)m" }
        return "--"
    }

    private var fourthMetricIcon: String {
        if note.metrics.averageHeartRate != nil { return "heart.fill" }
        if note.metrics.cardioMinutes > 0 { return "figure.run" }
        return "clock"
    }
}

private struct DayMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        BramCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(BramFont.headline(size: 24))
                    .foregroundStyle(BramColor.textPrimary)
                Text(title)
                    .font(BramFont.label(size: 12))
                    .foregroundStyle(BramColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    DailyWorkoutStatsPanelView(note: BramPreviewData.populatedNote)
        .preferredColorScheme(.dark)
}
