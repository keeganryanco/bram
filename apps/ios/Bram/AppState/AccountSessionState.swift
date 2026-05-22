import Foundation

enum AccountSessionStatus: Equatable {
    case initializing
    case signedOut
    case needsOnboarding
    case needsPaywall
    case ready
    case failed(String)
}

private enum AccountAuthSource: Equatable {
    case unknown
    case email
    case apple
    case google
}

@MainActor
final class AccountSessionState: ObservableObject {
    @Published private(set) var status: AccountSessionStatus = .initializing
    @Published private(set) var account: AccountSnapshot?
    @Published private(set) var goalsProfile = BramPreviewData.goalsProfile
    @Published private(set) var onboardingDraft = OnboardingDraft()
    @Published private(set) var hasPendingCrashSupportPrompt = false
    @Published private(set) var canChangeEmailWithPassword = false
    @Published private(set) var paywallMessage: String?

    private let authService: (any BramAuthServicing)?
    private let bootstrapService: (any AccountBootstrapServicing)?
    private(set) var localStore: any WorkoutLocalStore
    private let paywallService: (any BramPaywallServicing)?
    private let entitlementRefreshService: (any BramEntitlementRefreshing)?
    private let promoRedemptionService: (any BramPromoRedeeming)?
    private let referralService: (any BramReferralProgramProviding)?
    private let welcomeEmailService: (any BramWelcomeEmailSending)?
    private let accountDeletionService: (any BramAccountDeleting)?
    private let passwordResetService: (any BramPasswordResetting)?
    private let analytics: any AnalyticsTracking
    private let supportService: (any SupportRequestSubmitting)?
    private let errorReporter: (any AppErrorReporting)?
    private let diagnosticsRecorder: AppDiagnosticsRecorder
    private var workoutSyncService: (any WorkoutSyncService)?
    private let localStoreFactory: ((UUID) -> any WorkoutLocalStore)?
    private let workoutSyncServiceFactory: ((any WorkoutLocalStore) -> (any WorkoutSyncService)?)?
    private let configurationError: Error?
    private var userId: UUID?
    private var didStart = false
    private var pendingReferralCode: String?

    init(
        authService: (any BramAuthServicing)?,
        bootstrapService: (any AccountBootstrapServicing)?,
        localStore: any WorkoutLocalStore = SQLiteWorkoutLocalStore.shared,
        paywallService: (any BramPaywallServicing)? = nil,
        entitlementRefreshService: (any BramEntitlementRefreshing)? = nil,
        promoRedemptionService: (any BramPromoRedeeming)? = nil,
        referralService: (any BramReferralProgramProviding)? = nil,
        welcomeEmailService: (any BramWelcomeEmailSending)? = nil,
        accountDeletionService: (any BramAccountDeleting)? = nil,
        passwordResetService: (any BramPasswordResetting)? = nil,
        analytics: any AnalyticsTracking = NoopAnalyticsService(),
        supportService: (any SupportRequestSubmitting)? = nil,
        errorReporter: (any AppErrorReporting)? = nil,
        diagnosticsRecorder: AppDiagnosticsRecorder = .shared,
        workoutSyncService: (any WorkoutSyncService)? = nil,
        localStoreFactory: ((UUID) -> any WorkoutLocalStore)? = nil,
        workoutSyncServiceFactory: ((any WorkoutLocalStore) -> (any WorkoutSyncService)?)? = nil,
        configurationError: Error? = nil
    ) {
        self.authService = authService
        self.bootstrapService = bootstrapService
        self.localStore = localStore
        self.paywallService = paywallService
        self.entitlementRefreshService = entitlementRefreshService
        self.promoRedemptionService = promoRedemptionService
        self.referralService = referralService
        self.welcomeEmailService = welcomeEmailService
        self.accountDeletionService = accountDeletionService
        self.passwordResetService = passwordResetService
        self.analytics = analytics
        self.supportService = supportService
        self.errorReporter = errorReporter
        self.diagnosticsRecorder = diagnosticsRecorder
        self.workoutSyncService = workoutSyncService
        self.localStoreFactory = localStoreFactory
        self.workoutSyncServiceFactory = workoutSyncServiceFactory
        self.configurationError = configurationError
        self.hasPendingCrashSupportPrompt = diagnosticsRecorder.beginSession()
    }

