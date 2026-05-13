import SwiftUI

struct InterpretedLineDetailView: View {
    let line: InterpretedWorkoutLine

    var body: some View {
        BramPanelChrome(title: line.detailTitle) {
            VStack(alignment: .leading, spacing: 16) {
                Text(line.rawText.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(BramFont.headline())
                    .foregroundStyle(BramColor.textPrimary)

                Text(line.detailText)
                    .font(BramFont.callout())
                    .foregroundStyle(BramColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(line.chipText)
                    .font(BramFont.button())
                    .foregroundStyle(BramColor.violet)
            }
        }
    }
}

#Preview {
    InterpretedLineDetailView(line: BramPreviewData.populatedNote.interpretedLines[0])
        .preferredColorScheme(.dark)
}
