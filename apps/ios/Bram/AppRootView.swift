import SwiftUI

struct AppRootView: View {
    @ObservedObject var accountState: AccountSessionState

    init(accountState: AccountSessionState) {
        self.accountState = accountState
    }

    var body: some View {
        Group {
            switch accountState.status {
            case .initializing:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BramColor.appBackground)
            case .signedOut:
                accountGate(message: nil)
            case .needsOnboarding:
                OnboardingGateView(
                    account: accountState.settingsAccount,
                    goalsProfile: accountState.goalsProfile,
                    complete: accountState.completeOnboarding,
                    signOut: accountState.signOut
                )
            case .ready:
                HomeView(
                    account: accountState.settingsAccount,
                    initialGoalsProfile: accountState.goalsProfile,
                    featureAccess: accountState.featureAccess,
                    onSignOut: accountState.signOut,
                    onGoalsProfileSave: accountState.saveGoalsProfile
                )
            case .failed(let message):
                accountGate(message: message)
            }
        }
            .tint(BramColor.violet)
            .font(BramFont.body())
            .task {
                await accountState.start()
            }
            .onOpenURL { url in
                Task {
                    await accountState.handleCallbackURL(url)
                }
            }
    }

    private func accountGate(message: String?) -> some View {
        AccountGateView(
            message: message,
            signIn: accountState.signIn,
            signUp: accountState.signUp,
            signInWithApple: accountState.signInWithApple,
            signInWithGoogle: accountState.signInWithGoogle
        )
    }
}

#Preview {
    AppRootView(
        accountState: AccountSessionState(
            authService: nil,
            bootstrapService: nil,
            configurationError: BramSupabaseConfigurationError.missingValue("BramSupabasePublishableKey")
        )
    )
}