    static func configuredFromBundle() -> AccountSessionState {
        do {
            let configuration = try BramSupabaseConfiguration.fromBundle()
            let client = BramSupabaseClientFactory.makeClient(configuration: configuration)
            let analytics = PostHogAnalyticsService.configuredFromBundle()
            return AccountSessionState(
                authService: BramAuthService(client: client, configuration: configuration),
                bootstrapService: AccountBootstrapService(client: client),
                localStore: SQLiteWorkoutLocalStore.shared,
                paywallService: RevenueCatPaywallService.configuredFromBundle(),
                entitlementRefreshService: BramRevenueCatEntitlementRefreshClient.configuredFromBundle(),
                promoRedemptionService: BramPromoRedemptionClient.configuredFromBundle(),
                referralService: BramReferralProgramClient.configuredFromBundle(),
                welcomeEmailService: BramAccountWelcomeEmailClient.configuredFromBundle(),
                accountDeletionService: BramAccountDeletionClient.configuredFromBundle(),
                passwordResetService: BramPasswordResetClient.configuredFromBundle(),
                analytics: analytics,
                supportService: BramSupportClient.configuredFromBundle(),
                errorReporter: BramErrorReportClient.configuredFromBundle(),
                localStoreFactory: { SQLiteWorkoutLocalStore.accountScoped(userId: $0) },
                workoutSyncServiceFactory: { SupabaseWorkoutSyncService(client: client, localStore: $0) }
            )
        } catch {
            return AccountSessionState(
                authService: nil,
                bootstrapService: nil,
                configurationError: error
            )
        }
    }

    var settingsAccount: SettingsAccountState {
        guard let account else {
            return BramPreviewData.account
        }
        return SettingsAccountState(
            userId: userId,
            displayName: account.displayName ?? "Bram user",
            email: account.email,
            accountTier: account.accountTier,
            isDeveloper: account.isDeveloper,
            founderOfferEligible: account.founderOfferEligible,
            activePromoKind: account.activePromoKind,
            activePromoLabel: account.activePromoLabel,
            appleHealthConnected: false,
            appearance: "System",
            preferredUnits: account.preferredUnits,
            canChangeEmailWithPassword: canChangeEmailWithPassword
        )
    }

    var featureAccess: BramFeatureAccess {
        BramEntitlementPolicy.access(for: account)
    }

    func start() async {
        guard !didStart else { return }
        didStart = true

        if let configurationError {
            status = .failed(configurationError.localizedDescription)
            return
        }

        guard let authService else {
            status = .failed("Account services are not configured.")
            return
        }

        do {
            guard let restoredUserId = try await authService.restoreSessionUserId() else {
                status = .signedOut
                analytics.track(AnalyticsEvent(name: "session_restored", properties: ["result": "signed_out"]))
                return
            }
            try await bootstrap(userId: restoredUserId)
            analytics.track(AnalyticsEvent(name: "session_restored", properties: ["result": "signed_in"]))
        } catch {
            reportNonFatal(source: "account", eventName: "session_restore_failed", error: error)
            status = .failed(error.localizedDescription)
        }
    }

    func markAppScenePhase(active: Bool) {
        if active {
            _ = diagnosticsRecorder.beginSession()
        } else {
            diagnosticsRecorder.markCleanExit()
        }
    }

    func signUp(email: String, password: String) async {
        await authenticate(source: .email) {
            do {
                if let userId = try await authService?.signUp(email: email, password: password) {
                    return userId
                }
            } catch {
                guard Self.isExistingAccountError(error) else { throw error }
            }

            do {
                guard let userId = try await authService?.signIn(email: email, password: password) else {
                    throw AccountSessionError.accountServicesUnavailable
                }
                return userId
            } catch {
                if Self.isInvalidCredentialsError(error) {
                    throw AccountSessionError.invalidCredentials
                }
                throw error
            }
        }
    }

