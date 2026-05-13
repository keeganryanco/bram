import Foundation

enum AccountSessionStatus: Equatable {
    case initializing
    case signedOut
    case needsOnboarding
    case ready
    case failed(String)
}

@MainActor
final class AccountSessionState: ObservableObject {
    @Published private(set) var status: AccountSessionStatus = .initializing
    @Published private(set) var account: AccountSnapshot?
    @Published private(set) var goalsProfile = BramPreviewData.goalsProfile

    private let authService: (any BramAuthServicing)?
    private let bootstrapService: (any AccountBootstrapServicing)?
    private let configurationError: Error?
    private var userId: UUID?
    private var didStart = false

    init(
        authService: (any BramAuthServicing)?,
        bootstrapService: (any AccountBootstrapServicing)?,
        configurationError: Error? = nil
    ) {
        self.authService = authService
        self.bootstrapService = bootstrapService
        self.configurationError = configurationError
    }

    static func configuredFromBundle() -> AccountSessionState {
        do {
            let configuration = try BramSupabaseConfiguration.fromBundle()
            let client = BramSupabaseClientFactory.makeClient(configuration: configuration)
            return AccountSessionState(
                authService: BramAuthService(client: client, configuration: configuration),
                bootstrapService: AccountBootstrapService(client: client)
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
        guard let userId, let bootstrapService else {
            status = .failed(AccountSessionError.accountServicesUnavailable.localizedDescription)
            return
        }

        status = .initializing
        do {
            let result = try await bootstrapService.saveOnboarding(profile: profile, userId: userId)
            apply(result)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func saveGoalsProfile(_ profile: TrainingGoalsProfile) async {
        guard let userId, let bootstrapService else { return }
        do {
            let result = try await bootstrapService.saveOnboarding(profile: profile, userId: userId)
            apply(result)
        } catch {
            status = .failed(error.localizedDescription)
        }
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
        status = .signedOut
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
        let result = try await bootstrapService.bootstrap(userId: userId)
        self.userId = userId
        apply(result)
    }

    private func apply(_ result: AccountBootstrapResult) {
        account = result.account
        goalsProfile = result.goalsProfile
        status = result.needsOnboarding ? .needsOnboarding : .ready
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
