import SwiftUI

struct WorkoutSuggestionCard: View {
    let suggestion: WorkoutSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 30, height: 30)
                .background(accentColor.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.kind.rawValue)
                    .font(BramFont.label(size: 12))
                    .foregroundStyle(accentColor)
                Text(suggestion.text)
                    .font(BramFont.callout())
                    .foregroundStyle(BramColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
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
    }

    private var accentColor: Color {
        switch suggestion.kind {
        case .progression:
            BramColor.violet
        case .recovery:
            BramColor.recovery
        case .balance:
            BramColor.cool
        case .reminder:
            BramColor.energy
        }
    }

    private var iconName: String {
        switch suggestion.kind {
        case .progression:
            "arrow.up.right"
        case .recovery:
            "leaf.fill"
        case .balance:
            "scale.3d"
        case .reminder:
            "bell.fill"
        }
    }
}

#Preview {
    WorkoutSuggestionCard(suggestion: BramPreviewData.populatedNote.suggestion!)
        .padding()
        .background(BramColor.appBackground)
}