    func signIn(email: String, password: String) async {
        await authenticate(source: .email) {
            do {
                guard let userId = try await authService?.signIn(email: email, password: password) else {
                    throw AccountSessionError.accountServicesUnavailable
                }
                return userId
            } catch {
                if Self.isInvalidCredentialsError(error) {
                    throw AccountSessionError.invalidCredentials
                }
                throw error
            }
        }
    }

    func resetPassword(email: String) async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else {
            status = .failed("Enter your email and Bram can send a reset link.")
            return
        }

        do {
            guard let passwordResetService else {
                throw AccountSessionError.accountServicesUnavailable
            }
            try await passwordResetService.sendResetEmail(email: cleanEmail)
            analytics.track(AnalyticsEvent(name: "password_reset_requested", properties: ["source": "account_gate"]))
            status = .failed("Password reset email sent. Check your inbox for the reset link.")
        } catch {
            reportNonFatal(source: "account", eventName: "password_reset_failed", error: error)
            status = .failed(error.localizedDescription)
        }
    }

    func signInWithApple() async {
        await authenticate(source: .apple) {
            guard let userId = try await authService?.signInWithOAuth(.apple) else {
                throw AccountSessionError.noSessionAfterOAuth
            }
            return userId
        }
    }

    func signInWithGoogle() async {
        await authenticate(source: .google) {
            guard let userId = try await authService?.signInWithOAuth(.google) else {
                throw AccountSessionError.noSessionAfterOAuth
            }
            return userId
        }
    }

    func handleCallbackURL(_ url: URL) async {
        if let referralCode = Self.referralCode(from: url) {
            pendingReferralCode = referralCode
            analytics.track(AnalyticsEvent(name: "referral_deep_link_opened", properties: [:]))
            await claimPendingReferralIfPossible()
            return
        }

        await authenticate {
            guard let userId = try await authService?.handleCallbackURL(url) else {
                throw AccountSessionError.accountServicesUnavailable
            }
            return userId
        }
    }

    func completeOnboarding(with profile: TrainingGoalsProfile) async {
        await completeOnboarding(firstName: onboardingDraft.firstName, profile: profile)
    }

    func saveOnboardingProgress(draft: OnboardingDraft, profile: TrainingGoalsProfile) async {
        onboardingDraft = draft.sanitized
        goalsProfile = profile.sanitized
        try? await localStore.save(onboardingDraft)
        try? await localStore.save(goalsProfile)
    }

    func trackOnboardingStepViewed(_ step: OnboardingStep) {
        analytics.track(
            AnalyticsEvent(
                name: "onboarding_step_viewed",
                properties: ["step": step.analyticsName, "index": "\(step.rawValue)"]
            )
        )
    }

    func trackOnboardingStepCompleted(_ step: OnboardingStep, profile: TrainingGoalsProfile) {
        analytics.track(
            AnalyticsEvent(
                name: "onboarding_step_completed",
                properties: onboardingProperties(step: step, profile: profile)
            )
        )
    }

    func requestOnboardingHealthAccess() async -> HealthAuthorizationState {
        do {
            let healthService = AppleHealthService()
            let requestedState = try await healthService.requestAuthorization()
            var state = requestedState
            if requestedState.canAttemptRefresh,
               let refreshed = try? await healthService.refreshHealthData(for: .now) {
                if let metric = refreshed.dailyMetric, Self.hasHealthMetricValue(metric) {
                    try? await localStore.save(metric)
                }
                state = HealthAuthorizationState.afterSuccessfulRefresh(
                    hasImportedHealthData: Self.hasHealthMetricValue(refreshed.dailyMetric) || !refreshed.workouts.isEmpty
                )
            }
            analytics.track(
                AnalyticsEvent(
                    name: "onboarding_permission_set",
                    properties: [
                        "permission": "apple_health",
                        "state": state.rawValue
                    ]
                )
            )
            return state
        } catch {
            reportNonFatal(source: "onboarding", eventName: "apple_health_permission_failed", error: error)
            return .error
        }
    }

    func requestOnboardingNotificationAccess() async {
        do {
            let granted = try await BramNotificationService().requestAuthorization()
            analytics.track(
                AnalyticsEvent(
                    name: "onboarding_permission_set",
                    properties: [
                        "permission": "notifications",
                        "granted": granted ? "true" : "false"
                    ]
                )
            )
        } catch {
            reportNonFatal(source: "onboarding", eventName: "notification_permission_failed", error: error)
        }
    }

    func completeOnboarding(firstName: String, profile: TrainingGoalsProfile) async {
        guard let userId, let bootstrapService else {
            status = .failed(AccountSessionError.accountServicesUnavailable.localizedDescription)
            return
        }

        status = .initializing
        do {
            let cleanName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanProfile = profile.sanitized
            try await localStore.save(OnboardingDraft(firstName: cleanName, step: .paywall))
            try await localStore.save(cleanProfile)
            let result = try await bootstrapService.saveOnboarding(firstName: cleanName, profile: cleanProfile, userId: userId)
            try? await localStore.clearOnboardingDraft()
            await configurePaywallIfPossible(userId: userId)
            analytics.track(
                AnalyticsEvent(
                    name: "onboarding_completed",
                    properties: onboardingProperties(step: .recap, profile: cleanProfile)
                )
            )
            apply(result)
        } catch {
            reportNonFatal(source: "onboarding", eventName: "onboarding_completion_failed", error: error)
            status = .failed(error.localizedDescription)
        }
    }

    func saveGoalsProfile(_ profile: TrainingGoalsProfile) async {
        guard let userId, let bootstrapService else { return }
        do {
            try await localStore.save(profile.sanitized)
            let result = try await bootstrapService.saveGoalsProfile(profile: profile, userId: userId)
            analytics.track(
                AnalyticsEvent(
                    name: "goals_saved",
                    properties: [
                        "primary_goal": profile.primaryGoal.rawValue,
                        "unit_preference": profile.preferredUnits.rawValue,
                        "weekly_days_bucket": Self.bucketDays(profile.weeklyTrainingDays),
                        "session_length_bucket": Self.bucketMinutes(profile.sessionLengthMinutes)
                    ]
                )
            )
            apply(result)
        } catch {
            reportNonFatal(source: "settings", eventName: "goals_save_failed", error: error)
            status = .failed(error.localizedDescription)
        }
    }

    func updateDisplayName(_ displayName: String) async throws {
        guard let userId, let bootstrapService else {
            throw AccountSessionError.accountServicesUnavailable
        }
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw AccountSessionError.invalidAccountUpdate("Enter the name you want Bram to use.")
        }

        let result = try await bootstrapService.saveDisplayName(cleanName, userId: userId)
        apply(result)
        track(AnalyticsEvent(name: "account_name_updated", properties: [:]))
    }

    func updateEmail(newEmail: String, password: String) async throws {
        guard canChangeEmailWithPassword,
              let currentEmail = account?.email,
              let authService
        else {
            throw AccountSessionError.invalidAccountUpdate("Email changes are available only for email and password accounts.")
        }
        let cleanEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            throw AccountSessionError.invalidAccountUpdate("Enter a valid email address.")
        }
        guard !password.isEmpty else {
            throw AccountSessionError.invalidAccountUpdate("Enter your current password to change your email.")
        }

        do {
            try await authService.updateEmail(currentEmail: currentEmail, password: password, newEmail: cleanEmail)
            track(AnalyticsEvent(name: "account_email_update_requested", properties: [:]))
        } catch {
            if Self.isInvalidCredentialsError(error) {
                throw AccountSessionError.invalidAccountUpdate("That password is not correct.")
            }
            throw error
        }
    }

    func sendCurrentAccountPasswordReset() async throws {
        guard let email = account?.email, let passwordResetService else {
            throw AccountSessionError.accountServicesUnavailable
        }
        try await passwordResetService.sendResetEmail(email: email)
        track(AnalyticsEvent(name: "password_reset_requested", properties: ["source": "settings"]))
    }

    func syncPendingWorkoutData() async {
        guard let userId, let workoutSyncService else { return }
        do {
            try await workoutSyncService.syncPendingAccountData(userId: userId)
            analytics.track(AnalyticsEvent(name: "workout_sync_succeeded", properties: [:]))
        } catch {
            reportNonFatal(source: "sync", eventName: "workout_sync_failed", error: error)
        }
    }

    func loadPaywall() async throws -> BramPaywallSnapshot {
        guard let paywallService else { throw BramPaywallError.notConfigured }
        return try await paywallService.loadPaywall()
    }

    func trackPaywallImpression() {
        paywallService?.trackPaywallImpression()
        analytics.track(AnalyticsEvent(name: "paywall_viewed", properties: ["source": "account_gate"]))
    }

    func purchase(packageId: String) async {
        paywallMessage = nil
        diagnosticsRecorder.suppressCrashPromptTemporarily()
        analytics.track(AnalyticsEvent(name: "purchase_started", properties: ["package_id": packageId]))
        await runPaywallAction {
            try await paywallService?.purchase(packageId: packageId)
        }
    }

    func continueToTesting() async {
        guard let account, account.usesReviewTestingPaywall else { return }
        analytics.track(AnalyticsEvent(name: "review_testing_paywall_bypassed", properties: [:]))
        status = .ready
    }

    func restorePurchases() async {
        paywallMessage = nil
        diagnosticsRecorder.suppressCrashPromptTemporarily()
        analytics.track(AnalyticsEvent(name: "restore_purchases_started", properties: ["source": "paywall"]))
        await runPaywallAction {
            try await paywallService?.restorePurchases()
        }
    }

    func redeemAppleOfferCode() async {
        paywallMessage = "Enter your App Store offer code. Bram will check access when you return."
        analytics.track(AnalyticsEvent(name: "apple_offer_code_sheet_opened", properties: ["source": "paywall"]))
        paywallService?.presentCodeRedemption()
    }

    func retryPaywallAccess() async {
        paywallMessage = nil
        diagnosticsRecorder.suppressCrashPromptTemporarily(duration: 120)
        analytics.track(AnalyticsEvent(name: "paywall_access_retry_started", properties: [:]))
        await runPaywallAction {}
    }

    func redeemPromoCode(_ code: String) async throws {
        guard let token = try await authService?.currentAccessToken(),
              let promoRedemptionService
        else {
            throw AccountSessionError.accountServicesUnavailable
        }

        analytics.track(AnalyticsEvent(name: "promo_redemption_started", properties: ["source": "paywall"]))
        let refreshed = try await promoRedemptionService.redeem(code: code, accessToken: token)
        analytics.track(
            AnalyticsEvent(
                name: "promo_redemption_succeeded",
                properties: ["account_tier": refreshed.accountTier.rawValue]
            )
        )
        let result = AccountBootstrapResult(account: refreshed, goalsProfile: goalsProfile)
        apply(result)
    }

    func track(_ event: AnalyticsEvent) {
        diagnosticsRecorder.record(eventName: event.name, properties: event.properties)
        analytics.track(event)
    }

    func currentAccessToken() async -> String? {
        try? await authService?.currentAccessToken()
    }

    func reportNonFatal(
        source: String,
        eventName: String,
        message: String? = nil,
        error: Error? = nil,
        metadata: [String: String] = [:]
    ) {
        analytics.track(
            AnalyticsEvent(
                name: "nonfatal_error",
                properties: [
                    "source": source,
                    "event_name": eventName
                ].merging(metadata) { current, _ in current }
            )
        )
        diagnosticsRecorder.record(
            eventName: eventName,
            properties: ["source": source].merging(metadata) { current, _ in current }
        )
        if let error {
            analytics.capture(
                error: error,
                properties: [
                    "source": source,
                    "event_name": eventName
                ].merging(metadata) { current, _ in current }
            )
        }

        guard let errorReporter else { return }
        Task {
            guard let token = try? await authService?.currentAccessToken() else { return }
            try? await errorReporter.report(
                AppErrorReport(
                    severity: .error,
                    source: source,
                    eventName: eventName,
                    message: message ?? error?.localizedDescription,
                    errorCode: nil,
                    metadata: metadata
                ),
                accessToken: token
            )
        }
    }

    func submitSupportRequest(_ draft: SupportRequestDraft) async throws {
        guard let token = try await authService?.currentAccessToken(),
              let supportService
        else {
            throw AccountSessionError.accountServicesUnavailable
        }

        try await supportService.submit(draft, accessToken: token)
        track(
            AnalyticsEvent(
                name: "support_submitted",
                properties: [
                    "category": draft.category.rawValue,
                    "include_diagnostics": draft.includeDiagnostics ? "true" : "false"
                ]
            )
        )
    }

    func dismissCrashSupportPrompt() {
        diagnosticsRecorder.dismissCrashPrompt()
        hasPendingCrashSupportPrompt = false
        track(AnalyticsEvent(name: "crash_support_prompt_dismissed", properties: [:]))
    }

    func submitCrashSupportRequest() async {
        do {
            try await submitSupportRequest(
                SupportRequestDraft(
                    category: .bug,
                    message: "Bram appears to have closed unexpectedly on the previous app session. Please review the attached diagnostics.",
                    contactEmail: account?.email,
                    includeDiagnostics: true,
                    source: "previous_crash_prompt"
                )
            )
            diagnosticsRecorder.clearPendingCrashPrompt()
            hasPendingCrashSupportPrompt = false
            track(AnalyticsEvent(name: "crash_support_submitted", properties: [:]))
        } catch {
            reportNonFatal(source: "support", eventName: "crash_support_submit_failed", error: error)
            hasPendingCrashSupportPrompt = false
        }
    }

    func signOut() async {
        do {
            try await authService?.signOut()
        } catch {
            status = .failed(error.localizedDescription)
            return
        }
        analytics.track(AnalyticsEvent(name: "account_signed_out", properties: [:]))
        analytics.reset()
        userId = nil
        account = nil
        canChangeEmailWithPassword = false
        paywallMessage = nil
        goalsProfile = BramPreviewData.goalsProfile
        onboardingDraft = OnboardingDraft()
        status = .signedOut
    }

    func deleteAccount() async {
        do {
            guard let token = try await authService?.currentAccessToken() else {
                throw AccountSessionError.accountServicesUnavailable
            }
            guard let accountDeletionService else {
                throw AccountSessionError.accountServicesUnavailable
            }
            try await accountDeletionService.deleteAccount(accessToken: token)
            try? await localStore.clearLocalAccountData()
            if let userId {
                try? KeychainWorkoutNoteBodyKeyStore().deleteKey(userId: userId)
            }
            try? await authService?.signOut()
            analytics.track(AnalyticsEvent(name: "account_deleted", properties: [:]))
            analytics.reset()
            userId = nil
            account = nil
            canChangeEmailWithPassword = false
            paywallMessage = nil
            goalsProfile = BramPreviewData.goalsProfile
            onboardingDraft = OnboardingDraft()
            status = .signedOut
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func authenticate(source: AccountAuthSource = .unknown, _ operation: () async throws -> UUID) async {
        paywallMessage = nil
        status = .initializing
        do {
            let userId = try await operation()
            analytics.track(AnalyticsEvent(name: "auth_succeeded", properties: [:]))
            try await bootstrap(userId: userId, authSource: source)
            sendWelcomeEmailIfPossible()
        } catch let error as AccountSessionError {
            analytics.track(AnalyticsEvent(name: "auth_failed", properties: ["reason": error.analyticsReason]))
            status = .failed(error.localizedDescription)
        } catch {
            analytics.track(AnalyticsEvent(name: "auth_failed", properties: ["reason": "unknown"]))
            reportNonFatal(source: "account", eventName: "auth_failed", error: error)
            status = .failed(error.localizedDescription)
        }
    }

    private func bootstrap(userId: UUID, authSource: AccountAuthSource = .unknown) async throws {
        guard let bootstrapService else {
            throw AccountSessionError.accountServicesUnavailable
        }
        configureLocalAccountStoreIfNeeded(userId: userId)
        var result = try await bootstrapService.bootstrap(userId: userId)
        self.userId = userId
        analytics.identify(
            userId: userId,
            properties: [
                "platform": "ios",
                "account_tier": result.account.accountTier.rawValue,
                "subscription_status": result.account.subscriptionStatus.rawValue,
                "is_developer": result.account.isDeveloper ? "true" : "false",
                "preferred_units": result.account.preferredUnits
            ]
        )
        var canSafelyPullRemoteWorkoutData = true
        do {
            try await workoutSyncService?.syncPendingAccountData(userId: userId)
        } catch {
            canSafelyPullRemoteWorkoutData = false
            reportNonFatal(source: "sync", eventName: "workout_sync_before_pull_failed", error: error)
        }
        if canSafelyPullRemoteWorkoutData {
            do {
                try await workoutSyncService?.pullAccountData(userId: userId)
            } catch {
                reportNonFatal(source: "sync", eventName: "workout_pull_failed", error: error)
            }
        }
        if result.needsOnboarding {
            analytics.track(AnalyticsEvent(name: "onboarding_started", properties: ["source": "bootstrap"]))
            if authSource == .apple, Self.nonBlank(result.account.displayName) == nil {
                result = try await bootstrapService.saveDisplayName("Bram user", userId: userId)
            }

            var draft = (try? await localStore.onboardingDraft()) ?? OnboardingDraft()
            if authSource == .apple {
                draft.firstName = Self.nonBlank(result.account.displayName) ?? "Bram user"
                if draft.step == .name {
                    draft.step = .goal
                }
                try? await localStore.save(draft)
            }
            onboardingDraft = draft
            goalsProfile = (try? await localStore.trainingGoalsProfile()) ?? result.goalsProfile
        } else {
            onboardingDraft = OnboardingDraft(firstName: result.account.displayName ?? "", step: .paywall)
            goalsProfile = result.goalsProfile
            await configurePaywallIfPossible(userId: userId)
        }
        canChangeEmailWithPassword = (try? await authService?.canChangeEmailWithPassword()) ?? false
        apply(result)
        await claimPendingReferralIfPossible()
    }

    private func apply(_ result: AccountBootstrapResult) {
        account = result.account
        if !result.needsOnboarding {
            goalsProfile = result.goalsProfile
        }
        if result.needsOnboarding {
            status = .needsOnboarding
        } else if result.account.usesReviewTestingPaywall {
            status = .needsPaywall
        } else if Self.canEnterApp(account: result.account) {
            status = .ready
        } else {
            status = .needsPaywall
        }
    }

    private static func canEnterApp(account: AccountSnapshot) -> Bool {
        account.hasPremiumAccess || account.hasDeveloperAccess
    }

    private func onboardingProperties(step: OnboardingStep, profile: TrainingGoalsProfile) -> [String: String] {
        [
            "step": step.analyticsName,
            "primary_goal": profile.primaryGoal.rawValue,
            "unit_preference": profile.preferredUnits.rawValue,
            "weekly_days_bucket": Self.bucketDays(profile.weeklyTrainingDays),
            "session_length_bucket": Self.bucketMinutes(profile.sessionLengthMinutes),
            "style_count": "\(profile.trainingStyles.count)",
            "equipment_count": "\(profile.equipment.count)"
        ]
    }

    private static func bucketDays(_ days: Int) -> String {
        switch days {
        case ..<3: "1_2"
        case 3...4: "3_4"
        case 5...7: "5_7"
        default: "8_plus"
        }
    }

    private static func bucketMinutes(_ minutes: Int) -> String {
        switch minutes {
        case ..<45: "under_45"
        case 45..<75: "45_74"
        case 75..<105: "75_104"
        default: "105_plus"
        }
    }

    private static func isExistingAccountError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("already registered") || message.contains("already exists")
    }

    private static func isInvalidCredentialsError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("invalid login credentials")
            || message.contains("invalid credentials")
            || message.contains("email or password")
    }

    private func configurePaywallIfPossible(userId: UUID) async {
        do {
            try await paywallService?.configure(userId: userId)
        } catch {
            reportNonFatal(source: "paywall", eventName: "revenuecat_login_failed", error: error)
        }
    }

    private func configureLocalAccountStoreIfNeeded(userId: UUID) {
        guard self.userId != userId, let localStoreFactory else { return }
        localStore = localStoreFactory(userId)
        workoutSyncService = workoutSyncServiceFactory?(localStore)
    }

    private func sendWelcomeEmailIfPossible() {
        guard let welcomeEmailService else { return }
        Task {
            do {
                guard let token = try await authService?.currentAccessToken() else { return }
                try await welcomeEmailService.sendWelcomeEmail(accessToken: token)
            } catch {
                reportNonFatal(source: "account", eventName: "welcome_email_failed", error: error)
            }
        }
    }

    private func runPaywallAction(_ action: () async throws -> Void) async {
        do {
            guard let userId else { throw AccountSessionError.accountServicesUnavailable }
            try await action()
            guard let token = try await authService?.currentAccessToken() else {
                throw BramPaywallError.refreshFailed
            }
            if let refreshed = try await entitlementRefreshService?.refresh(accessToken: token) {
                let result = AccountBootstrapResult(account: refreshed, goalsProfile: goalsProfile)
                apply(result)
                paywallMessage = result.account.hasPremiumAccess || result.account.hasDeveloperAccess ? nil : "No active App Store subscription was found yet."
            } else if let bootstrapService {
                let result = try await bootstrapService.bootstrap(userId: userId)
                apply(result)
                paywallMessage = result.account.hasPremiumAccess || result.account.hasDeveloperAccess ? nil : "No active App Store subscription was found yet."
            }
        } catch BramPaywallError.purchaseCancelled {
            analytics.track(AnalyticsEvent(name: "purchase_cancelled", properties: [:]))
            paywallMessage = nil
            status = .needsPaywall
        } catch {
            reportNonFatal(source: "paywall", eventName: "paywall_action_failed", error: error)
            paywallMessage = "We couldn't confirm App Store access yet. Restore or try again."
            status = .needsPaywall
        }
    }

    private static func hasHealthMetricValue(_ metric: HealthDailyMetric?) -> Bool {
        guard let metric else { return false }
        return metric.activeEnergyCalories != nil ||
            metric.averageHeartRate != nil ||
            metric.bodyweightValue != nil ||
            metric.workoutDurationMinutes != nil
    }

    private func claimPendingReferralIfPossible() async {
        guard let code = pendingReferralCode,
              let referralService,
              let token = try? await authService?.currentAccessToken()
        else { return }

        do {
            if let refreshed = try await entitlementRefreshService?.refresh(accessToken: token) {
                account = refreshed
            }
            let refreshed = try await referralService.claimReferral(code: code, accessToken: token)
            account = refreshed
            pendingReferralCode = nil
            analytics.track(AnalyticsEvent(name: "referral_claimed", properties: [:]))
        } catch {
            reportNonFatal(source: "referrals", eventName: "referral_claim_failed", error: error)
        }
    }

    private static func referralCode(from url: URL) -> String? {
        guard url.scheme == "app.trybram.Bram", url.host == "referral" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let rawCode = components?.queryItems?.first(where: { $0.name == "code" })?.value
        let normalized = rawCode?
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        guard let normalized, normalized.range(of: #"^BRAM[A-Z0-9]{6,14}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return normalized
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

enum AccountSessionError: LocalizedError {
    case accountServicesUnavailable
    case noSessionAfterSignup
    case noSessionAfterOAuth
    case invalidCredentials
    case invalidAccountUpdate(String)

    var errorDescription: String? {
        switch self {
        case .accountServicesUnavailable:
            "Account services are not configured."
        case .noSessionAfterSignup:
            "Signup succeeded, but no session was returned. Confirm email may still be enabled in Supabase."
        case .noSessionAfterOAuth:
            "The provider sign-in did not return a session."
        case .invalidCredentials:
            "Email or password is wrong."
        case .invalidAccountUpdate(let message):
            message
        }
    }

    var analyticsReason: String {
        switch self {
        case .accountServicesUnavailable: "services_unavailable"
        case .noSessionAfterSignup: "no_session_after_signup"
        case .noSessionAfterOAuth: "no_session_after_oauth"
        case .invalidCredentials: "invalid_credentials"
        case .invalidAccountUpdate: "invalid_account_update"
        }
    }
}

private extension OnboardingStep {
    var analyticsName: String {
        switch self {
        case .name: "name"
        case .goal: "goal"
        case .plan: "weekly_plan"
        case .training: "training_setup"
        case .body: "body_baseline"
        case .notePreview: "note_preview"
        case .appleHealth: "apple_health"
        case .notifications: "notifications"
        case .recap: "recap"
        case .paywall: "paywall"
        }
    }
}
