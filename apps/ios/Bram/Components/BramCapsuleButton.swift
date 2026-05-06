import SwiftUI

struct BramCapsuleButton<Content: View>: View {
    let action: () -> Void
    private let content: Content

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .font(BramFont.button())
                .foregroundStyle(BramColor.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(BramColor.elevated)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(BramColor.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}
