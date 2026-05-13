import SwiftUI

@main
struct BramApp: App {
    @StateObject private var accountState = AccountSessionState.configuredFromBundle()

    var body: some Scene {
        WindowGroup {
            AppRootView(accountState: accountState)
        }
    }
}
