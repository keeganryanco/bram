import Testing
import Foundation
import UIKit
@testable import Bram

struct BramTests {
    @Test func workoutNoteDefaultsToEmptyBody() {
        let note = WorkoutNote()
        #expect(note.body.isEmpty)
    }

    @Test func freePremiumAccountHasPremiumAccess() {
        let account = AccountSnapshot(
            userId: UUID(),
            email: "keegan@trybram.app",
            displayName: "Keegan",
            preferredUnits: "lb",
            onboardingCompletedAt: nil,
            accountTier: .freePremium,
            subscriptionStatus: .freePremium,
            entitlementSource: .manual,
            isDeveloper: true,
            founderOfferEligible: true,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )

        #expect(account.hasPremiumAccess)
        #expect(account.hasDeveloperAccess)
    }

    @Test func accountSnapshotDecodesSupabaseDateStrings() throws {
        let data = """
        {
          "user_id": "11111111-1111-4111-8111-111111111111",
          "email": "keegan@trybram.app",
          "display_name": "Keegan",
          "preferred_units": "lb",
          "onboarding_completed_at": "2026-05-13T12:00:00Z",
          "account_tier": "FREE_PREMIUM",
          "subscription_status": "FREE_PREMIUM",
          "entitlement_source": "MANUAL",
          "is_developer": true,
          "founder_offer_eligible": true,
          "premium_expires_at": null,
          "entitlements_updated_at": "2026-05-13T12:05:00Z"
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(AccountSnapshot.self, from: data)

        #expect(account.email == "keegan@trybram.app")
        #expect(account.hasPremiumAccess)
        #expect(account.onboardingCompletedAt != nil)
    }

    @Test func workoutNoteBodyEncryptionKeepsPlaintextOutOfSyncPayloadFields() throws {
        let userId = UUID()
        let key = Data(repeating: 7, count: 32)
        let encryptor = WorkoutNoteBodyEncryptionService(
            keyStore: InMemoryWorkoutNoteBodyKeyStore(key: key)
        )

        let encrypted = try #require(try encryptor.encrypt("Bench 185 3x8", userId: userId))

        #expect(encrypted.algorithm == "AES-256-GCM")
        #expect(encrypted.keyVersion == 1)
        #expect(encrypted.ciphertext.contains("Bench") == false)
        #expect(encrypted.nonce.isEmpty == false)
        #expect(try encryptor.decrypt(encrypted, userId: userId) == "Bench 185 3x8")

        #expect(Data(base64Encoded: encrypted.nonce)?.count == 12)
        #expect(Data(base64Encoded: encrypted.ciphertext)?.isEmpty == false)
    }

    @Test func freeAccountDoesNotUnlockPremiumSurfaces() {
        let account = AccountSnapshot(
            userId: UUID(),
            email: "free@trybram.app",
            displayName: nil,
            preferredUnits: "lb",
            onboardingCompletedAt: nil,
            accountTier: .free,
            subscriptionStatus: .none,
            entitlementSource: .none,
            isDeveloper: false,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )

        let access = BramEntitlementPolicy.access(for: account)

        #expect(!access.canUseInterpretation)
        #expect(!access.canUseStats)
        #expect(!access.canUseHealth)
        #expect(!access.canUseSuggestions)
        #expect(!access.canUseDeveloperFeatures)
    }

    @Test func developerAccountUnlocksAllPremiumSurfacesWithoutSubscription() {
        let account = AccountSnapshot(
            userId: UUID(),
            email: "dev@trybram.app",
            displayName: "Dev",
            preferredUnits: "lb",
            onboardingCompletedAt: .now,
            accountTier: .free,
            subscriptionStatus: .none,
            entitlementSource: .dev,
            isDeveloper: true,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )

        let access = BramEntitlementPolicy.access(for: account)

        #expect(access.canUseInterpretation)
        #expect(access.canUseStats)
        #expect(access.canUseHealth)
        #expect(access.canUseSuggestions)
        #expect(access.canUseDeveloperFeatures)
    }

    @Test func trainingGoalsProfileMapsToSupabasePayloads() {
        let userId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let completedAt = Date(timeIntervalSince1970: 1_777_777_777)
        let profile = TrainingGoalsProfile(
            primaryGoal: .stronger,
            weeklyTrainingDays: 5,
            sessionLengthMinutes: 75,
            trainingStyles: [.running, .gym],
            equipment: [.barbell, .dumbbells],
            heightValue: 72,
            currentWeightValue: 190,
            targetWeightValue: 185,
            currentWeightLoggedAt: completedAt,
            currentWeightSource: .manual,
            sex: .male,
            preferredUnits: .imperial,
            estimatedDailyCalories: 2_700
        )

        let training = TrainingGoalsSupabaseMapper.trainingUpsert(
            from: profile,
            userId: userId,
            onboardingCompletedAt: completedAt
        )
        let profileUpdate = TrainingGoalsSupabaseMapper.profileUpdate(
            from: profile,
            onboardingCompletedAt: completedAt
        )

        #expect(training.userId == userId)
        #expect(training.primaryGoal == "stronger")
        #expect(training.weeklyTrainingDays == 5)
        #expect(training.sessionLengthMinutes == 75)
        #expect(training.trainingStyles == ["gym", "running"])
        #expect(training.availableEquipment == ["barbell", "dumbbells"])
        #expect(profileUpdate.preferredUnits == "lb")
        #expect(profileUpdate.bodyweightValue == 190)
        #expect(profileUpdate.heightUnit == "in")
        #expect(profileUpdate.sex == "male")
        #expect(profileUpdate.estimatedDailyCalories == 2_700)
    }

    @MainActor
    @Test func accountBootstrapStateMovesSignedInUserToOnboarding() async {
        let userId = UUID()
        let account = AccountSnapshot(
            userId: userId,
            email: "new@trybram.app",
            displayName: nil,
            preferredUnits: "lb",
            onboardingCompletedAt: nil,
            accountTier: .free,
            subscriptionStatus: .none,
            entitlementSource: .none,
            isDeveloper: false,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: userId),
            bootstrapService: MockBootstrapService(result: AccountBootstrapResult(account: account, goalsProfile: TrainingGoalsProfile())),
            localStore: MockLocalStore()
        )

        await state.start()

        #expect(state.status == .needsOnboarding)
        #expect(state.account?.email == "new@trybram.app")
    }

    @MainActor
    @Test func accountBootstrapStateMovesSignedInUserToReady() async {
        let userId = UUID()
        let account = AccountSnapshot(
            userId: userId,
            email: "ready@trybram.app",
            displayName: "Ready",
            preferredUnits: "kg",
            onboardingCompletedAt: .now,
            accountTier: .premium,
            subscriptionStatus: .active,
            entitlementSource: .appStore,
            isDeveloper: false,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: userId),
            bootstrapService: MockBootstrapService(result: AccountBootstrapResult(account: account, goalsProfile: TrainingGoalsProfile())),
            localStore: MockLocalStore()
        )

        await state.start()

        #expect(state.status == .ready)
        #expect(state.featureAccess.canUseStats)
        #expect(state.settingsAccount.email == "ready@trybram.app")
    }

    @MainActor
    @Test func accountBootstrapStateMovesCompletedFreeUserToPaywall() async {
        let userId = UUID()
        let account = AccountSnapshot(
            userId: userId,
            email: "free@trybram.app",
            displayName: "Free",
            preferredUnits: "lb",
            onboardingCompletedAt: .now,
            accountTier: .free,
            subscriptionStatus: .none,
            entitlementSource: .none,
            isDeveloper: false,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: userId),
            bootstrapService: MockBootstrapService(result: AccountBootstrapResult(account: account, goalsProfile: TrainingGoalsProfile())),
            localStore: MockLocalStore()
        )

        await state.start()

        #expect(state.status == .needsPaywall)
    }

    @MainActor
    @Test func developerAccountBypassesPaywall() async {
        let userId = UUID()
        let account = AccountSnapshot(
            userId: userId,
            email: "dev@trybram.app",
            displayName: "Dev",
            preferredUnits: "lb",
            onboardingCompletedAt: .now,
            accountTier: .free,
            subscriptionStatus: .none,
            entitlementSource: .dev,
            isDeveloper: true,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: userId),
            bootstrapService: MockBootstrapService(result: AccountBootstrapResult(account: account, goalsProfile: TrainingGoalsProfile())),
            localStore: MockLocalStore()
        )

        await state.start()

        #expect(state.status == .ready)
    }

    @MainActor
    @Test func reviewDeveloperAccountShowsTestingPaywallThenBypasses() async {
        let userId = UUID()
        let account = AccountSnapshot(
            userId: userId,
            email: "review@trybram.app",
            displayName: "Review",
            preferredUnits: "lb",
            onboardingCompletedAt: .now,
            accountTier: .free,
            subscriptionStatus: .none,
            entitlementSource: .dev,
            isDeveloper: true,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: userId),
            bootstrapService: MockBootstrapService(result: AccountBootstrapResult(account: account, goalsProfile: TrainingGoalsProfile())),
            localStore: MockLocalStore()
        )

        await state.start()
        #expect(state.status == .needsPaywall)

        await state.continueToTesting()
        #expect(state.status == .ready)
        #expect(state.featureAccess.canUseStats)
    }

    @MainActor
    @Test func accountBootstrapUsesAccountScopedLocalStore() async throws {
        let userId = UUID()
        let account = AccountSnapshot(
            userId: userId,
            email: "scoped@trybram.app",
            displayName: nil,
            preferredUnits: "lb",
            onboardingCompletedAt: nil,
            accountTier: .free,
            subscriptionStatus: .none,
            entitlementSource: .none,
            isDeveloper: false,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )
        let scopedStore = MockLocalStore()
        try await scopedStore.save(OnboardingDraft(firstName: "Scoped", step: .goal))
        try await scopedStore.save(TrainingGoalsProfile(weeklyTrainingDays: 6))

        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: userId),
            bootstrapService: MockBootstrapService(result: AccountBootstrapResult(account: account, goalsProfile: TrainingGoalsProfile())),
            localStore: MockLocalStore(),
            localStoreFactory: { requestedUserId in
                #expect(requestedUserId == userId)
                return scopedStore
            }
        )

        await state.start()

        #expect(state.onboardingDraft.firstName == "Scoped")
        #expect(state.goalsProfile.weeklyTrainingDays == 6)
    }

    @MainActor
    @Test func accountBootstrapDoesNotPullRemoteWhenPendingWorkoutSyncFails() async throws {
        let userId = UUID()
        let account = AccountSnapshot(
            userId: userId,
            email: "sync@trybram.app",
            displayName: "Sync",
            preferredUnits: "lb",
            onboardingCompletedAt: .now,
            accountTier: .premium,
            subscriptionStatus: .active,
            entitlementSource: .appStore,
            isDeveloper: false,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )
        let syncService = MockWorkoutSyncService(syncError: AccountSessionError.accountServicesUnavailable)
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: userId),
            bootstrapService: MockBootstrapService(result: AccountBootstrapResult(account: account, goalsProfile: TrainingGoalsProfile())),
            localStore: MockLocalStore(),
            workoutSyncService: syncService
        )

        await state.start()

        #expect(state.status == .ready)
        #expect(await syncService.didAttemptSync)
        #expect(await !syncService.didAttemptPull)
    }

    @MainActor
    @Test func deleteAccountCallsServerClearsLocalDataAndSignsOut() async throws {
        let userId = UUID()
        let account = AccountSnapshot(
            userId: userId,
            email: "delete@trybram.app",
            displayName: "Delete",
            preferredUnits: "lb",
            onboardingCompletedAt: .now,
            accountTier: .premium,
            subscriptionStatus: .active,
            entitlementSource: .appStore,
            isDeveloper: false,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )
        let localStore = MockLocalStore()
        let deletionService = MockAccountDeletionService()
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: userId),
            bootstrapService: MockBootstrapService(result: AccountBootstrapResult(account: account, goalsProfile: TrainingGoalsProfile())),
            localStore: localStore,
            accountDeletionService: deletionService
        )

        await state.start()
        await state.deleteAccount()

        #expect(state.status == .signedOut)
        #expect(await deletionService.deletedAccessToken == "test-token")
        #expect(await localStore.didClearLocalAccountData)
    }

    @MainActor
    @Test func accountBootstrapStateSurfacesAuthErrors() async {
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: nil, error: AccountSessionError.accountServicesUnavailable),
            bootstrapService: MockBootstrapService(result: nil),
            localStore: MockLocalStore()
        )

        await state.signIn(email: "broken@trybram.app", password: "password")

        if case .failed(let message) = state.status {
            #expect(message.contains("Account services"))
        } else {
            Issue.record("Expected failed account state.")
        }
    }

    @MainActor
    @Test func signUpForExistingAccountFallsBackToSignIn() async {
        let userId = UUID()
        let account = AccountSnapshot(
            userId: userId,
            email: "existing@trybram.app",
            displayName: nil,
            preferredUnits: "lb",
            onboardingCompletedAt: nil,
            accountTier: .free,
            subscriptionStatus: .none,
            entitlementSource: .none,
            isDeveloper: false,
            founderOfferEligible: false,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: userId, signUpError: TestAuthError(message: "User already registered")),
            bootstrapService: MockBootstrapService(result: AccountBootstrapResult(account: account, goalsProfile: TrainingGoalsProfile())),
            localStore: MockLocalStore()
        )

        await state.signUp(email: "existing@trybram.app", password: "password")

        #expect(state.status == .needsOnboarding)
        #expect(state.account?.email == "existing@trybram.app")
    }

    @MainActor
    @Test func invalidCredentialsUseFriendlyResetCopy() async {
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: nil, signInError: TestAuthError(message: "Invalid login credentials")),
            bootstrapService: MockBootstrapService(result: nil),
            localStore: MockLocalStore()
        )

        await state.signIn(email: "wrong@trybram.app", password: "bad-password")

        #expect(state.status == .failed("Email or password is wrong."))
    }

    @MainActor
    @Test func passwordResetUsesBackendEmailRoute() async {
        let resetService = MockPasswordResetService()
        let state = AccountSessionState(
            authService: MockAuthService(restoredUserId: nil),
            bootstrapService: MockBootstrapService(result: nil),
            localStore: MockLocalStore(),
            passwordResetService: resetService
        )

        await state.resetPassword(email: " Lift@TryBram.App ")

        #expect(await resetService.sentEmail == "Lift@TryBram.App")
        #expect(state.status == .failed("Password reset email sent. Check your inbox for the reset link."))
    }

    @Test func emptyDailyWorkoutNoteStartsReady() {
        let note = DailyWorkoutNote()

        #expect(note.body.isEmpty)
        #expect(note.metrics.parseState == .empty)
        #expect(note.parsedSummary == nil)
    }

    @Test func heuristicInterpreterMapsStrengthCardioAndHeartRate() async {
        let note = DailyWorkoutNote(
            body: """
            Bench 185 3x8
            Bike 20 min
            avg HR 142
            """
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)

        #expect(result.metrics.totalSets == 3)
        #expect(result.metrics.estimatedVolume == 4_440)
        #expect(result.metrics.prCount == 1)
        #expect(result.metrics.cardioMinutes == 20)
        #expect(result.metrics.averageHeartRate == 142)
        #expect(result.lines.map(\.chipText).contains("PR"))
        #expect(result.lines.map(\.chipText).contains("20 min"))
        #expect(result.lines.map(\.chipText).contains("HR 142"))
    }

    @Test func heuristicInterpreterTracksDistanceOnlyCardio() async {
        let note = DailyWorkoutNote(body: "1 mile run")

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)

        #expect(result.metrics.cardioMinutes == 10)
        #expect(result.metrics.workoutDurationMinutes == 10)
        #expect(result.cardioEntries.first?.activityType == "Running")
        #expect(result.cardioEntries.first?.distance == 1)
        #expect(result.cardioEntries.first?.distanceUnit == "mi")
        #expect(result.lines.first?.chipText == "1 mi")
        #expect(result.lines.first?.cardioEntry?.activityType == "Running")
    }

    @Test func heuristicInterpreterKeepsSameDayCardioAndLiftDistinct() async {
        let note = DailyWorkoutNote(
            body: """
            Morning run
            1 mile run

            Evening lift
            Bench
            1 - 185 for 8
            2 - 185 for 8
            """
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)

        #expect(result.metrics.totalSets == 2)
        #expect(result.metrics.cardioMinutes == 10)
        #expect(result.cardioEntries.first?.sessionName == "Morning run")
        #expect(result.cardioEntries.first?.sessionIndex == 1)
    }

    @Test func exerciseMatcherNormalizesCommonAliases() {
        let matcher = DefaultExerciseMatchingService()

        #expect(matcher.normalize("Single Arm Preacher").exerciseKey == "single_arm_preacher_curl")
        #expect(matcher.normalize("SA Preacher").exerciseKey == "single_arm_preacher_curl")
        #expect(matcher.normalize("Preacher Curl").exerciseKey == "single_arm_preacher_curl")
    }

    @Test func epleyEstimateAndPRDetectionUseEstimatedOneRepMax() {
        let matcher = DefaultExerciseMatchingService()
        let exercise = matcher.normalize("Bench")
        let set = StrengthSetRecord(
            exerciseKey: exercise.exerciseKey,
            exerciseName: exercise.displayName,
            reps: 8,
            load: 185
        )
        let result = DefaultPRDetectionService().detectPR(for: exercise, sets: [set])

        #expect(Int(set.estimatedOneRepMax.rounded()) == 234)
        #expect(result.isPR)
        #expect(result.badge?.label == "PR")
    }

    @Test func blockStyleWorkoutCreatesExerciseAnchorWithoutConfidenceUIText() async {
        let note = DailyWorkoutNote(
            body: """
            Single Arm Preacher
            1 - 30 for 10
            2 - 35 for 8
            """
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)
        let headerLine = result.lines.first { $0.lineIndex == 0 }
        let prSetLine = result.lines.first { $0.lineIndex == 2 }

        #expect(headerLine?.exerciseAnchor?.exerciseKey == "single_arm_preacher_curl")
        #expect(headerLine?.badges.isEmpty == true)
        #expect(prSetLine?.badges.first?.label == "PR")
        #expect(headerLine?.detailText.contains("%") == false)
    }

    @Test func blockStyleWorkoutPutsPRBadgeOnBestSetLine() async {
        let note = DailyWorkoutNote(
            body: """
            Cable Pullover
            1 - 40 for 8
            2 - 45 for 8
            3 - 40 for 10
            """
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)
        let headerLine = result.lines.first { $0.lineIndex == 0 }
        let bestSetLine = result.lines.first { $0.lineIndex == 2 }

        #expect(headerLine?.badges.isEmpty == true)
        #expect(bestSetLine?.chipText == "PR")
        #expect(bestSetLine?.badges.first?.label == "PR")
    }

    @Test func legDayWorkoutParsesSupersetAndBodyweightSets() async {
        let note = DailyWorkoutNote(
            body: """
            May 7 Leg Day
            Weight at 7 am 192
            Warm up Banded Squats - 10, banded side to side walks 10, 135 bar 10

            Squats
            1 - 225 lbs for 8
            2 - 245 for 8
            3 - 275 for 4
            4 - 245 for 6

            RDLs barbell
            1 - 155 for 6
            2 - 155 for 7
            3 - 155 for 5

            Superset
            Leg Curls
            1 - 20 for 8
            2 - 30 for 5
            3 - 30 for 5
            Sissy Squats
            1 - BW for 8
            2 - BW for 6
            3 - BW for 6
            """
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)
        let exerciseKeys = result.lines.compactMap(\.exerciseAnchor?.exerciseKey)

        #expect(result.metrics.totalSets == 13)
        #expect(exerciseKeys.contains("back_squat"))
        #expect(exerciseKeys.contains("barbell_romanian_deadlift"))
        #expect(exerciseKeys.contains("leg_curl"))
        #expect(exerciseKeys.contains("sissy_squat"))
    }

    @Test func supersetCreatesGroupAnchorAndIndividualExerciseAnchors() async {
        let note = DailyWorkoutNote(
            body: """
            Superset
            Sissy Squats
            1 - 8
            2 - 7
            3 - 8
            4 - 8
            Reverse Nordic
            1 - 4
            2 - 5
            3 - 4
            4 - 3
            """
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)
        let group = result.lines.first { $0.lineIndex == 0 }?.exerciseAnchor
        let exerciseKeys = result.lines.compactMap(\.exerciseAnchor?.exerciseKey)

        #expect(result.metrics.totalSets == 8)
        #expect(group?.isSupersetGroup == true)
        #expect(group?.groupMembers.map(\.exerciseKey) == ["sissy_squat", "reverse_nordic"])
        #expect(exerciseKeys.contains("sissy_squat"))
        #expect(exerciseKeys.contains("reverse_nordic"))
    }

    @Test func parserLinksCurrentMissingExerciseExamples() async {
        let note = DailyWorkoutNote(
            body: """
            Calf Raises
            1 - 40

            Tricep Overhead DB
            1 - 30s for 6
            2 - 30s for 10
            3 - 30s for 10

            Single Arm Tricep Overhead DB
            1 - 30s for 7, 20s for 5
            2 - 20s for 6

            Shoulder Flies DB Standing
            1 - 30s for 10
            2 - 30s for 7

            Hanging Leg Raises
            1 - 7
            2 - 6
            3 - 5
            """
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)
        let exerciseKeys = result.lines.compactMap(\.exerciseAnchor?.exerciseKey)

        #expect(result.metrics.totalSets == 11)
        #expect(exerciseKeys.contains("calf_raise"))
        #expect(exerciseKeys.contains("dumbbell_overhead_triceps_extension"))
        #expect(exerciseKeys.contains("single_arm_dumbbell_overhead_triceps_extension"))
        #expect(exerciseKeys.contains("standing_dumbbell_lateral_raise"))
        #expect(exerciseKeys.contains("hanging_leg_raise"))
    }

    @Test func unknownExerciseHeaderStillBecomesStableAnchorWhenFollowedBySets() async {
        let note = DailyWorkoutNote(
            body: """
            Weird Keegan Press
            1 - 44 for 9
            2 - 44 for 8
            """
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)
        let anchor = result.lines.first?.exerciseAnchor

        #expect(result.metrics.totalSets == 2)
        #expect(anchor?.displayName == "Weird Keegan Press")
        #expect(anchor?.exerciseKey == "weird_keegan_press")
    }

    @Test func sqliteWorkoutStorePersistsAutosavedNote() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var note = try await store.note(for: date)
        note.body = "Bench 185 3x8"

        try await store.save(note)

        let loaded = try await store.note(for: date)
        #expect(loaded.body == "Bench 185 3x8")
        #expect(loaded.metrics.totalSets == 3)
        #expect(loaded.metrics.estimatedVolume == 4_440)
        #expect(loaded.interpretedLines.first?.chipText == "PR")
    }

    @Test func sqliteWorkoutStoreImportsSyncedRemoteWorkoutDataOnFreshInstall() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramRemoteImportTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let userId = UUID()
        let noteId = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let note = DailyWorkoutNote(
            id: noteId,
            remoteId: noteId,
            userId: userId,
            date: date,
            body: "Bench 185 3x8",
            syncState: .synced
        )

        try await store.importSyncedWorkoutData([
            WorkoutSyncPayload(
                note: note,
                metrics: WorkoutMetricSnapshot(
                    totalSets: 3,
                    hardSets: 3,
                    estimatedVolume: 4_440,
                    prCount: 1,
                    streakDays: 0,
                    cardioMinutes: 0,
                    parseState: .parsed
                ),
                strengthSets: [
                    StrengthSetRecord(
                        exerciseKey: "bench_press",
                        exerciseName: "Bench Press",
                        reps: 8,
                        load: 185,
                        unit: "lb",
                        performedAt: date
                    )
                ],
                cardioEntries: [],
                prEvents: [],
                healthDailyMetric: nil,
                healthWorkoutMatch: nil
            )
        ])

        let loaded = try await store.note(for: date)
        let stats = try await store.statsWeek(containing: date)

        #expect(loaded.body == "Bench 185 3x8")
        #expect(loaded.syncState == .synced)
        #expect(loaded.remoteId == noteId)
        #expect(loaded.metrics.totalSets == 3)
        #expect(stats.workoutDaysInPeriod == 1)
        #expect(stats.loadByDay.contains { $0.volume == 4_440 })
    }

    @Test func sqliteWorkoutImportDoesNotOverwritePendingLocalWorkoutForSameDate() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramRemoteImportLocalWinsTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let userId = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var localNote = try await store.note(for: date)
        localNote.body = "Bench 225 3x5"
        localNote.updatedAt = Date(timeIntervalSince1970: 1_800_100_000)

        try await store.save(localNote)

        let remoteNote = DailyWorkoutNote(
            id: UUID(),
            remoteId: UUID(),
            userId: userId,
            date: date,
            body: "Bench 185 3x8",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            syncState: .synced
        )
        try await store.importSyncedWorkoutData([
            WorkoutSyncPayload(
                note: remoteNote,
                metrics: .empty,
                strengthSets: [],
                cardioEntries: [],
                prEvents: []
            )
        ])

        let loaded = try await store.note(for: date)
        let pending = try await store.pendingWorkoutSyncPayloads(limit: 10)

        #expect(loaded.id == localNote.id)
        #expect(loaded.body == "Bench 225 3x5")
        #expect(loaded.syncState != .synced)
        #expect(pending.contains { $0.note.id == localNote.id })
    }

    @Test func sqliteWorkoutImportDoesNotResurrectPendingLocalDelete() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramRemoteImportDeleteWinsTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let userId = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var localNote = try await store.note(for: date)
        localNote.body = "Bench 225 3x5"

        try await store.save(localNote)
        try await store.delete(localNote)

        let remoteNote = DailyWorkoutNote(
            id: localNote.id,
            remoteId: localNote.id,
            userId: userId,
            date: date,
            body: "Bench 185 3x8",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            syncState: .synced
        )
        try await store.importSyncedWorkoutData([
            WorkoutSyncPayload(
                note: remoteNote,
                metrics: .empty,
                strengthSets: [],
                cardioEntries: [],
                prEvents: []
            )
        ])

        let pending = try await store.pendingWorkoutSyncPayloads(limit: 10)

        #expect(pending.contains { $0.note.id == localNote.id && $0.note.deletedAt != nil })
    }

    @Test func sqliteWorkoutStoreBuildsCalendarMarkersFromSavedNotes() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramCalendarTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let prDate = Date(timeIntervalSince1970: 1_800_000_000)
        let emptyDate = Date(timeIntervalSince1970: 1_800_086_400)

        var prNote = try await store.note(for: prDate)
        prNote.body = "Bench 185 3x8"
        try await store.save(prNote)

        var emptyNote = try await store.note(for: emptyDate)
        emptyNote.body = "   "
        try await store.save(emptyNote)

        let days = try await store.calendarWorkoutDays()

        #expect(days.count == 1)
        #expect(Calendar.current.isDate(days[0].date, inSameDayAs: prDate))
        #expect(days[0].hasWorkout)
        #expect(days[0].hadPR)
    }

    @Test func sqliteWorkoutStoreDoesNotCountBodyweightOnlyNotesAsWorkouts() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramBodyweightOnlyWorkoutTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var note = try await store.note(for: date)
        note.body = "190 lbs at 8 am weighed"

        try await store.save(note)

        let days = try await store.calendarWorkoutDays()
        let stats = try await store.statsWeek(containing: date)
        let profile = try await store.trainingGoalsProfile()

        #expect(days.isEmpty)
        #expect(stats.workoutDaysInPeriod == 0)
        #expect(stats.currentStreak == 0)
        #expect(stats.setVolumeByMuscle.isEmpty)
        #expect(stats.bodyweightTrend.contains { Int($0.value.rounded()) == 190 && $0.source == .note })
        #expect(profile.currentWeightValue == 190)
    }

    @Test func sqliteWorkoutStoreCountsCardioOnlyNotesAsWorkouts() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramCardioOnlyWorkoutTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var note = try await store.note(for: date)
        note.body = "1 mile run"

        try await store.save(note)

        let days = try await store.calendarWorkoutDays()
        let stats = try await store.statsWeek(containing: date)

        #expect(days.count == 1)
        #expect(days.first?.hasWorkout == true)
        #expect(stats.workoutDaysInPeriod == 1)
        #expect(stats.loadByDay.contains { ($0.durationMinutes ?? 0) > 0 || ($0.energyCalories ?? 0) > 0 })
    }

    @Test func sqliteWorkoutStoreDerivesProgressStatsFromStructuredSets() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramStatsTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let previousDate = date.addingTimeInterval(-7 * 86_400)
        var previousNote = try await store.note(for: previousDate)
        previousNote.body = "Bench 135 2x8"
        try await store.save(previousNote)

        var note = try await store.note(for: date)
        note.body = "Bench 185 3x8"
        try await store.save(note)

        let stats = try await store.statsWeek(containing: date)

        #expect(stats.loadByDay.contains { $0.volume == 4_440 })
        #expect(stats.setVolumeByMuscle.contains { $0.muscleGroup == "Chest" && $0.sets == 3 })
        #expect(stats.macroSetVolumeByMuscle.contains { $0.muscleGroup == "Chest" && $0.sets == 3 })
        #expect(stats.prCount == 1)
        #expect(stats.recentPRLabels.contains("Bench"))
        #expect(stats.priorWorkoutDaysInPeriod == 1)
        #expect(stats.setVolumeDelta == 1)
        #expect(stats.progressSignals.contains { $0.label == "PRs" && $0.value == "1" })
        #expect(stats.progressSignals.contains { $0.label == "Workouts" && $0.value == "1/4" })
        #expect(stats.progressSignals.contains { $0.label == "Chest" && $0.value == "+1 sets" })
        #expect(stats.insight?.kind == .progression)
    }

    @Test func sqliteWorkoutStoreMapsDirectCoreWorkToAbs() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramAbsStatsTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var note = try await store.note(for: date)
        note.body = """
        Cable Crunches
        1 - 80 for 12
        2 - 90 for 10
        """

        try await store.save(note)

        let stats = try await store.statsWeek(containing: date)

        #expect(stats.setVolumeByMuscle.contains { $0.muscleGroup == "Abs" && $0.sets == 2 })
        #expect(stats.loadByDay.contains { day in
            day.muscleBreakdown.contains { $0.muscleGroup == "Abs" && $0.sets == 2 }
        })
    }

    @Test func sqliteWorkoutStoreClassifiesRealisticChestDayWithoutOther() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramChestDayStatsTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var note = try await store.note(for: date)
        note.body = """
        Chest Barbell Bench
        Weighed 11 am 192.2

        Barbell Chest
        1 - 185 lbs for 8
        2 - 205 lbs for 4
        3 - 195 for 6
        4 - 185 lbs for 6

        Incline barbell chest
        1 - 155 lbs for 7
        2 - 165 lbs for 3
        3 - 135 lbs for 12

        Incline Flies
        1 - 35 lbs for 8
        2 - 35 lbs for 6
        3 - 35 lbs for 5, 30 for 3 , 20 for 3

        Tricep Pushdown
        1 - 70 for 8
        2 - 70 for 7
        3 - 70 for 4, 50 for 6

        Superset
        DB Tricep pullovers
        1 - 30 each for 8
        2 - 30 for 8
        3 - 30 for 7
        4 - 30 for 4, 20 for 4
        Tricep Dips
        1 - BW for 4
        2 - BW for 2, descending 1
        3 - BW for 1, descending 1
        4 - BW descending for 1

        Delt Raises
        1 - 30 for 6
        2 - 20 for 9
        3 - 20 for 8
        4 - 20 for 7, 10 for 6

        Cable Crunches
        1 - 70 for 8
        2 - 70 for 6
        3 - 70 for 6
        4 - 70 for 6
        """

        try await store.save(note)

        let stats = try await store.statsWeek(containing: date)
        let groups = Dictionary(uniqueKeysWithValues: stats.setVolumeByMuscle.map { ($0.muscleGroup, $0.sets) })

        #expect(groups["Chest"] == 10)
        #expect(groups["Triceps"] == 11)
        #expect(groups["Shoulders"] == 4)
        #expect(groups["Abs"] == 4)
        #expect(groups["Other"] == nil)
    }

    @Test func sqliteWorkoutStoreBreaksArmsIntoSubgroupsForProgress() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramArmSubgroupTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var note = try await store.note(for: date)
        note.body = """
        Preacher Curl
        1 - 35 for 8
        2 - 35 for 7

        Tricep Pushdown
        1 - 70 for 8
        2 - 70 for 7
        """

        try await store.save(note)
        let stats = try await store.statsWeek(containing: date)
        let groups = Dictionary(uniqueKeysWithValues: stats.setVolumeByMuscle.map { ($0.muscleGroup, $0.sets) })
        let macroGroups = Dictionary(uniqueKeysWithValues: stats.macroSetVolumeByMuscle.map { ($0.muscleGroup, $0.sets) })

        #expect(groups["Biceps"] == 2)
        #expect(groups["Triceps"] == 2)
        #expect(groups["Arms"] == nil)
        #expect(macroGroups["Arms"] == 4)
        #expect(macroGroups["Biceps"] == nil)
        #expect(macroGroups["Triceps"] == nil)
    }

    @Test func sqliteWorkoutStoreDoesNotCreateWeakInsightWithoutUsefulData() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramEmptyStatsInsightTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        let stats = try await store.statsWeek(containing: date)

        #expect(stats.prCount == 0)
        #expect(stats.workoutDaysInPeriod == 0)
        #expect(stats.setVolumeDelta == 0)
        #expect(stats.insight == nil)
    }

    @Test func sqliteWorkoutStoreIncludesBodyweightTrendAndStreakRepairs() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramProgressBodyweightTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let firstDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 4))!
        let thirdDate = firstDate.addingTimeInterval(2 * 86_400)

        try await store.save(
            TrainingGoalsProfile(
                weeklyTrainingDays: 3,
                currentWeightValue: 192,
                targetWeightValue: 185,
                currentWeightLoggedAt: thirdDate,
                currentWeightSource: .note
            )
        )

        var firstNote = try await store.note(for: firstDate)
        firstNote.body = "Bench 185 3x8"
        try await store.save(firstNote)

        var thirdNote = try await store.note(for: thirdDate)
        thirdNote.body = "Squat 225 3x5"
        try await store.save(thirdNote)

        let stats = try await store.statsWeek(containing: firstDate)

        #expect(stats.bodyweightTrend.last?.value == 192)
        #expect(stats.targetWeight == 185)
        #expect(stats.weeklyTarget == 3)
        #expect(stats.workoutDaysInPeriod == 2)
        #expect(stats.streakRepairCount == 1)
        #expect(stats.streakTitle == "Keep the week alive")
        #expect(stats.streakSubtitle == "1 more workout keeps this week on target.")
        #expect(stats.streakAwards.contains { $0.title == "Comeback Ready" && $0.isUnlocked })
    }

    @Test func sqliteWorkoutStoreAwardsGoalBasedWeeklyStreaks() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramGoalStreakAwardsTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let startDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 4))!

        try await store.save(TrainingGoalsProfile(weeklyTrainingDays: 2))

        var firstNote = try await store.note(for: startDate)
        firstNote.body = "Bench 185 3x8"
        try await store.save(firstNote)

        var secondNote = try await store.note(for: startDate.addingTimeInterval(86_400))
        secondNote.body = "Run 1 mile"
        try await store.save(secondNote)

        let stats = try await store.statsWeek(containing: startDate)

        #expect(stats.streakTitle == "On track")
        #expect(stats.streakSubtitle == "2 of 2 workouts logged. Planned rest days stay neutral.")
        #expect(stats.streakAwards.contains { $0.title == "On Track" && $0.isUnlocked })
        #expect(stats.streakAwards.contains { $0.title == "Record Spark" && $0.isUnlocked })
    }

    @Test func currentWeekOnPaceCountsAsGoalStreak() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramCurrentGoalStreakTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let calendar = Calendar.current
        let today = Date()
        let week = calendar.dateInterval(of: .weekOfYear, for: today)!
        let weeklyTarget = 4
        let elapsedDays = min(
            7,
            max((calendar.dateComponents([.day], from: week.start, to: today).day ?? 0) + 1, 1)
        )
        let requiredByToday = min(
            weeklyTarget,
            max(Int(ceil(Double(weeklyTarget) * Double(elapsedDays) / 7.0)), 1)
        )

        try await store.save(TrainingGoalsProfile(weeklyTrainingDays: weeklyTarget))

        for offset in 0..<requiredByToday {
            let date = calendar.date(byAdding: .day, value: offset, to: week.start)!
            var note = try await store.note(for: date)
            note.body = "Bench 185 3x8"
            try await store.save(note)
        }

        let stats = try await store.statsWeek(containing: today)

        #expect(stats.workoutDaysInPeriod == requiredByToday)
        #expect(stats.currentStreak >= 1)
    }

    @Test func backfilledGoalWeeksCountTowardStreakWithoutConsecutiveDays() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramBackfilledGoalStreakTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let calendar = Calendar.current
        let referenceDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 20))!
        let secondWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)!
        let firstWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: secondWeek.start)!

        try await store.save(TrainingGoalsProfile(weeklyTrainingDays: 2))

        for weekStart in [firstWeekStart, secondWeek.start] {
            for offset in [0, 2] {
                let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                var note = try await store.note(for: date)
                note.body = "Squat 225 3x5"
                try await store.save(note)
            }
        }

        let stats = try await store.statsWeek(containing: referenceDate)

        #expect(stats.workoutDaysInPeriod == 2)
        #expect(stats.currentStreak == 2)
        #expect(stats.highestStreak >= 2)
    }

    @Test func foundingLiftersWeekStateFollowsAnnouncementAndActiveDates() {
        let calendar = Calendar(identifier: .gregorian)
        let beforeAnnouncement = calendar.date(from: DateComponents(year: 2026, month: 5, day: 21))!
        let announcement = calendar.date(from: DateComponents(year: 2026, month: 5, day: 22))!
        let activeStart = calendar.date(from: DateComponents(year: 2026, month: 5, day: 23))!
        let activeEnd = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30))!
        let afterEvent = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31))!

        #expect(LaunchChallengeProgress.make(qualifyingWorkoutDays: 0, asOf: beforeAnnouncement, calendar: calendar).state == .hidden)
        #expect(LaunchChallengeProgress.make(qualifyingWorkoutDays: 0, asOf: announcement, calendar: calendar).state == .announced)
        #expect(LaunchChallengeProgress.make(qualifyingWorkoutDays: 0, asOf: activeStart, calendar: calendar).state == .active)
        #expect(LaunchChallengeProgress.make(qualifyingWorkoutDays: 3, asOf: activeEnd, calendar: calendar).state == .active)
        #expect(LaunchChallengeProgress.make(qualifyingWorkoutDays: 4, asOf: activeEnd, calendar: calendar).state == .completed)
        #expect(LaunchChallengeProgress.make(qualifyingWorkoutDays: 4, asOf: afterEvent, calendar: calendar).state == .completed)
        #expect(LaunchChallengeProgress.make(qualifyingWorkoutDays: 3, asOf: afterEvent, calendar: calendar).state == .ended)
    }

    @Test func foundingLiftersWeekCountsOnlyQualifyingWorkoutDaysInRange() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramFoundingLiftersChallengeTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let calendar = Calendar(identifier: .gregorian)
        let outsideDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 22))!
        let bodyweightOnlyDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 23))!
        let workoutDates = [
            calendar.date(from: DateComponents(year: 2026, month: 5, day: 24))!,
            calendar.date(from: DateComponents(year: 2026, month: 5, day: 26))!,
            calendar.date(from: DateComponents(year: 2026, month: 5, day: 29))!,
            calendar.date(from: DateComponents(year: 2026, month: 5, day: 30))!
        ]

        var outsideNote = try await store.note(for: outsideDate)
        outsideNote.body = "Bench 185 3x8"
        try await store.save(outsideNote)

        var bodyweightNote = try await store.note(for: bodyweightOnlyDate)
        bodyweightNote.body = "Weighed 192 lbs"
        try await store.save(bodyweightNote)

        for date in workoutDates {
            var note = try await store.note(for: date)
            note.body = "Squat 225 3x5"
            try await store.save(note)
        }

        let stats = try await store.statsWeek(containing: workoutDates[2])

        #expect(stats.launchChallenge.progressCount == 4)
        #expect(stats.launchChallenge.isEarned)
        #expect(stats.launchChallenge.progressText == "4/4 workouts")
    }

    @Test func foundingLiftersWeekDoesNotUnlockWithOutsideOrBodyweightOnlyNotes() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramFoundingLiftersLockedTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let calendar = Calendar(identifier: .gregorian)
        let entries: [(Date, String)] = [
            (calendar.date(from: DateComponents(year: 2026, month: 5, day: 22))!, "Bench 185 3x8"),
            (calendar.date(from: DateComponents(year: 2026, month: 5, day: 23))!, "Weighed 192 lbs"),
            (calendar.date(from: DateComponents(year: 2026, month: 5, day: 24))!, "Bench 185 3x8"),
            (calendar.date(from: DateComponents(year: 2026, month: 5, day: 25))!, "Run 1 mile"),
            (calendar.date(from: DateComponents(year: 2026, month: 5, day: 30))!, "Squat 225 3x5")
        ]

        for entry in entries {
            var note = try await store.note(for: entry.0)
            note.body = entry.1
            try await store.save(note)
        }

        let stats = try await store.statsWeek(containing: calendar.date(from: DateComponents(year: 2026, month: 5, day: 30))!)

        #expect(stats.launchChallenge.progressCount == 3)
        #expect(!stats.launchChallenge.isEarned)
        #expect(stats.launchChallenge.progressText == "3/4 workouts")
    }

    @Test func sqliteWorkoutStoreBuildsExerciseHistoryFromSavedSets() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramExerciseHistoryTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let firstDate = Date(timeIntervalSince1970: 1_800_000_000)
        let secondDate = firstDate.addingTimeInterval(7 * 86_400)

        var firstNote = try await store.note(for: firstDate)
        firstNote.body = "Bench 185 3x8"
        try await store.save(firstNote)

        var secondNote = try await store.note(for: secondDate)
        secondNote.body = "Bench 205 3x5"
        try await store.save(secondNote)

        let exercise = DefaultExerciseMatchingService().normalize("Bench")
        let anchor = ExerciseAnchor(
            id: UUID(),
            displayName: exercise.displayName,
            normalizedName: exercise.canonicalName,
            exerciseKey: exercise.exerciseKey,
            history: .placeholder(for: exercise)
        )

        let history = try await store.exerciseHistory(for: anchor)

        #expect(history.recentSessions.count == 2)
        #expect(history.recentSessions.first?.bestSetText == "205 x 5")
        #expect(history.bestSetText == "205 x 5")
        #expect(Int((history.estimatedOneRepMax ?? 0).rounded()) == 239)
    }

    @Test func heuristicInterpreterParsesEffortIntoStrengthSets() async {
        let note = DailyWorkoutNote(
            date: Date(timeIntervalSince1970: 1_800_000_000),
            body: """
            Bench
            1 - 185 for 8 RPE 8
            2 - 185 for 6 RIR 1
            3 - 185 for 5 to failure
            """
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)

        #expect(result.strengthSets.map(\.effort) == ["RPE 8", "RIR 1", "Failure"])
        #expect(result.metrics.hardSets == 3)
        #expect(result.lines.first?.detailText.contains("Effort:") == true)
    }

    @Test func heuristicInterpreterParsesDumbbellNaturalShorthand() async throws {
        let note = DailyWorkoutNote(
            date: Date(timeIntervalSince1970: 1_800_000_000),
            body: "incline curls 70s for 10"
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)
        let set = try #require(result.strengthSets.first)
        let line = try #require(result.lines.first)

        #expect(set.exerciseKey == "incline_dumbbell_curl")
        #expect(set.load == 70)
        #expect(set.reps == 10)
        #expect(result.metrics.totalSets == 1)
        #expect(line.segments.first?.kind == .exerciseAnchor)
        #expect(line.segments.first?.text == "incline curls")
        #expect(line.segments.contains { $0.kind == .metric && $0.text == "70 x 10" })
    }

    @Test func heuristicInterpreterParsesNaturalSingleSetStrengthLine() async throws {
        let note = DailyWorkoutNote(
            date: Date(timeIntervalSince1970: 1_800_000_000),
            body: "Leg curls 70 for 8"
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)
        let set = try #require(result.strengthSets.first)
        let line = try #require(result.lines.first)

        #expect(set.exerciseKey == "leg_curl")
        #expect(set.load == 70)
        #expect(set.reps == 8)
        #expect(result.metrics.totalSets == 1)
        #expect(line.segments.first?.kind == .exerciseAnchor)
        #expect(line.segments.first?.text == "leg curls")
    }

    @Test func heuristicInterpreterDisplaysExplicitBodyweightLine() async throws {
        let note = DailyWorkoutNote(
            date: Date(timeIntervalSince1970: 1_800_000_000),
            body: "Weighed 192.5 lbs"
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)
        let line = try #require(result.lines.first)

        #expect(line.kind == .health)
        #expect(line.detailTitle == "Bodyweight")
        #expect(line.chipText == "Weight")
        #expect(line.segments.contains { $0.kind == .metric && $0.text == "192.5 lb" })
        #expect(result.metrics.totalSets == 0)
    }

    @Test func heuristicInterpreterParsesJogWithDurationAndDistance() async throws {
        let note = DailyWorkoutNote(
            date: Date(timeIntervalSince1970: 1_800_000_000),
            body: "15 min jog 1 mile"
        )

        let result = await HeuristicWorkoutInterpretationService().interpret(note: note)
        let cardio = try #require(result.cardioEntries.first)

        #expect(cardio.activityType == "Running")
        #expect(cardio.durationMinutes == 15)
        #expect(cardio.distance == 1)
        #expect(cardio.distanceUnit == "mi")
        #expect(result.metrics.cardioMinutes == 15)
    }

    @Test func sqliteWorkoutStoreSurfacesEffortInExerciseHistory() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramExerciseEffortHistoryTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        var note = try await store.note(for: date)
        note.body = """
        Bench
        1 - 185 for 8 RPE 8
        2 - 185 for 6
        """
        try await store.save(note)

        let exercise = DefaultExerciseMatchingService().normalize("Bench")
        let anchor = ExerciseAnchor(
            id: UUID(),
            displayName: exercise.displayName,
            normalizedName: exercise.canonicalName,
            exerciseKey: exercise.exerciseKey,
            history: .placeholder(for: exercise)
        )
        let history = try await store.exerciseHistory(for: anchor)

        #expect(history.recentEffortText == "RPE 8")
        #expect(history.recentSessions.first?.effortText == "RPE 8")
    }

    @Test func sqliteWorkoutStoreBuildsCardioHistoryFromSavedEntries() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramCardioHistoryTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let firstDate = Date(timeIntervalSince1970: 1_800_000_000)
        let secondDate = firstDate.addingTimeInterval(7 * 86_400)

        var firstNote = try await store.note(for: firstDate)
        firstNote.body = "1 mile run"
        try await store.save(firstNote)

        var secondNote = try await store.note(for: secondDate)
        secondNote.body = "2 mile run 22 min"
        try await store.save(secondNote)

        let history = try await store.cardioHistory(for: "Running")

        #expect(history.activityType == "Running")
        #expect(history.recentSessions.count == 2)
        #expect(history.recentSessions.first?.distance == 2)
        #expect(history.recentSessions.first?.durationMinutes == 22)
        #expect(history.bestDistanceText == "2 mi")
        #expect(history.averagePaceText == "10:30/mi")
        #expect(history.recentSessions.first?.paceText == "11:00/mi")
        #expect(history.estimatedCaloriesText != "--")
    }

    @Test func sqliteWorkoutStoreBuildsPendingWorkoutSyncPayloadAndMarksSynced() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramWorkoutSyncPayloadTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var note = try await store.note(for: date)
        note.body = """
        Bench 185 3x8
        Run 1 mile 10 min
        """

        try await store.save(note)

        let payload = try #require(await store.pendingWorkoutSyncPayloads(limit: 10).first)

        #expect(payload.note.id == note.id)
        #expect(payload.note.body.contains("Bench"))
        #expect(payload.metrics?.totalSets == 3)
        #expect(payload.strengthSets.count == 3)
        #expect(payload.cardioEntries.first?.activityType == "Running")

        let remoteId = UUID()
        let userId = UUID()
        try await store.markWorkoutSynced(localNoteId: note.id, remoteId: remoteId, userId: userId)

        let remainingPayloads = try await store.pendingWorkoutSyncPayloads(limit: 10)
        let syncedNote = try await store.note(for: date)

        #expect(remainingPayloads.isEmpty)
        #expect(syncedNote.remoteId == remoteId)
        #expect(syncedNote.userId == userId)
        #expect(syncedNote.syncState == .synced)
    }

    @Test func exerciseSuggestionUsesUpwardTrendForConcreteTarget() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sessions = [
            ExerciseHistorySession(
                id: UUID(),
                date: now,
                bestSetText: "205 x 5",
                estimatedOneRepMax: 239,
                volume: 3_075
            ),
            ExerciseHistorySession(
                id: UUID(),
                date: now.addingTimeInterval(-7 * 86_400),
                bestSetText: "185 x 5",
                estimatedOneRepMax: 216,
                volume: 2_775
            )
        ]

        let suggestion = LocalSuggestionEngine.exerciseSuggestion(
            exerciseKey: "barbell_bench_press",
            sessions: sessions,
            goals: TrainingGoalsProfile(primaryGoal: .stronger)
        )

        #expect(suggestion.text.contains("small load jump") || suggestion.text.contains("add one rep"))
        #expect(suggestion.target == "210 x 4-5")
        #expect(suggestion.evidence.contains("upward_trend"))
    }

    @Test func exerciseSuggestionHandlesBodyweightProgression() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sessions = [
            ExerciseHistorySession(
                id: UUID(),
                date: now,
                bestSetText: "BW x 8",
                estimatedOneRepMax: 0,
                volume: 0
            )
        ]

        let suggestion = LocalSuggestionEngine.exerciseSuggestion(
            exerciseKey: "sissy_squat",
            sessions: sessions
        )

        #expect(suggestion.target == "9 clean reps")
        #expect(suggestion.evidence.contains("thin_history"))
    }

    @Test func suggestionDraftsAreDisabledForCardsOnlyHomeSuggestions() {
        let note = DailyWorkoutNote(
            body: "Leg Day\nI feel tired today\nSquats\n1 - 225 for 8\n2 - 245 for 6",
            metrics: WorkoutMetricSnapshot(
                totalSets: 2,
                estimatedVolume: 3_270,
                prCount: 0,
                streakDays: 0,
                parseState: .parsed
            )
        )

        let draft = LocalSuggestionEngine.draft(
            for: note,
            goals: TrainingGoalsProfile(primaryGoal: .buildMuscle)
        )

        #expect(draft == nil)
    }

    @Test func suggestionContextBuilderExcludesRawNoteTextAndIncludesStructuredContext() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramSuggestionContextTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let firstDate = Date(timeIntervalSince1970: 1_800_000_000)
        let secondDate = firstDate.addingTimeInterval(7 * 86_400)

        var firstNote = try await store.note(for: firstDate)
        firstNote.body = "Bench 185 3x8"
        try await store.save(firstNote)

        var secondNote = try await store.note(for: secondDate)
        secondNote.body = "I feel strong today\nBench 205 3x5\n1 mile run"
        let result = await HeuristicWorkoutInterpretationService().interpret(note: secondNote)
        let context = await SuggestionContextBuilder.build(
            installId: "install-test-123",
            note: secondNote,
            result: result,
            goals: TrainingGoalsProfile(primaryGoal: .stronger, weeklyTrainingDays: 4),
            store: store
        )

        #expect(context.installId == "install-test-123")
        #expect(context.metrics.totalSets == 3)
        #expect(context.cardioSummaries.first?.activityType == "Running")
        #expect(context.currentMuscleSets.contains { $0.muscleGroup == "Chest" && $0.sets == 3 })
        #expect(context.exerciseSummaries.first?.exerciseKey == "bench_press")
        #expect(context.readinessHint == "high")
        #expect(context.sessionKind == "mixed")
        #expect(String(describing: context).contains("I feel strong today") == false)
    }

    @Test func dailySuggestionUsesExerciseHistoryBeforeGenericVolumeAdvice() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sessions = [
            ExerciseHistorySession(id: UUID(), date: now, bestSetText: "205 x 5", estimatedOneRepMax: 239, volume: 3_075),
            ExerciseHistorySession(id: UUID(), date: now.addingTimeInterval(-7 * 86_400), bestSetText: "185 x 5", estimatedOneRepMax: 216, volume: 2_775)
        ]
        let exerciseSuggestion = LocalSuggestionEngine.exerciseSuggestion(
            exerciseKey: "barbell_bench_press",
            sessions: sessions,
            goals: TrainingGoalsProfile(primaryGoal: .stronger)
        )
        let context = WorkoutSuggestionRequestContext(
            installId: "install-test-123",
            metrics: WorkoutMetricSnapshot(totalSets: 14, estimatedVolume: 12_000, prCount: 0, streakDays: 0, parseState: .parsed),
            goals: TrainingGoalsProfile(primaryGoal: .stronger),
            currentMuscleSets: [MuscleSetMetric(muscleGroup: "Chest", sets: 14, colorRole: .chest)],
            currentExerciseSetCounts: ["barbell_bench_press": 3],
            currentExerciseEffortBuckets: [:],
            exerciseSummaries: [
                ExerciseHistorySummary(
                    id: UUID(),
                    exerciseKey: "barbell_bench_press",
                    displayName: "Barbell Bench Press",
                    estimatedOneRepMax: 239,
                    bestSetText: "205 x 5",
                    recentDates: sessions.map(\.date),
                    recentSessions: sessions,
                    recommendation: "Repeat the last clean setup.",
                    primarySuggestion: exerciseSuggestion
                )
            ],
            cardioSummaries: [],
            workoutPattern: nil,
            activeExerciseKey: nil,
            activeExerciseSetCount: 0,
            activeExerciseLatestEffort: nil,
            readinessHint: nil,
            equipmentHint: nil,
            constraintHint: nil,
            cardioIntent: nil,
            sessionKind: "strength",
            recentFeedbackSummary: [:]
        )

        let suggestion = LocalSuggestionEngine.dailySuggestion(context: context)

        #expect(suggestion?.kind == .progression)
        #expect(suggestion?.text.contains("Barbell Bench Press") == true)
        #expect(suggestion?.text.contains("210 x 4-5") == true)
        #expect(suggestion?.text.contains("Volume is high") == false)
    }

    @Test func dailySuggestionNamesHighVolumeMuscleGroup() {
        let context = WorkoutSuggestionRequestContext(
            installId: "install-test-123",
            metrics: WorkoutMetricSnapshot(totalSets: 12, estimatedVolume: 8_000, prCount: 0, streakDays: 0, parseState: .parsed),
            goals: TrainingGoalsProfile(primaryGoal: .buildMuscle),
            currentMuscleSets: [MuscleSetMetric(muscleGroup: "Chest", sets: 10, colorRole: .chest)],
            currentExerciseSetCounts: [:],
            currentExerciseEffortBuckets: [:],
            exerciseSummaries: [],
            cardioSummaries: [],
            workoutPattern: nil,
            activeExerciseKey: nil,
            activeExerciseSetCount: 0,
            activeExerciseLatestEffort: nil,
            readinessHint: nil,
            equipmentHint: nil,
            constraintHint: nil,
            cardioIntent: nil,
            sessionKind: "strength",
            recentFeedbackSummary: [:]
        )

        let suggestion = LocalSuggestionEngine.dailySuggestion(context: context)

        #expect(suggestion?.kind == .balance)
        #expect(suggestion?.text.contains("Chest") == true)
        #expect(suggestion?.text.contains("10 sets") == true)
    }

    @Test func suggestionFeedbackPayloadDoesNotNeedRawNoteText() {
        let feedback = SuggestionFeedback(
            installId: "install-test-123",
            suggestionId: UUID(),
            suggestionType: "draft",
            action: .thumbsDown,
            source: .local,
            coarseContext: ["readiness": "low", "setBucket": "moderate"]
        )

        #expect(feedback.coarseContext["noteText"] == nil)
        #expect(feedback.coarseContext["readiness"] == "low")
    }

    @Test func coachFeedbackIconsFillOnlySelectedThumb() {
        #expect(SuggestionFeedbackAction.thumbsUp.coachFeedbackSystemImage(isSelected: false) == "hand.thumbsup")
        #expect(SuggestionFeedbackAction.thumbsUp.coachFeedbackSystemImage(isSelected: true) == "hand.thumbsup.fill")
        #expect(SuggestionFeedbackAction.thumbsDown.coachFeedbackSystemImage(isSelected: false) == "hand.thumbsdown")
        #expect(SuggestionFeedbackAction.thumbsDown.coachFeedbackSystemImage(isSelected: true) == "hand.thumbsdown.fill")
    }

    @Test func coachCardsIgnoreIncompleteSetInput() {
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 0, estimatedVolume: 0, prCount: 0, streakDays: 0, parseState: .interpreting),
            exerciseSummaries: []
        )

        let cards = WorkoutCoachCardEngine.cards(context: context, interpretedLines: [], phase: .typing)

        #expect(cards.isEmpty)
    }

    @Test func coachCardsShowActiveExerciseProgressionInMainNotes() {
        let summary = coachExerciseSummary(
            exerciseKey: "bench_press",
            displayName: "Bench Press",
            sessions: [
                coachSession(date: .now, bestSetText: "205 x 5", estimatedOneRepMax: 239, volume: 3_075),
                coachSession(date: .now.addingTimeInterval(-86_400 * 7), bestSetText: "185 x 5", estimatedOneRepMax: 216, volume: 2_775)
            ],
            suggestion: ExerciseSuggestion(
                exerciseKey: "bench_press",
                title: "Progress",
                text: "If the top set moves well, make a small load jump or add one rep.",
                target: "210 x 4-5",
                evidence: ["upward_trend"]
            )
        )
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 3, estimatedVolume: 3_075, prCount: 0, streakDays: 0, parseState: .parsed),
            exerciseSummaries: [summary],
            activeExerciseKey: "bench_press",
            activeExerciseSetCount: 2
        )

        let cards = WorkoutCoachCardEngine.cards(
            context: context,
            interpretedLines: [coachAnchorLine(lineIndex: 0, exerciseKey: "bench_press", displayName: "Bench Press")],
            activeLineIndex: 1,
            phase: .typing
        )

        #expect(cards.count == 1)
        #expect(cards.first?.affectedExerciseKey == "bench_press")
        #expect(cards.first?.title == "Next set")
    }

    @Test func coachCardsDoNotShowWorkoutTargetFromSameSessionMuscleCount() {
        let summary = coachExerciseSummary(
            exerciseKey: "bench_press",
            displayName: "Bench Press",
            sessions: [
                coachSession(date: .now.addingTimeInterval(-86_400 * 5), bestSetText: "205 x 5", estimatedOneRepMax: 239, volume: 3_075)
            ],
            suggestion: ExerciseSuggestion(
                exerciseKey: "bench_press",
                title: "Progress",
                text: "If the top set moves well, make a small load jump or add one rep.",
                target: "210 x 4-5",
                evidence: ["saved_history"]
            )
        )
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 5, estimatedVolume: 5_000, prCount: 0, streakDays: 0, parseState: .parsed),
            currentMuscleSets: [MuscleSetMetric(muscleGroup: "Chest", sets: 5, colorRole: .chest)],
            exerciseSummaries: [summary]
        )

        let cards = WorkoutCoachCardEngine.cards(context: context, interpretedLines: [], phase: .typing)

        #expect(cards.isEmpty)
        #expect(cards.contains { $0.text.contains("Most work is chest") } == false)
    }

    @Test func coachSplitPatternRequiresHighConfidenceHistory() {
        let metrics = WorkoutMetricSnapshot(totalSets: 0, estimatedVolume: 0, prCount: 0, streakDays: 0, parseState: .parsed)
        let weakContext = coachCardContext(
            metrics: metrics,
            workoutPattern: WorkoutPatternSummary(
                label: "Biceps pattern",
                confidence: .low,
                workoutCount: 2,
                matchedMuscleGroup: "Biceps",
                matchedExerciseKeys: ["dumbbell_curls"],
                evidence: ["pattern_low"]
            )
        )
        let highContext = coachCardContext(
            metrics: metrics,
            workoutPattern: WorkoutPatternSummary(
                label: "Back pattern",
                confidence: .high,
                workoutCount: 5,
                matchedMuscleGroup: "Back",
                matchedExerciseKeys: ["lat_pulldown", "row"],
                evidence: ["pattern_high"]
            )
        )

        let weakCards = WorkoutCoachCardEngine.cards(context: weakContext, interpretedLines: [], phase: .typing)
        let highCards = WorkoutCoachCardEngine.cards(context: highContext, interpretedLines: [], phase: .typing)

        #expect(weakCards.isEmpty)
        #expect(highCards.first?.title == "Back pattern")
        #expect(highCards.first?.text.localizedCaseInsensitiveContains("back") == true)
    }

    @Test func coachExerciseProgressionDisappearsAfterMovingToNextExercise() {
        let dumbbellSummary = coachExerciseSummary(
            exerciseKey: "dumbbell_curls",
            displayName: "Dumbbell curls",
            sessions: [
                coachSession(date: .now, bestSetText: "35 x 7", estimatedOneRepMax: 43, volume: 700),
                coachSession(date: .now.addingTimeInterval(-86_400 * 7), bestSetText: "30 x 8", estimatedOneRepMax: 38, volume: 600)
            ],
            suggestion: ExerciseSuggestion(
                exerciseKey: "dumbbell_curls",
                text: "Keep the same load and try to match or add one rep before pushing weight again.",
                target: "35 x 8",
                evidence: ["saved_history"]
            )
        )
        let hammerSummary = coachExerciseSummary(
            exerciseKey: "hammer_curls",
            displayName: "Hammer curls",
            sessions: [
                coachSession(date: .now, bestSetText: "20 x 10", estimatedOneRepMax: 27, volume: 200)
            ],
            suggestion: ExerciseSuggestion(
                exerciseKey: "hammer_curls",
                text: "Build a little more history before chasing progression.",
                target: "20 x 11",
                evidence: ["thin_history"]
            )
        )
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 5, estimatedVolume: 900, prCount: 0, streakDays: 0, parseState: .parsed),
            exerciseSummaries: [dumbbellSummary, hammerSummary],
            currentExerciseSetCounts: ["dumbbell_curls": 4, "hammer_curls": 1],
            activeExerciseKey: "hammer_curls",
            activeExerciseSetCount: 1
        )
        let lines = [
            coachAnchorLine(lineIndex: 0, exerciseKey: "dumbbell_curls", displayName: "Dumbbell curls"),
            coachAnchorLine(lineIndex: 6, exerciseKey: "hammer_curls", displayName: "Hammer curls")
        ]

        let cards = WorkoutCoachCardEngine.cards(
            context: context,
            interpretedLines: lines,
            activeLineIndex: 7,
            phase: .typing
        )

        #expect(cards.contains { $0.affectedExerciseKey == "dumbbell_curls" } == false)
        #expect(cards.first?.affectedExerciseKey == "hammer_curls")
    }

    @Test func coachExerciseProgressionCanSuggestMovingOnAfterThreeCompletedSets() {
        let summary = coachExerciseSummary(
            exerciseKey: "dumbbell_curls",
            displayName: "Dumbbell curls",
            sessions: [
                coachSession(date: .now, bestSetText: "35 x 7", estimatedOneRepMax: 43, volume: 700),
                coachSession(date: .now.addingTimeInterval(-86_400 * 7), bestSetText: "30 x 8", estimatedOneRepMax: 38, volume: 600)
            ],
            suggestion: ExerciseSuggestion(
                exerciseKey: "dumbbell_curls",
                text: "Keep the same load and try to match or add one rep before pushing weight again.",
                target: "35 x 8",
                evidence: ["saved_history"]
            )
        )
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 3, estimatedVolume: 700, prCount: 0, streakDays: 0, parseState: .parsed),
            exerciseSummaries: [summary],
            currentExerciseSetCounts: ["dumbbell_curls": 3],
            activeExerciseKey: "dumbbell_curls",
            activeExerciseSetCount: 3
        )

        let cards = WorkoutCoachCardEngine.cards(
            context: context,
            interpretedLines: [coachAnchorLine(lineIndex: 0, exerciseKey: "dumbbell_curls", displayName: "Dumbbell curls")],
            activeLineIndex: 3,
            phase: .typing
        )

        #expect(cards.first?.title == "Move on?")
        #expect(cards.first?.affectedExerciseKey == "dumbbell_curls")
    }

    @Test func coachExerciseSpecificEffortAdviceUsesCurrentContextInMainNotes() {
        let summary = coachExerciseSummary(
            exerciseKey: "bench_press",
            displayName: "Bench Press",
            sessions: [
                coachSession(date: .now, bestSetText: "205 x 5", estimatedOneRepMax: 239, volume: 3_075, effortText: "Failure"),
                coachSession(date: .now.addingTimeInterval(-86_400 * 7), bestSetText: "185 x 5", estimatedOneRepMax: 216, volume: 2_775)
            ],
            suggestion: ExerciseSuggestion(
                exerciseKey: "bench_press",
                title: "Progress",
                text: "If the top set moves well, make a small load jump or add one rep.",
                target: "210 x 4-5",
                evidence: ["upward_trend"]
            )
        )
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 3, estimatedVolume: 3_075, prCount: 0, streakDays: 0, parseState: .parsed),
            exerciseSummaries: [summary],
            activeExerciseKey: "bench_press",
            activeExerciseSetCount: 1,
            activeExerciseLatestEffort: "max"
        )

        let cards = WorkoutCoachCardEngine.cards(
            context: context,
            interpretedLines: [coachAnchorLine(lineIndex: 0, exerciseKey: "bench_press", displayName: "Bench Press")],
            activeLineIndex: 1,
            phase: .typing
        )

        #expect(cards.first?.text.localizedCaseInsensitiveContains("near max") == true)
    }

    @Test func coachPRCardsAppearInMainNotesWhenMeaningful() {
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 3, estimatedVolume: 3_075, prCount: 1, streakDays: 0, parseState: .parsed),
            goal: .stronger,
            exerciseSummaries: [
                coachExerciseSummary(
                    exerciseKey: "bench_press",
                    displayName: "Bench Press",
                    sessions: [
                        coachSession(date: .now, bestSetText: "205 x 5", estimatedOneRepMax: 239, volume: 3_075),
                        coachSession(date: .now.addingTimeInterval(-86_400 * 7), bestSetText: "185 x 5", estimatedOneRepMax: 216, volume: 2_775)
                    ]
                )
            ]
        )

        let cards = WorkoutCoachCardEngine.cards(
            context: context,
            interpretedLines: [coachPRLine(exerciseKey: "bench_press", displayName: "Bench Press")],
            phase: .saved
        )

        #expect(cards.first?.kind == .progression)
        #expect(cards.first?.title == "Record")
    }

    @Test func coachFirstRecordedExerciseBaselineAppearsInMainNotes() {
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 3, estimatedVolume: 2_000, prCount: 1, streakDays: 0, parseState: .parsed),
            exerciseSummaries: [
                coachExerciseSummary(
                    exerciseKey: "front_squat",
                    displayName: "Front Squat",
                    sessions: [
                        coachSession(date: .now, bestSetText: "135 x 5", estimatedOneRepMax: 158, volume: 2_025)
                    ]
                )
            ]
        )

        let cards = WorkoutCoachCardEngine.cards(
            context: context,
            interpretedLines: [coachPRLine(exerciseKey: "front_squat", displayName: "Front Squat")],
            phase: .saved
        )

        #expect(cards.first?.kind == .baseline)
    }

    @Test func coachGoalSpecificPRAdviceAppearsInMainNotes() {
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 3, estimatedVolume: 3_075, prCount: 1, streakDays: 0, parseState: .parsed),
            goal: .leaner,
            exerciseSummaries: [
                coachExerciseSummary(
                    exerciseKey: "bench_press",
                    displayName: "Bench Press",
                    sessions: [
                        coachSession(date: .now, bestSetText: "205 x 5", estimatedOneRepMax: 239, volume: 3_075),
                        coachSession(date: .now.addingTimeInterval(-86_400 * 7), bestSetText: "185 x 5", estimatedOneRepMax: 216, volume: 2_775)
                    ]
                )
            ]
        )

        let cards = WorkoutCoachCardEngine.cards(
            context: context,
            interpretedLines: [coachPRLine(exerciseKey: "bench_press", displayName: "Bench Press")],
            phase: .saved
        )

        #expect(cards.first?.text.contains("match it cleanly") == true)
    }

    @Test func coachLowReadinessPrioritizesRecovery() {
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 8, estimatedVolume: 5_000, prCount: 1, streakDays: 0, parseState: .parsed),
            readiness: "low",
            currentMuscleSets: [MuscleSetMetric(muscleGroup: "Legs", sets: 8, colorRole: .legs)]
        )

        let cards = WorkoutCoachCardEngine.cards(
            context: context,
            interpretedLines: [coachPRLine(exerciseKey: "squat", displayName: "Squat")],
            phase: .saved
        )

        #expect(cards.first?.kind == .recovery)
        #expect(cards.first?.text.contains("Legs") == true)
    }

    @Test func coachCardCapsRespectTypingAndWrapUpPhases() {
        let context = coachCardContext(
            metrics: WorkoutMetricSnapshot(totalSets: 12, estimatedVolume: 8_000, prCount: 1, streakDays: 0, cardioMinutes: 12, parseState: .parsed),
            currentMuscleSets: [MuscleSetMetric(muscleGroup: "Chest", sets: 10, colorRole: .chest)],
            exerciseSummaries: [
                coachExerciseSummary(
                    exerciseKey: "bench_press",
                    displayName: "Bench Press",
                    sessions: [
                        coachSession(date: .now, bestSetText: "205 x 5", estimatedOneRepMax: 239, volume: 3_075),
                        coachSession(date: .now.addingTimeInterval(-86_400 * 7), bestSetText: "185 x 5", estimatedOneRepMax: 216, volume: 2_775)
                    ]
                )
            ],
            cardioSummaries: [CardioHistorySummary(activityType: "Running", recentSessions: [], recommendation: "Repeat the easy mile and keep it smooth.")]
        )

        let typing = WorkoutCoachCardEngine.cards(
            context: context,
            interpretedLines: [coachPRLine(exerciseKey: "bench_press", displayName: "Bench Press")],
            phase: .typing
        )
        let wrapUp = WorkoutCoachCardEngine.cards(
            context: context,
            interpretedLines: [coachPRLine(exerciseKey: "bench_press", displayName: "Bench Press")],
            phase: .wrapUp
        )

        #expect(typing.count <= 1)
        #expect(wrapUp.count <= 1)
    }

    @Test func coachCardDisplayPolicyQueuesBeforeMinimumReadableTime() {
        let card = WorkoutCoachCard(
            kind: .balance,
            text: "Keep one main movement and limit accessories.",
            priority: 80,
            minimumVisibleSeconds: 8
        )
        let shownAt = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 1_004)

        let remaining = WorkoutCoachCardDisplayPolicy.remainingVisibleTime(current: card, shownAt: shownAt, now: now)

        #expect(remaining == 4)
    }

    @Test func sqliteWorkoutStoreAwardsPRsAgainstAllTimeExerciseHistory() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramAllTimePRTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let firstDate = Date(timeIntervalSince1970: 1_800_000_000)
        let repeatDate = firstDate.addingTimeInterval(7 * 86_400)
        let prDate = firstDate.addingTimeInterval(14 * 86_400)

        var firstNote = try await store.note(for: firstDate)
        firstNote.body = "Bench 185 3x8"
        try await store.save(firstNote)
        let firstBeforeLaterWorkouts = try await store.note(for: firstDate)

        var repeatNote = try await store.note(for: repeatDate)
        repeatNote.body = "Bench 185 3x8"
        try await store.save(repeatNote)

        var prNote = try await store.note(for: prDate)
        prNote.body = "Bench 205 3x5"
        try await store.save(prNote)

        let loadedFirst = try await store.note(for: firstDate)
        let loadedRepeat = try await store.note(for: repeatDate)
        let loadedPR = try await store.note(for: prDate)

        #expect(firstBeforeLaterWorkouts.metrics.prCount == 1)
        #expect(loadedFirst.metrics.prCount == 0)
        #expect(!loadedFirst.interpretedLines.contains { $0.chipText == "PR" })
        #expect(loadedRepeat.metrics.prCount == 0)
        #expect(!loadedRepeat.interpretedLines.contains { $0.chipText == "PR" })
        #expect(loadedPR.metrics.prCount == 1)
        #expect(loadedPR.interpretedLines.contains { $0.chipText == "PR" })
    }

    @Test func sqliteWorkoutStorePersistsTrainingGoalsProfile() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramGoalsTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let profile = TrainingGoalsProfile(
            primaryGoal: .betterCardio,
            weeklyTrainingDays: 5,
            sessionLengthMinutes: 45,
            trainingStyles: [.gym, .running],
            equipment: [.fullGym, .cardioEquipment],
            heightValue: 72,
            currentWeightValue: 192.5,
            targetWeightValue: 185,
            sex: .male,
            preferredUnits: .imperial,
            estimatedDailyCalories: 2_750
        )

        try await store.save(profile)
        let loaded = try await store.trainingGoalsProfile()

        #expect(loaded.primaryGoal == .betterCardio)
        #expect(loaded.weeklyTrainingDays == 5)
        #expect(loaded.sessionLengthMinutes == 45)
        #expect(loaded.trainingStyles == [.gym, .running])
        #expect(loaded.equipment == [.fullGym, .cardioEquipment])
        #expect(loaded.currentWeightValue == 192.5)
        #expect(loaded.settingsSubtitle == "Cardio, 5 days/week")
    }

    @Test func noteBodyweightUpdatesGoalsProfileWhenExplicit() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramNoteBodyweightTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var note = try await store.note(for: date)
        note.body = "body weight 192.4 lbs"

        try await store.save(note)
        let profile = try await store.trainingGoalsProfile()

        #expect(profile.currentWeightValue == 192.4)
        #expect(profile.currentWeightSource == .note)
        #expect(profile.currentWeightLoggedAt == date)

        let stats = try await store.statsWeek(containing: date)
        #expect(stats.bodyweightTrend.contains { $0.value == 192.4 && $0.source == .note })
    }

    @Test func noteBodyweightInfersStandaloneWeightNearExistingProfile() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramInferredBodyweightTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        try await store.save(TrainingGoalsProfile(currentWeightValue: 190, currentWeightLoggedAt: date.addingTimeInterval(-86_400), currentWeightSource: .manual))
        var note = try await store.note(for: date)
        note.body = "192 lb"

        try await store.save(note)
        let profile = try await store.trainingGoalsProfile()

        #expect(profile.currentWeightValue == 192)
        #expect(profile.currentWeightSource == .note)

        let stats = try await store.statsWeek(containing: date)
        #expect(stats.bodyweightTrend.contains { $0.value == 192 && $0.source == .note })
    }

    @Test func noteBodyweightDoesNotTreatExerciseLoadAsProfileWeight() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramBodyweightGuardTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        try await store.save(TrainingGoalsProfile(currentWeightValue: 190, currentWeightLoggedAt: date.addingTimeInterval(-86_400), currentWeightSource: .manual))
        var note = try await store.note(for: date)
        note.body = "Bench\n1 - 185 lbs for 8"

        try await store.save(note)
        let profile = try await store.trainingGoalsProfile()

        #expect(profile.currentWeightValue == 190)
        #expect(profile.currentWeightSource == .manual)
    }

    @Test func mixedBodyweightAndNaturalSetStoresBothSignals() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramMixedBodyweightNaturalSetTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var note = try await store.note(for: date)
        note.body = """
        Weighed 192.5 lbs
        Leg curls 70 for 8
        """

        try await store.save(note)
        let loaded = try await store.note(for: date)
        let profile = try await store.trainingGoalsProfile()

        #expect(profile.currentWeightValue == 192.5)
        #expect(loaded.metrics.totalSets == 1)
        #expect(loaded.interpretedLines.contains { $0.kind == .health && $0.detailTitle == "Bodyweight" })
        #expect(loaded.interpretedLines.contains { $0.exerciseAnchor?.exerciseKey == "leg_curl" })
    }

    @Test func healthBodyweightDoesNotOverwriteNewerManualSameDayWeight() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramBodyweightRecencyTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let dayStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let manualTime = dayStart.addingTimeInterval(18 * 60 * 60)
        try await store.save(
            TrainingGoalsProfile(
                currentWeightValue: 191.8,
                currentWeightLoggedAt: manualTime,
                currentWeightSource: .manual
            )
        )

        try await store.save(
            HealthDailyMetric(
                date: dayStart,
                bodyweightValue: 192.4,
                bodyweightUnit: "lb"
            )
        )

        let profile = try await store.trainingGoalsProfile()

        #expect(profile.currentWeightValue == 191.8)
        #expect(profile.currentWeightSource == .manual)
        #expect(profile.currentWeightLoggedAt == manualTime)
    }

    @Test func healthBodyweightBecomesCurrentWhenNewerThanProfile() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramLatestHealthBodyweightTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let oldDate = Date(timeIntervalSince1970: 1_800_000_000)
        let newerDate = oldDate.addingTimeInterval(2 * 86_400)
        try await store.save(
            TrainingGoalsProfile(
                currentWeightValue: 193,
                currentWeightLoggedAt: oldDate,
                currentWeightSource: .manual
            )
        )

        try await store.save(
            HealthDailyMetric(
                date: newerDate,
                bodyweightValue: 191.6,
                bodyweightUnit: "lb"
            )
        )

        let profile = try await store.trainingGoalsProfile()
        let stats = try await store.statsWeek(containing: newerDate)

        #expect(profile.currentWeightValue == 191.6)
        #expect(profile.currentWeightSource == .appleHealth)
        #expect(stats.bodyweightTrend.last?.value == 191.6)
        #expect(stats.bodyweightTrend.last?.source == .appleHealth)
    }

    @Test func manualBodyweightPersistsAsChartObservation() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramManualBodyweightChartTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let loggedAt = Date(timeIntervalSince1970: 1_800_000_000)

        try await store.save(
            TrainingGoalsProfile(
                currentWeightValue: 193,
                targetWeightValue: 195,
                currentWeightLoggedAt: loggedAt,
                currentWeightSource: .manual
            )
        )

        let stats = try await store.statsWeek(containing: loggedAt)

        #expect(stats.bodyweightTrend.count == 1)
        #expect(stats.bodyweightTrend.first?.value == 193)
        #expect(stats.bodyweightTrend.first?.source == .manual)
        #expect(stats.targetWeight == 195)
    }

    @Test func trainingGoalsSubtitleHandlesDefaultsAndSingularDay() {
        let defaultProfile = TrainingGoalsProfile()
        let oneDayProfile = TrainingGoalsProfile(primaryGoal: .stronger, weeklyTrainingDays: 1)

        #expect(defaultProfile.settingsSubtitle == "Build muscle, 4 days/week")
        #expect(oneDayProfile.settingsSubtitle == "Strength, 1 day/week")
    }

    @Test func healthEnergyEstimatorUsesHealthEnergyBeforeEstimates() {
        let metrics = WorkoutMetricSnapshot(
            totalSets: 10,
            estimatedVolume: 12_000,
            prCount: 0,
            streakDays: 0,
            parseState: .parsed
        )
        let health = HealthDailyMetric(
            date: .now,
            activeEnergyCalories: 420,
            averageHeartRate: 138,
            workoutDurationMinutes: 55
        )

        let result = HealthEnergyEstimator.applyingEnergy(
            to: metrics,
            goals: TrainingGoalsProfile(currentWeightValue: 200),
            dailyHealth: health
        )

        #expect(result.activeEnergyCalories == 420)
        #expect(!result.energyIsEstimated)
        #expect(result.averageHeartRate == 138)
        #expect(result.workoutDurationMinutes == 55)
    }

    @Test func healthEnergyEstimatorUsesGoalsBodyweightThenFallback() {
        let metrics = WorkoutMetricSnapshot(
            totalSets: 10,
            estimatedVolume: 12_000,
            prCount: 0,
            streakDays: 0,
            parseState: .parsed
        )

        let withWeight = HealthEnergyEstimator.estimateEnergyCalories(
            metrics: metrics,
            goals: TrainingGoalsProfile(sessionLengthMinutes: 60, currentWeightValue: 200)
        )
        let fallback = HealthEnergyEstimator.estimateEnergyCalories(
            metrics: metrics,
            goals: TrainingGoalsProfile(sessionLengthMinutes: 60, currentWeightValue: nil)
        )

        #expect(withWeight > fallback)
        #expect(fallback > 0)
    }

    @Test func healthEnergyEstimatorUsesPlausibleTrackingTimeForDuration() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let note = DailyWorkoutNote(
            body: "Bench\n1 - 185 for 8",
            createdAt: startedAt,
            updatedAt: startedAt.addingTimeInterval(42 * 60)
        )
        let metrics = WorkoutMetricSnapshot(
            totalSets: 8,
            estimatedVolume: 9_200,
            prCount: 0,
            streakDays: 0,
            parseState: .parsed
        )

        let result = HealthEnergyEstimator.applyingEnergy(
            to: metrics,
            goals: TrainingGoalsProfile(sessionLengthMinutes: 60, currentWeightValue: 190),
            dailyHealth: nil,
            note: note
        )

        #expect(result.workoutDurationMinutes == 42)
        #expect(result.energyIsEstimated)
    }

    @Test func healthEnergyEstimatorIgnoresImplausiblePasteDuration() {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let note = DailyWorkoutNote(
            body: "Bench\n1 - 185 for 8\n2 - 185 for 8\n3 - 185 for 8",
            createdAt: startedAt,
            updatedAt: startedAt.addingTimeInterval(60)
        )
        let metrics = WorkoutMetricSnapshot(
            totalSets: 3,
            estimatedVolume: 4_440,
            prCount: 0,
            streakDays: 0,
            parseState: .parsed
        )

        let result = HealthEnergyEstimator.applyingEnergy(
            to: metrics,
            goals: TrainingGoalsProfile(sessionLengthMinutes: 60),
            dailyHealth: nil,
            note: note
        )

        #expect(result.workoutDurationMinutes == 20)
    }

    @Test func healthWorkoutMatcherReturnsPlainLanguageMatchQuality() {
        let endDate = Date(timeIntervalSince1970: 1_800_000_000)
        let note = DailyWorkoutNote(
            date: endDate,
            body: "Run 3 miles 30 min",
            updatedAt: endDate.addingTimeInterval(5 * 60),
            metrics: WorkoutMetricSnapshot(
                totalSets: 0,
                estimatedVolume: 0,
                prCount: 0,
                streakDays: 0,
                cardioMinutes: 30,
                workoutDurationMinutes: 30,
                parseState: .parsed
            )
        )
        let workout = HealthWorkoutSample(
            healthWorkoutId: "health-run-1",
            activityType: "Running",
            startDate: endDate.addingTimeInterval(-30 * 60),
            endDate: endDate,
            durationMinutes: 30,
            activeEnergyCalories: 330,
            distanceValue: 3.1,
            distanceUnit: "mi"
        )

        let match = HealthWorkoutMatcher.bestMatch(for: note, workouts: [workout])

        #expect(match?.matchQuality == .strong)
        #expect(match?.matchQuality.label == "strong match")
        #expect(match?.matchQuality.label.contains("%") == false)
    }

    @Test func healthAuthorizationStateTreatsReadRequestAsRefreshable() {
        #expect(HealthAuthorizationState.notRequested.canAttemptRefresh)
        #expect(HealthAuthorizationState.requested.canAttemptRefresh)
        #expect(HealthAuthorizationState.connected.canAttemptRefresh)
        #expect(HealthAuthorizationState.connectedNoRecentData.canAttemptRefresh)
        #expect(!HealthAuthorizationState.unavailable.canAttemptRefresh)
    }

    @Test func healthAuthorizationStateSeparatesConnectedEmptyFromAccessReview() {
        #expect(HealthAuthorizationState.afterSuccessfulRefresh(hasImportedHealthData: true) == .connected)
        #expect(HealthAuthorizationState.afterSuccessfulRefresh(hasImportedHealthData: false) == .connectedNoRecentData)
        #expect(HealthAuthorizationState.requested.isConnectedLike)
        #expect(HealthAuthorizationState.connected.isConnectedLike)
        #expect(HealthAuthorizationState.connectedNoRecentData.isConnectedLike)
        #expect(!HealthAuthorizationState.accessNeedsReview.isConnectedLike)
    }

    @Test func appleHealthProgressPresentationDoesNotUseSlashWhenConnectedLike() {
        var stats = BramPreviewData.stats
        stats.loadByDay = []
        stats.bodyweightTrend = []
        stats.healthMetricsConnected = false

        for state in [HealthAuthorizationState.requested, .connected, .connectedNoRecentData] {
            let presentation = AppleHealthProgressPresentation.make(state: state, stats: stats)
            #expect(presentation.systemImage == "heart.fill")
            #expect(presentation.title == "Apple Health")
            #expect(presentation.subtitle.contains("Connected"))
            #expect(presentation.showsCharts == false)
        }
    }

    @Test func appleHealthProgressPresentationShowsChartsForHealthData() {
        var stats = BramPreviewData.stats
        stats.loadByDay = [
            DailyLoadMetric(
                weekday: "Mon",
                energyCalories: 410,
                energyIsEstimated: false,
                volume: 1200,
                durationMinutes: 50,
                averageHeartRate: 136
            )
        ]
        stats.bodyweightTrend = [
            BodyweightTrendPoint(date: .now, value: 192, source: .appleHealth)
        ]

        let presentation = AppleHealthProgressPresentation.make(state: .connected, stats: stats)

        #expect(presentation.showsCharts)
        #expect(stats.hasHealthChartData)
        #expect(stats.hasAppleHealthBodyweight)
        #expect(stats.loadByDay[0].energyUnitLabel == "Health cal")
        #expect(stats.loadByDay[0].energyAccessibilityLabel == "410 calories from Apple Health")
    }

    @Test func localHealthDataPromotesRequestedStateToConnected() {
        #expect(
            HealthAuthorizationState.afterLocalLoad(
                currentState: .requested,
                hasLocalHealthData: true
            ) == .connected
        )
        #expect(
            HealthAuthorizationState.afterLocalLoad(
                currentState: .requested,
                hasLocalHealthData: false
            ) == .requested
        )
    }

    @Test func sqliteWorkoutStorePersistsHealthMetricsAndEnergyStats() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramHealthTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var note = try await store.note(for: date)
        note.body = "Bench 185 3x8"
        try await store.save(note)

        try await store.save(
            HealthDailyMetric(
                date: date,
                activeEnergyCalories: 410,
                averageHeartRate: 136,
                workoutDurationMinutes: 50
            )
        )
        try await store.save(note)

        let loaded = try await store.note(for: date)
        let stats = try await store.statsWeek(containing: date)

        #expect(loaded.metrics.activeEnergyCalories == 410)
        #expect(loaded.metrics.energyIsEstimated == false)
        #expect(stats.loadByDay.contains { $0.energyCalories == 410 && !$0.energyIsEstimated })
        #expect(stats.healthMetricsConnected)
    }

    @Test func weeklyTargetStreakSemanticsAllowPlannedRestDays() {
        let fourDayGoal = TrainingGoalsProfile(weeklyTrainingDays: 4)
        let dailyGoal = TrainingGoalsProfile(weeklyTrainingDays: 7)

        #expect(fourDayGoal.respectsPlannedRestDays)
        #expect(!dailyGoal.respectsPlannedRestDays)
    }

    @Test func bramLogoAssetIsBundled() {
        #expect(UIImage(named: "BramLogo") != nil)
    }

    @Test func onboardingBearAssetsAreBundled() {
        #expect(UIImage(named: "BramBearAccountCreation") != nil)
        #expect(UIImage(named: "BramBearFirstName") != nil)
        #expect(UIImage(named: "BramBearGoal") != nil)
        #expect(UIImage(named: "BramBearWeeklyRhythm") != nil)
        #expect(UIImage(named: "BramBearTrainingSetup") != nil)
        #expect(UIImage(named: "BramBearBodyBaseline") != nil)
    }

    @Test func sqliteWorkoutStorePersistsOnboardingDraft() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("BramOnboardingTests-\(UUID().uuidString).sqlite")
            .path
        let store = try SQLiteWorkoutLocalStore(databasePath: path)
        let draft = OnboardingDraft(firstName: " Keegan ", step: .training)

        try await store.save(draft)
        let loaded = try await store.onboardingDraft()

        #expect(loaded.firstName == "Keegan")
        #expect(loaded.step == .training)
    }

    @Test func onboardingDraftRequiresNameOnFirstStep() {
        #expect(!OnboardingDraft(firstName: "", step: .name).canContinueFromCurrentStep)
        #expect(OnboardingDraft(firstName: "Keegan", step: .name).canContinueFromCurrentStep)
        #expect(OnboardingDraft(firstName: "", step: .goal).canContinueFromCurrentStep)
    }

    @Test func onboardingPermissionStepsAppearBeforeRecapWithoutChangingStoredRawValues() {
        #expect(OnboardingStep.recap.rawValue == 6)
        #expect(OnboardingStep.paywall.rawValue == 7)
        #expect(OnboardingStep.flowSteps.suffix(3) == [.appleHealth, .notifications, .recap])
        #expect(OnboardingStep.notePreview.nextStep == .appleHealth)
        #expect(OnboardingStep.recap.previousStep == .notifications)
    }

    private func coachCardContext(
        metrics: WorkoutMetricSnapshot,
        goal: TrainingPrimaryGoal = .stronger,
        readiness: String? = nil,
        currentMuscleSets: [MuscleSetMetric] = [],
        exerciseSummaries: [ExerciseHistorySummary] = [],
        currentExerciseSetCounts: [String: Int]? = nil,
        currentExerciseEffortBuckets: [String: String] = [:],
        cardioSummaries: [CardioHistorySummary] = [],
        workoutPattern: WorkoutPatternSummary? = nil,
        activeExerciseKey: String? = nil,
        activeExerciseSetCount: Int = 0,
        activeExerciseLatestEffort: String? = nil
    ) -> WorkoutSuggestionRequestContext {
        WorkoutSuggestionRequestContext(
            installId: "install-test-123",
            metrics: metrics,
            goals: TrainingGoalsProfile(primaryGoal: goal),
            currentMuscleSets: currentMuscleSets,
            currentExerciseSetCounts: currentExerciseSetCounts ?? Dictionary(uniqueKeysWithValues: exerciseSummaries.map { ($0.exerciseKey, 2) }),
            currentExerciseEffortBuckets: currentExerciseEffortBuckets,
            exerciseSummaries: exerciseSummaries,
            cardioSummaries: cardioSummaries,
            workoutPattern: workoutPattern,
            activeExerciseKey: activeExerciseKey,
            activeExerciseSetCount: activeExerciseSetCount,
            activeExerciseLatestEffort: activeExerciseLatestEffort,
            readinessHint: readiness,
            equipmentHint: nil,
            constraintHint: nil,
            cardioIntent: nil,
            sessionKind: metrics.cardioMinutes > 0 && metrics.totalSets > 0 ? "mixed" : "strength",
            recentFeedbackSummary: [:]
        )
    }

    private func coachAnchorLine(lineIndex: Int, exerciseKey: String, displayName: String) -> InterpretedWorkoutLine {
        let exercise = ExerciseAnchor(
            id: UUID(),
            displayName: displayName,
            normalizedName: displayName,
            exerciseKey: exerciseKey,
            history: .supersetPlaceholder(members: [])
        )
        return InterpretedWorkoutLine(
            noteId: UUID(),
            lineIndex: lineIndex,
            rawText: displayName,
            kind: .strength,
            segments: [InterpretedLineSegment(kind: .exerciseAnchor, text: displayName, exerciseKey: exerciseKey)],
            exerciseAnchor: exercise,
            chipText: "",
            detailTitle: displayName,
            detailText: "",
            confidence: 0.9
        )
    }

    private func coachExerciseSummary(
        exerciseKey: String,
        displayName: String,
        sessions: [ExerciseHistorySession],
        suggestion: ExerciseSuggestion? = nil
    ) -> ExerciseHistorySummary {
        ExerciseHistorySummary(
            id: UUID(),
            exerciseKey: exerciseKey,
            displayName: displayName,
            estimatedOneRepMax: sessions.first?.estimatedOneRepMax,
            bestSetText: sessions.first?.bestSetText,
            recentDates: sessions.map(\.date),
            recentSessions: sessions,
            recommendation: suggestion?.text ?? "Repeat the last clean setup.",
            primarySuggestion: suggestion
        )
    }

    private func coachSession(
        date: Date,
        bestSetText: String,
        estimatedOneRepMax: Double,
        volume: Int,
        effortText: String? = nil
    ) -> ExerciseHistorySession {
        ExerciseHistorySession(
            id: UUID(),
            date: date,
            bestSetText: bestSetText,
            estimatedOneRepMax: estimatedOneRepMax,
            volume: volume,
            effortText: effortText
        )
    }

    private func coachPRLine(exerciseKey: String, displayName: String) -> InterpretedWorkoutLine {
        let exercise = ExerciseAnchor(
            id: UUID(),
            displayName: displayName,
            normalizedName: displayName,
            exerciseKey: exerciseKey,
            history: .supersetPlaceholder(members: [])
        )
        return InterpretedWorkoutLine(
            noteId: UUID(),
            lineIndex: 0,
            rawText: "\(displayName) 205 x 5",
            kind: .strength,
            segments: [
                InterpretedLineSegment(kind: .exerciseAnchor, text: displayName, exerciseKey: exerciseKey),
                InterpretedLineSegment(kind: .badge, text: "PR", exerciseKey: exerciseKey)
            ],
            exerciseAnchor: exercise,
            badges: [WorkoutLineBadge(kind: .pr, label: "PR", colorRole: .violet)],
            chipText: "PR",
            detailTitle: displayName,
            detailText: "Best set",
            confidence: 0.9
        )
    }
}

private struct MockAuthService: BramAuthServicing {
    var restoredUserId: UUID?
    var error: Error?
    var signUpError: Error?
    var signInError: Error?

    func restoreSessionUserId() async throws -> UUID? {
        if let error { throw error }
        return restoredUserId
    }

    func currentAccessToken() async throws -> String? {
        if let error { throw error }
        return "test-token"
    }

    func signUp(email: String, password: String) async throws -> UUID? {
        if let signUpError { throw signUpError }
        if let error { throw error }
        return restoredUserId ?? UUID()
    }

    func signIn(email: String, password: String) async throws -> UUID {
        if let signInError { throw signInError }
        if let error { throw error }
        return restoredUserId ?? UUID()
    }

    func signInWithOAuth(_ provider: BramOAuthProvider) async throws -> UUID? {
        if let error { throw error }
        return restoredUserId ?? UUID()
    }

    func handleCallbackURL(_ url: URL) async throws -> UUID {
        if let error { throw error }
        return restoredUserId ?? UUID()
    }

    func signOut() async throws {
        if let error { throw error }
    }
}

private struct TestAuthError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

private actor MockPasswordResetService: BramPasswordResetting {
    private(set) var sentEmail: String?

    func sendResetEmail(email: String) async throws {
        sentEmail = email
    }
}

private struct MockBootstrapService: AccountBootstrapServicing {
    var result: AccountBootstrapResult?

    func bootstrap(userId: UUID) async throws -> AccountBootstrapResult {
        guard let result else { throw AccountSessionError.accountServicesUnavailable }
        return result
    }

    func saveOnboarding(firstName: String, profile: TrainingGoalsProfile, userId: UUID) async throws -> AccountBootstrapResult {
        guard var result else { throw AccountSessionError.accountServicesUnavailable }
        result.account.displayName = firstName
        result.account.onboardingCompletedAt = .now
        result.goalsProfile = profile
        return result
    }

    func saveGoalsProfile(profile: TrainingGoalsProfile, userId: UUID) async throws -> AccountBootstrapResult {
        guard var result else { throw AccountSessionError.accountServicesUnavailable }
        result.goalsProfile = profile
        return result
    }
}

private actor MockLocalStore: WorkoutLocalStore {
    var draft = OnboardingDraft()
    var profile = TrainingGoalsProfile()
    var didClearLocalAccountData = false

    func note(for date: Date) async throws -> DailyWorkoutNote { DailyWorkoutNote(date: date) }
    func trainingGoalsProfile() async throws -> TrainingGoalsProfile { profile }
    func healthDailyMetric(for date: Date) async throws -> HealthDailyMetric? { nil }
    func healthWorkoutSamples(on date: Date) async throws -> [HealthWorkoutSample] { [] }
    func healthWorkoutMatch(for noteId: UUID) async throws -> HealthWorkoutMatch? { nil }
    func calendarWorkoutDays() async throws -> [CalendarWorkoutDay] { [] }
    func statsWeek(containing date: Date) async throws -> StatsWeekSnapshot { BramPreviewData.stats }
    func stats(for period: StatsPeriod, containing date: Date) async throws -> StatsWeekSnapshot { BramPreviewData.stats }
    func exerciseHistory(for exercise: ExerciseAnchor) async throws -> ExerciseHistorySummary { exercise.history }
    func cardioHistory(for activityType: String) async throws -> CardioHistorySummary { CardioHistorySummary(activityType: activityType) }
    func workoutPatternSummary(through date: Date) async throws -> WorkoutPatternSummary? { nil }
    func save(_ note: DailyWorkoutNote) async throws {}
    func save(_ profile: TrainingGoalsProfile) async throws { self.profile = profile }
    func onboardingDraft() async throws -> OnboardingDraft { draft }
    func save(_ draft: OnboardingDraft) async throws { self.draft = draft.sanitized }
    func clearOnboardingDraft() async throws { draft = OnboardingDraft() }
    func save(_ metric: HealthDailyMetric) async throws {}
    func save(_ workouts: [HealthWorkoutSample]) async throws {}
    func save(_ match: HealthWorkoutMatch) async throws {}
    func delete(_ note: DailyWorkoutNote) async throws {}
    func pendingWorkoutSyncPayloads(limit: Int) async throws -> [WorkoutSyncPayload] { [] }
    func markWorkoutSynced(localNoteId: UUID, remoteId: UUID, userId: UUID) async throws {}
    func markWorkoutSyncFailed(localNoteId: UUID, errorMessage: String) async throws {}
    func importSyncedWorkoutData(_ payloads: [WorkoutSyncPayload]) async throws {}
    func clearLocalAccountData() async throws { didClearLocalAccountData = true }
}

private actor MockWorkoutSyncService: WorkoutSyncService {
    var syncError: Error?
    private(set) var didAttemptSync = false
    private(set) var didAttemptPull = false

    init(syncError: Error? = nil) {
        self.syncError = syncError
    }

    func syncPendingAccountData(userId: UUID) async throws {
        didAttemptSync = true
        if let syncError { throw syncError }
    }

    func pullAccountData(userId: UUID) async throws {
        didAttemptPull = true
    }
}

private actor MockAccountDeletionService: BramAccountDeleting {
    var deletedAccessToken: String?

    func deleteAccount(accessToken: String) async throws {
        deletedAccessToken = accessToken
    }
}

private struct InMemoryWorkoutNoteBodyKeyStore: WorkoutNoteBodyKeyStoring {
    var key: Data

    func keyData(userId: UUID) throws -> Data {
        key
    }
}
