import SwiftUI

struct StatsPanelView: View {
    let stats: StatsWeekSnapshot
    @State private var selectedMode: StatsMode

    init(stats: StatsWeekSnapshot, initialMode: StatsMode = .stats) {
        self.stats = stats
        _selectedMode = State(initialValue: initialMode)
    }

    var body: some View {
        BramPanelChrome(title: "Progress") {
            Picker("Mode", selection: $selectedMode) {
                Text("Stats").tag(StatsMode.stats)
                Text("Streaks").tag(StatsMode.streaks)
            }
            .pickerStyle(.segmented)

            if selectedMode == .stats {
                StatsOverview(stats: stats)
            } else {
                StreakOverview(stats: stats)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(stats.dateRangeTitle)
                .font(BramFont.headline())
                .foregroundStyle(BramColor.textPrimary)

            WeeklyLoadCard(stats: stats)
            MuscleSetCard(stats: stats)
            HealthPlaceholderCard(title: "Apple Health", subtitle: "Sleep, recovery, and bodyweight will connect here.")
        }
    }
}

private struct WeeklyLoadCard: View {
    let stats: StatsWeekSnapshot

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Workout Load", systemImage: "scalemass.fill")
                    .font(BramFont.headline())
                    .foregroundStyle(BramColor.textPrimary)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(stats.loadByDay) { day in
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(BramColor.violet.opacity(day.volume == 0 ? 0.18 : 0.85))
                                .frame(height: barHeight(for: day.volume))
                            Text(day.weekday)
                                .font(BramFont.label(size: 11))
                                .foregroundStyle(BramColor.textTertiary)
                        }
                    }
                }
                .frame(height: 150, alignment: .bottom)
            }
        }
    }

    private func barHeight(for volume: Int) -> CGFloat {
        max(10, CGFloat(volume) / 190)
    }
}

private struct MuscleSetCard: View {
    let stats: StatsWeekSnapshot

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Set Volume")
                    .font(BramFont.headline())
                    .foregroundStyle(BramColor.textPrimary)

                ForEach(stats.setVolumeByMuscle) { metric in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(metric.muscleGroup)
                                .font(BramFont.label())
                                .foregroundStyle(BramColor.textPrimary)
                            Spacer()
                            Text("\(metric.sets) sets")
                                .font(BramFont.label(size: 13))
                                .foregroundStyle(BramColor.textSecondary)
                        }

                        GeometryReader { geometry in
                            Capsule()
                                .fill(metric.colorRole.color.opacity(0.85))
                                .frame(width: geometry.size.width * min(CGFloat(metric.sets) / 18, 1), height: 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
    }
}

private struct StreakOverview: View {
    let stats: StatsWeekSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BramCard {
                VStack(spacing: 14) {
                    RiveMascotPlaceholder(moment: .streak)
                    Text("\(stats.currentStreak)")
                        .font(BramFont.largeTitle(size: 72))
                        .foregroundStyle(BramColor.energy)
                    Text("days logged in a row")
                        .font(BramFont.headline())
                        .foregroundStyle(BramColor.textPrimary)
                    Text("Highest streak \(stats.highestStreak)")
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            HealthPlaceholderCard(title: "Streak repairs", subtitle: "Repair logic can be added after real workout history exists.")
        }
    }
}

private struct HealthPlaceholderCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        BramCard {
            HStack(spacing: 12) {
                Image(systemName: "heart.slash")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(BramColor.textTertiary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(BramFont.headline())
                        .foregroundStyle(BramColor.textPrimary)
                    Text(subtitle)
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textSecondary)
                }
            }
        }
    }
}

#Preview {
    StatsPanelView(stats: BramPreviewData.stats)
        .preferredColorScheme(.dark)
}
