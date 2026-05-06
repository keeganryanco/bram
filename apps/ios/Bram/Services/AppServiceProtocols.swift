import Foundation

protocol WorkoutNoteStore {
    func note(for date: Date) async throws -> DailyWorkoutNote
    func save(_ note: DailyWorkoutNote) async throws
}

protocol AccountStateProviding {
    func accountSnapshot() async throws -> AccountSnapshot
}

protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

protocol HealthDataProviding {
    func weeklySnapshot() async throws -> StatsWeekSnapshot
}

protocol AnimationAssetProviding {
    func mascotAssetName(for moment: MascotMoment) -> String?
}

struct AnalyticsEvent: Hashable {
    var name: String
    var properties: [String: String]
}

enum MascotMoment: Hashable {
    case idle
    case streak
    case weeklyReview
}
