import Foundation

enum HealthAuthorizationState: String, Codable, Hashable, Sendable {
    case unavailable
    case notRequested
    case requested
    case connected
    case connectedNoRecentData
    case accessNeedsReview
    case error

    var canAttemptRefresh: Bool {
        self != .unavailable
    }

    var isConnectedLike: Bool {
        switch self {
        case .requested, .connected, .connectedNoRecentData:
            true
        case .unavailable, .notRequested, .accessNeedsReview, .error:
            false
        }
    }

    static func afterSuccessfulRefresh(hasImportedHealthData: Bool) -> HealthAuthorizationState {
        hasImportedHealthData ? .connected : .connectedNoRecentData
    }

    static func afterLocalLoad(currentState: HealthAuthorizationState, hasLocalHealthData: Bool) -> HealthAuthorizationState {
        guard hasLocalHealthData else { return currentState }
        return .connected
    }
}

enum HealthWorkoutMatchQuality: String, Codable, Hashable, Sendable {
    case strong
    case possible
    case manual

    var label: String {
        switch self {
        case .strong: "strong match"
        case .possible: "possible match"
        case .manual: "manual match"
        }
    }
}

struct HealthDailyMetric: Identifiable, Codable, Hashable, Sendable {
    var id: String { Self.dayKey(for: date) }
    var date: Date
    var activeEnergyCalories: Int?
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var bodyweightValue: Double?
    var bodyweightUnit: String?
    var workoutDurationMinutes: Int?
    var source: String
    var updatedAt: Date

    init(
        date: Date,
        activeEnergyCalories: Int? = nil,
        averageHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        bodyweightValue: Double? = nil,
        bodyweightUnit: String? = nil,
        workoutDurationMinutes: Int? = nil,
        source: String = "APPLE_HEALTH",
        updatedAt: Date = .now
    ) {
        self.date = date
        self.activeEnergyCalories = activeEnergyCalories
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.bodyweightValue = bodyweightValue
        self.bodyweightUnit = bodyweightUnit
        self.workoutDurationMinutes = workoutDurationMinutes
        self.source = source
        self.updatedAt = updatedAt
    }

    private static func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 1970, components.month ?? 1, components.day ?? 1)
    }
}

struct HealthWorkoutSample: Identifiable, Codable, Hashable, Sendable {
    var id: String { healthWorkoutId }
    var healthWorkoutId: String
    var activityType: String
    var startDate: Date
    var endDate: Date
    var durationMinutes: Int
    var activeEnergyCalories: Int?
    var distanceValue: Double?
    var distanceUnit: String?
    var averageHeartRate: Int?
    var maxHeartRate: Int?

    init(
        healthWorkoutId: String,
        activityType: String,
        startDate: Date,
        endDate: Date,
        durationMinutes: Int,
        activeEnergyCalories: Int? = nil,
        distanceValue: Double? = nil,
        distanceUnit: String? = nil,
        averageHeartRate: Int? = nil,
        maxHeartRate: Int? = nil
    ) {
        self.healthWorkoutId = healthWorkoutId
        self.activityType = activityType
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = durationMinutes
        self.activeEnergyCalories = activeEnergyCalories
        self.distanceValue = distanceValue
        self.distanceUnit = distanceUnit
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
    }
}

struct HealthWorkoutMatch: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var noteId: UUID
    var noteDate: Date
    var healthWorkoutId: String
    var matchQuality: HealthWorkoutMatchQuality
    var matchedAt: Date

    init(
        id: UUID = UUID(),
        noteId: UUID,
        noteDate: Date,
        healthWorkoutId: String,
        matchQuality: HealthWorkoutMatchQuality,
        matchedAt: Date = .now
    ) {
        self.id = id
        self.noteId = noteId
        self.noteDate = noteDate
        self.healthWorkoutId = healthWorkoutId
        self.matchQuality = matchQuality
        self.matchedAt = matchedAt
    }
}
