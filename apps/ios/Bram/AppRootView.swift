import SwiftUI

struct AppRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
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
                OnboardingFlowView(
                    account: accountState.settingsAccount,
                    initialDraft: accountState.onboardingDraft,
                    initialProfile: accountState.goalsProfile,
                    saveProgress: accountState.saveOnboardingProgress,
                    complete: accountState.completeOnboarding,
                    signOut: accountState.signOut,
                    trackStepViewed: accountState.trackOnboardingStepViewed,
                    trackStepCompleted: accountState.trackOnboardingStepCompleted
                )
            case .needsPaywall:
                PaywallGateView(
                    account: accountState.settingsAccount,
                    load: accountState.loadPaywall,
                    trackImpression: accountState.trackPaywallImpression,
                    purchase: accountState.purchase,
                    restore: accountState.restorePurchases,
                    redeem: accountState.redeemCode,
                    signOut: accountState.signOut
                )
            case .ready:
                HomeView(
                    account: accountState.settingsAccount,
                    initialGoalsProfile: accountState.goalsProfile,
                    noteStore: accountState.localStore,
                    featureAccess: accountState.featureAccess,
                    onSignOut: accountState.signOut,
                    onDeleteAccount: accountState.deleteAccount,
                    onGoalsProfileSave: accountState.saveGoalsProfile,
                    onWorkoutDataSaved: accountState.syncPendingWorkoutData,
                    track: accountState.track,
                    reportError: { source, eventName, message, error, metadata in
                        accountState.reportNonFatal(
                            source: source,
                            eventName: eventName,
                            message: message,
                            error: error,
                            metadata: metadata
                        )
                    },
                    submitSupportRequest: accountState.submitSupportRequest
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
            .onChange(of: scenePhase) { _, phase in
                accountState.markAppScenePhase(active: phase == .active)
            }
            .alert("Bram closed unexpectedly", isPresented: crashPromptBinding) {
                Button("Not now", role: .cancel) {
                    accountState.dismissCrashSupportPrompt()
                }
                Button("Send diagnostics") {
                    Task {
                        await accountState.submitCrashSupportRequest()
                    }
                }
            } message: {
                Text("Send recent app diagnostics to support so we can investigate. Workout note text is not included.")
            }
            .transaction { transaction in
                if reduceMotion {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
    }

    private var crashPromptBinding: Binding<Bool> {
        Binding(
            get: { accountState.hasPendingCrashSupportPrompt && accountState.status == .ready },
            set: { isPresented in
                if !isPresented {
                    accountState.dismissCrashSupportPrompt()
                }
            }
        )
    }

    private func accountGate(message: String?) -> some View {
        AccountGateView(
            message: message,
            signIn: accountState.signIn,
            signUp: accountState.signUp,
            resetPassword: accountState.resetPassword,
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
