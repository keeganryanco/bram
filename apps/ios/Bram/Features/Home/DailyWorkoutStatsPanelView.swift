import SwiftUI

struct DailyWorkoutStatsPanelView: View {
    let note: DailyWorkoutNote

    var body: some View {
        BramPanelChrome(title: note.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Today's workout")
                    .font(BramFont.headline())
                    .foregroundStyle(BramColor.textPrimary)

                LazyVGrid(columns: columns, spacing: 12) {
                    DayMetricCard(title: "Sets", value: "\(note.metrics.totalSets)", icon: "number", color: BramColor.violet)
                    DayMetricCard(title: "Volume", value: volumeText, icon: "scalemass.fill", color: BramColor.energy)
                    DayMetricCard(title: "PRs", value: "\(note.metrics.prCount)", icon: "trophy.fill", color: BramColor.warning)
                    DayMetricCard(title: "State", value: note.metrics.parseState.rawValue, icon: "sparkles", color: BramColor.recovery)
                }
            }
        }
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private var volumeText: String {
        note.metrics.estimatedVolume >= 1000 ? "\(note.metrics.estimatedVolume / 1000)k" : "\(note.metrics.estimatedVolume)"
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
