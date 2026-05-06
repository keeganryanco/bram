import SwiftUI

struct ParsedWorkoutSummaryCard: View {
    let summary: ParsedWorkoutSummary

    var body: some View {
        BramCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(summary.title, systemImage: "text.badge.checkmark")
                        .font(BramFont.headline())
                        .foregroundStyle(BramColor.textPrimary)
                    Spacer()
                    Text("Summary")
                        .font(BramFont.label(size: 12))
                        .foregroundStyle(BramColor.violet)
                }

                VStack(spacing: 10) {
                    ForEach(summary.exercises) { exercise in
                        ExerciseSummaryRow(exercise: exercise)
                    }
                }
            }
        }
    }
}

private struct ExerciseSummaryRow: View {
    let exercise: ParsedExerciseSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(BramFont.label())
                    .foregroundStyle(BramColor.textPrimary)
                Text(exercise.setSummary)
                    .font(BramFont.callout(size: 13))
                    .foregroundStyle(BramColor.textTertiary)
            }
            Spacer()
            Text(exercise.loadSummary)
                .font(BramFont.label(size: 13))
                .foregroundStyle(BramColor.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ParsedWorkoutSummaryCard(summary: BramPreviewData.populatedNote.parsedSummary!)
        .padding()
        .background(BramColor.appBackground)
}
