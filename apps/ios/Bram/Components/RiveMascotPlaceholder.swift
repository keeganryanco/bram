import SwiftUI
import RiveRuntime

struct RiveMascotPlaceholder: View {
    let moment: MascotMoment

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(BramColor.violet)
                .frame(width: 56, height: 56)
                .background(BramColor.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("Rive-ready")
                .font(BramFont.label(size: 12))
                .foregroundStyle(BramColor.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bram animation placeholder")
    }

    private var symbolName: String {
        switch moment {
        case .idle:
            "sparkles"
        case .streak:
            "flame.fill"
        case .weeklyReview:
            "chart.xyaxis.line"
        }
    }
}
