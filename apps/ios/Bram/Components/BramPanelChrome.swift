import SwiftUI

struct BramPanelChrome<Content: View>: View {
    let title: String
    let showsCloseButton: Bool
    private let content: Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, showsCloseButton: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showsCloseButton = showsCloseButton
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(BramColor.appBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: dismiss.callAsFunction) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(BramColor.textSecondary)
                                .frame(width: 34, height: 34)
                                .background(BramColor.elevated)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                }
            }
        }
    }
}
