import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct BramLogoMark: View {
    var size: CGFloat = 42

    var body: some View {
        Image("BramLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Bram")
            .overlay {
                if UIImage(named: "BramLogo") == nil {
                    Text("Bram")
                        .font(BramFont.wordmark(size: min(size * 0.62, 30)))
                        .foregroundStyle(BramColor.violet)
                        .frame(width: max(size * 1.8, 76), alignment: .leading)
                }
            }
    }
}

#Preview {
    BramLogoMark()
        .padding()
        .background(BramColor.appBackground)
}
