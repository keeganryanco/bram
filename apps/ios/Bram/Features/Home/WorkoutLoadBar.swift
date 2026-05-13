import SwiftUI

struct WorkoutLoadBar: View {
    let metrics: WorkoutMetricSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                MetricToken(icon: "number", value: "\(metrics.totalSets)", label: "sets", color: BramColor.violet)
                SeparatorDot()
                MetricToken(icon: "flame.fill", value: energyText, label: energyLabel, color: BramColor.energy)
                SeparatorDot()
                MetricToken(icon: "trophy.fill", value: "\(metrics.prCount)", label: "PR", color: BramColor.warning)
            }
            .padding(.horizontal, 18)
            .frame(height: 62)
            .background(.ultraThinMaterial)
            .background(BramColor.elevated.opacity(0.72))
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(BramColor.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 20, x: 0, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open workout stats")
    }

    private var energyText: String {
        guard let energy = metrics.activeEnergyCalories else { return "--" }
        return "\(energy)"
    }

    private var energyLabel: String {
        metrics.energyIsEstimated ? "est." : "cal"
    }

}

private struct MetricToken: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(BramFont.button())
                .foregroundStyle(BramColor.textPrimary)
            Text(label)
                .font(BramFont.label(size: 11))
                .foregroundStyle(BramColor.textTertiary)
        }
    }
}

private struct SeparatorDot: View {
    var body: some View {
        Circle()
            .fill(BramColor.textTertiary.opacity(0.45))
            .frame(width: 4, height: 4)
    }
}

#Preview {
    WorkoutLoadBar(metrics: BramPreviewData.populatedNote.metrics, action: {})
        .padding()
        .background(BramColor.appBackground)
}
