import SwiftUI

struct AppRootView: View {
    var body: some View {
        HomeView()
            .tint(BramColor.violet)
            .font(BramFont.body())
    }
}

#Preview {
    AppRootView()
}
