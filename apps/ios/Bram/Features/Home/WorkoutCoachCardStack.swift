import SwiftUI

struct WorkoutCoachCardStack: View {
    let cards: [WorkoutCoachCard]
    let onFeedback: (WorkoutCoachCard, SuggestionFeedbackAction) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(cards, id: \.stableDisplayKey) { card in
                WorkoutCoachCardView(card: card) { action in
                    onFeedback(card, action)
                }
            }
        }
    }
}

private struct WorkoutCoachCardView: View {
    let card: WorkoutCoachCard
    let onFeedback: (SuggestionFeedbackAction) -> Void
    @State private var showsFeedback = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 30, height: 30)
                .background(accentColor.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(card.title)
                            .font(BramFont.label(size: 12))
                            .foregroundStyle(accentColor)
                            .lineLimit(1)

                        if let metadata = card.metadata, !metadata.isEmpty {
                            Text(metadata)
                                .font(BramFont.label(size: 12))
                                .foregroundStyle(accentColor.opacity(0.82))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                    }
                    Text(card.text)
                        .font(BramFont.callout())
                        .foregroundStyle(BramColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if card.feedbackEligible, showsFeedback {
                    HStack(spacing: 8) {
                        feedbackButton("hand.thumbsup", label: "Suggestion was helpful") {
                            onFeedback(.thumbsUp)
                        }
                        feedbackButton("hand.thumbsdown", label: "Suggestion was not helpful") {
                            onFeedback(.thumbsDown)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(BramColor.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BramColor.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title). \(card.metadata ?? ""). \(card.text)")
        .task(id: card.stableDisplayKey) {
            showsFeedback = false
            guard card.feedbackEligible else { return }
            let delay = Int((max(4, card.minimumVisibleSeconds * 0.75) * 1_000).rounded())
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            showsFeedback = true
        }
    }

    private func feedbackButton(
        _ systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BramColor.textSecondary)
                .frame(width: 30, height: 28)
                .background(BramColor.cardSurface.opacity(0.78), in: Capsule())
        }
        .accessibilityLabel(label)
    }

    private var accentColor: Color {
        switch card.kind {
        case .progression:
            BramColor.energy
        case .recovery:
            BramColor.recovery
        case .balance:
            BramColor.cool
        case .reminder:
            BramColor.violet
        case .baseline:
            BramColor.textTertiary
        }
    }

    private var iconName: String {
        switch card.kind {
        case .progression:
            "arrow.up.right"
        case .recovery:
            "leaf.fill"
        case .balance:
            "scale.3d"
        case .reminder:
            "bell.fill"
        case .baseline:
            "bookmark.fill"
        }
    }
}

#Preview {
    WorkoutCoachCardStack(
        cards: [
            WorkoutCoachCard(kind: .progression, title: "Bench Press", text: "Repeat 205 and aim for 6 clean reps.", priority: 90, feedbackEligible: true),
            WorkoutCoachCard(kind: .recovery, text: "Keep today submaximal and leave one or two reps in reserve.", priority: 80)
        ],
        onFeedback: { _, _ in }
    )
    .padding()
    .background(BramColor.appBackground)
}
