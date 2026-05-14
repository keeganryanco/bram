import Foundation

enum AccountSessionStatus: Equatable {
    case initializing
    case signedOut
    case needsOnboarding
    case needsPaywall
    case ready
    case failed(String)
}

@MainActor
final class AccountSessionState: ObservableObject {
    @Published private(set) var status: AccountSessionStatus = .initializing
    @Published private(set) var account: AccountSnapshot?
    @Published private(set) var goalsProfile = BramPreviewData.goalsProfile
    @Published private(set) var onboardingDraft = OnboardingDraft()

    private let authService: (any BramAuthServicing)?
    private let bootstrapService: (any AccountBootstrapServicing)?
    private(set) var localStore: any WorkoutLocalStore
    private let paywallService: (any BramPaywallServicing)?
    private let entitlementRefreshService: (any BramEntitlementRefreshing)?
    private let accountDeletionService: (any BramAccountDeleting)?
    private var workoutSyncService: (any WorkoutSyncService)?
    private let localStoreFactory: ((UUID) -> any WorkoutLocalStore)?
    private let workoutSyncServiceFactory: ((any WorkoutLocalStore) -> (any WorkoutSyncService)?)?
    private let configurationError: Error?
    private var userId: UUID?
    private var didStart = false

    init(
        authService: (any BramAuthServicing)?,
        bootstrapService: (any AccountBootstrapServicing)?,
        localStore: any WorkoutLocalStore = SQLiteWorkoutLocalStore.shared,
        paywallService: (any BramPaywallServicing)? = nil,
        entitlementRefreshService: (any BramEntitlementRefreshing)? = nil,
        accountDeletionService: (any BramAccountDeleting)? = nil,
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
        self.accountDeletionService = accountDeletionService
        self.workoutSyncService = workoutSyncService
        self.localStoreFactory = localStoreFactory
        self.workoutSyncServiceFactory = workoutSyncServiceFactory
        self.configurationError = configurationError
    }

