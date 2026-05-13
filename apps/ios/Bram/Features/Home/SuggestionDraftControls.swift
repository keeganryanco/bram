import SwiftUI

struct SuggestionDraftControls: View {
    let draft: SuggestionDraft
    let onDelete: () -> Void
    let onThumbsUp: () -> Void
    let onThumbsDown: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label("Bram suggestion", systemImage: "sparkle")
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.textSecondary)

            Spacer()

            Button(action: onThumbsUp) {
                Image(systemName: "hand.thumbsup")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BramColor.violet)
            .accessibilityLabel("Suggestion was helpful")

            Button(action: onThumbsDown) {
                Image(systemName: "hand.thumbsdown")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BramColor.textSecondary)
            .accessibilityLabel("Suggestion was not helpful")

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BramColor.textSecondary)
            .accessibilityLabel("Delete suggestion")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(BramColor.cardSurface.opacity(0.72), in: Capsule())
        .overlay {
            Capsule().stroke(BramColor.hairline.opacity(0.75), lineWidth: 1)
        }
    }
}

#Preview {
    SuggestionDraftControls(
        draft: SuggestionDraft(text: "Bram: Try 3 steady sets."),
        onDelete: {},
        onThumbsUp: {},
        onThumbsDown: {}
    )
    .padding()
    .background(BramColor.appBackground)
}
