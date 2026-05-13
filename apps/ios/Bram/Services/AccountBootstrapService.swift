import Foundation
import Supabase

struct AccountBootstrapResult: Equatable {
    var account: AccountSnapshot
    var goalsProfile: TrainingGoalsProfile

    var needsOnboarding: Bool {
        account.onboardingCompletedAt == nil
    }
}

protocol AccountBootstrapServicing: Sendable {
    func bootstrap(userId: UUID) async throws -> AccountBootstrapResult
    func saveOnboarding(firstName: String, profile: TrainingGoalsProfile, userId: UUID) async throws -> AccountBootstrapResult
    func saveGoalsProfile(profile: TrainingGoalsProfile, userId: UUID) async throws -> AccountBootstrapResult
}

struct AccountBootstrapService: AccountBootstrapServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func bootstrap(userId: UUID) async throws -> AccountBootstrapResult {
        let account = try await fetchAccountSnapshot()
        let profile = try await fetchOrCreateTrainingProfile(userId: userId, preferredUnits: account.preferredUnits)
        return AccountBootstrapResult(account: account, goalsProfile: profile)
    }

    func saveOnboarding(firstName: String, profile: TrainingGoalsProfile, userId: UUID) async throws -> AccountBootstrapResult {
        try await saveProfile(
            profile,
            userId: userId,
            displayName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            onboardingCompletedAt: Date()
        )
        return try await bootstrap(userId: userId)
    }

    func saveGoalsProfile(profile: TrainingGoalsProfile, userId: UUID) async throws -> AccountBootstrapResult {
        try await saveProfile(profile, userId: userId, displayName: nil, onboardingCompletedAt: nil)
        return try await bootstrap(userId: userId)
    }

    private func saveProfile(
        _ profile: TrainingGoalsProfile,
        userId: UUID,
        displayName: String?,
        onboardingCompletedAt: Date?
    ) async throws {
        let completedAt = onboardingCompletedAt
        try await client
            .from("profiles")
            .update(
                TrainingGoalsSupabaseMapper.profileUpdate(
                    from: profile,
                    displayName: displayName,
                    onboardingCompletedAt: completedAt
                )
            )
            .eq("user_id", value: userId)
            .execute()

        try await client
            .from("training_profiles")
            .upsert(
                TrainingGoalsSupabaseMapper.trainingUpsert(
                    from: profile,
                    userId: userId,
                    onboardingCompletedAt: completedAt
                ),
                onConflict: "user_id"
            )
            .execute()
    }

    private func fetchAccountSnapshot() async throws -> AccountSnapshot {
        try await client
            .from("account_snapshot")
            .select()
            .limit(1)
            .single()
            .execute()
            .value
    }

    private func fetchOrCreateTrainingProfile(userId: UUID, preferredUnits: String) async throws -> TrainingGoalsProfile {
        let rows: [RemoteTrainingProfileRow] = try await client
            .from("training_profiles")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        if let row = rows.first {
            return TrainingGoalsSupabaseMapper.profile(from: row, preferredUnits: preferredUnits)
        }

        let defaultProfile = TrainingGoalsProfile(
            preferredUnits: MeasurementUnitPreferenceForAccount.weightUnit(preferredUnits)
        )
        try await client
            .from("training_profiles")
            .upsert(
                TrainingGoalsSupabaseMapper.trainingUpsert(
                    from: defaultProfile,
                    userId: userId,
                    onboardingCompletedAt: nil
                ),
                onConflict: "user_id"
            )
            .execute()
        return defaultProfile
    }
}

private enum MeasurementUnitPreferenceForAccount {
    static func weightUnit(_ value: String) -> MeasurementUnitPreference {
        value == "kg" ? .metric : .imperial
    }
}