    static func configuredFromBundle() -> AccountSessionState {
        do {
            let configuration = try BramSupabaseConfiguration.fromBundle()
            let client = BramSupabaseClientFactory.makeClient(configuration: configuration)
            return AccountSessionState(
                authService: BramAuthService(client: client, configuration: configuration),
                bootstrapService: AccountBootstrapService(client: client),
                localStore: SQLiteWorkoutLocalStore.shared,
                paywallService: RevenueCatPaywallService.configuredFromBundle(),
                entitlementRefreshService: BramRevenueCatEntitlementRefreshClient.configuredFromBundle(),
                accountDeletionService: BramAccountDeletionClient.configuredFromBundle(),
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
            displayName: account.displayName ?? "Bram user",
            email: account.email,
            accountTier: account.accountTier,
            isDeveloper: account.isDeveloper,
            founderOfferEligible: account.founderOfferEligible,
            appleHealthConnected: false,
            appearance: "System",
            preferredUnits: account.preferredUnits
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
                return
            }
            try await bootstrap(userId: restoredUserId)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func signUp(email: String, password: String) async {
        await authenticate {
            guard let userId = try await authService?.signUp(email: email, password: password) else {
                throw AccountSessionError.noSessionAfterSignup
            }
            return userId
        }
    }

    func signIn(email: String, password: String) async {
        await authenticate {
            guard let userId = try await authService?.signIn(email: email, password: password) else {
                throw AccountSessionError.accountServicesUnavailable
            }
            return userId
        }
    }

    func signInWithApple() async {
        await authenticate {
            guard let userId = try await authService?.signInWithOAuth(.apple) else {
                throw AccountSessionError.noSessionAfterOAuth
            }
            return userId
        }
    }

    func signInWithGoogle() async {
        await authenticate {
            guard let userId = try await authService?.signInWithOAuth(.google) else {
                throw AccountSessionError.noSessionAfterOAuth
            }
            return userId
        }
    }

    func handleCallbackURL(_ url: URL) async {
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
            apply(result)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func saveGoalsProfile(_ profile: TrainingGoalsProfile) async {
        guard let userId, let bootstrapService else { return }
        do {
            try await localStore.save(profile.sanitized)
            let result = try await bootstrapService.saveGoalsProfile(profile: profile, userId: userId)
            apply(result)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func syncPendingWorkoutData() async {
        guard let userId, let workoutSyncService else { return }
        try? await workoutSyncService.syncPendingAccountData(userId: userId)
    }

    func loadPaywall() async throws -> BramPaywallSnapshot {
        guard let paywallService else { throw BramPaywallError.notConfigured }
        return try await paywallService.loadPaywall()
    }

    func purchase(packageId: String) async {
        await runPaywallAction {
            try await paywallService?.purchase(packageId: packageId)
        }
    }

    func restorePurchases() async {
        await runPaywallAction {
            try await paywallService?.restorePurchases()
        }
    }

    func redeemCode() {
        paywallService?.presentCodeRedemption()
    }

    func signOut() async {
        do {
            try await authService?.signOut()
        } catch {
            status = .failed(error.localizedDescription)
            return
        }
        userId = nil
        account = nil
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
            try? await authService?.signOut()
            userId = nil
            account = nil
            goalsProfile = BramPreviewData.goalsProfile
            onboardingDraft = OnboardingDraft()
            status = .signedOut
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func authenticate(_ operation: () async throws -> UUID) async {
        status = .initializing
        do {
            let userId = try await operation()
            try await bootstrap(userId: userId)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func bootstrap(userId: UUID) async throws {
        guard let bootstrapService else {
            throw AccountSessionError.accountServicesUnavailable
        }
        configureLocalAccountStoreIfNeeded(userId: userId)
        let result = try await bootstrapService.bootstrap(userId: userId)
        self.userId = userId
        try? await workoutSyncService?.syncPendingAccountData(userId: userId)
        if result.needsOnboarding {
            onboardingDraft = (try? await localStore.onboardingDraft()) ?? OnboardingDraft()
            goalsProfile = (try? await localStore.trainingGoalsProfile()) ?? result.goalsProfile
        } else {
            onboardingDraft = OnboardingDraft(firstName: result.account.displayName ?? "", step: .paywall)
            goalsProfile = result.goalsProfile
            await configurePaywallIfPossible(userId: userId)
        }
        apply(result)
    }

    private func apply(_ result: AccountBootstrapResult) {
        account = result.account
        if !result.needsOnboarding {
            goalsProfile = result.goalsProfile
        }
        if result.needsOnboarding {
            status = .needsOnboarding
        } else if Self.canEnterApp(account: result.account) {
            status = .ready
        } else {
            status = .needsPaywall
        }
    }

    private static func canEnterApp(account: AccountSnapshot) -> Bool {
        account.hasPremiumAccess || account.hasDeveloperAccess
    }

    private func configurePaywallIfPossible(userId: UUID) async {
        try? paywallService?.configure(userId: userId)
    }

    private func configureLocalAccountStoreIfNeeded(userId: UUID) {
        guard self.userId != userId, let localStoreFactory else { return }
        localStore = localStoreFactory(userId)
        workoutSyncService = workoutSyncServiceFactory?(localStore)
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
            } else if let bootstrapService {
                let result = try await bootstrapService.bootstrap(userId: userId)
                apply(result)
            }
        } catch BramPaywallError.purchaseCancelled {
            status = .needsPaywall
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}

enum AccountSessionError: LocalizedError {
    case accountServicesUnavailable
    case noSessionAfterSignup
    case noSessionAfterOAuth

    var errorDescription: String? {
        switch self {
        case .accountServicesUnavailable:
            "Account services are not configured."
        case .noSessionAfterSignup:
            "Signup succeeded, but no session was returned. Confirm email may still be enabled in Supabase."
        case .noSessionAfterOAuth:
            "The provider sign-in did not return a session."
        }
    }
}
