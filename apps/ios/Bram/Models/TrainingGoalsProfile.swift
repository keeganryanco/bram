import Foundation

enum TrainingPrimaryGoal: String, Codable, CaseIterable, Identifiable {
    case stronger
    case buildMuscle
    case leaner
    case betterCardio
    case healthyRoutine
    case maintain

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stronger: "Get stronger"
        case .buildMuscle: "Build muscle"
        case .leaner: "Get leaner"
        case .betterCardio: "Better cardio"
        case .healthyRoutine: "Healthy routine"
        case .maintain: "Maintain"
        }
    }

    var shortLabel: String {
        switch self {
        case .stronger: "Strength"
        case .buildMuscle: "Build muscle"
        case .leaner: "Leaner"
        case .betterCardio: "Cardio"
        case .healthyRoutine: "Healthy routine"
        case .maintain: "Maintain"
        }
    }
}

enum TrainingStyle: String, Codable, CaseIterable, Identifiable {
    case gym
    case homeGym
    case calisthenics
    case pilates
    case running
    case biking
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gym: "Gym"
        case .homeGym: "Home gym"
        case .calisthenics: "Calisthenics"
        case .pilates: "Pilates"
        case .running: "Running"
        case .biking: "Biking"
        case .other: "Other"
        }
    }
}

enum EquipmentContext: String, Codable, CaseIterable, Identifiable {
    case fullGym
    case dumbbells
    case barbell
    case machines
    case cables
    case bands
    case bodyweight
    case cardioEquipment

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fullGym: "Full gym"
        case .dumbbells: "Dumbbells"
        case .barbell: "Barbell"
        case .machines: "Machines"
        case .cables: "Cables"
        case .bands: "Bands"
        case .bodyweight: "Bodyweight"
        case .cardioEquipment: "Cardio equipment"
        }
    }
}

enum BodySex: String, Codable, CaseIterable, Identifiable {
    case female
    case male
    case intersex
    case selfDescribe
    case preferNotToSay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .intersex: "Intersex"
        case .selfDescribe: "Self-describe"
        case .preferNotToSay: "Prefer not to say"
        }
    }
}

enum MeasurementUnitPreference: String, Codable, CaseIterable, Identifiable {
    case imperial
    case metric

    var id: String { rawValue }

    var label: String {
        switch self {
        case .imperial: "lb / ft"
        case .metric: "kg / cm"
        }
    }

    var weightUnit: String {
        switch self {
        case .imperial: "lb"
        case .metric: "kg"
        }
    }
}

enum BodyweightSource: String, Codable, Hashable {
    case manual
    case note
    case appleHealth

    var label: String {
        switch self {
        case .manual: "Manual"
        case .note: "From notes"
        case .appleHealth: "Apple Health"
        }
    }
}

struct TrainingGoalsProfile: Codable, Equatable, Hashable {
    var primaryGoal: TrainingPrimaryGoal
    var weeklyTrainingDays: Int
    var sessionLengthMinutes: Int
    var trainingStyles: Set<TrainingStyle>
    var equipment: Set<EquipmentContext>
    var heightValue: Double?
    var currentWeightValue: Double?
    var targetWeightValue: Double?
    var currentWeightLoggedAt: Date?
    var currentWeightSource: BodyweightSource?
    var sex: BodySex?
    var sexSelfDescription: String
    var preferredUnits: MeasurementUnitPreference
    var estimatedDailyCalories: Int?
    var updatedAt: Date

    init(
        primaryGoal: TrainingPrimaryGoal = .buildMuscle,
        weeklyTrainingDays: Int = 4,
        sessionLengthMinutes: Int = 60,
        trainingStyles: Set<TrainingStyle> = [.gym],
        equipment: Set<EquipmentContext> = [.fullGym],
        heightValue: Double? = nil,
        currentWeightValue: Double? = nil,
        targetWeightValue: Double? = nil,
        currentWeightLoggedAt: Date? = nil,
        currentWeightSource: BodyweightSource? = nil,
        sex: BodySex? = nil,
        sexSelfDescription: String = "",
        preferredUnits: MeasurementUnitPreference = .imperial,
        estimatedDailyCalories: Int? = nil,
        updatedAt: Date = .now
    ) {
        self.primaryGoal = primaryGoal
        self.weeklyTrainingDays = weeklyTrainingDays
        self.sessionLengthMinutes = sessionLengthMinutes
        self.trainingStyles = trainingStyles
        self.equipment = equipment
        self.heightValue = heightValue
        self.currentWeightValue = currentWeightValue
        self.targetWeightValue = targetWeightValue
        self.currentWeightLoggedAt = currentWeightLoggedAt
        self.currentWeightSource = currentWeightSource
        self.sex = sex
        self.sexSelfDescription = sexSelfDescription
        self.preferredUnits = preferredUnits
        self.estimatedDailyCalories = estimatedDailyCalories
        self.updatedAt = updatedAt
    }

    var settingsSubtitle: String {
        "\(primaryGoal.shortLabel), \(weeklyTrainingDays) \(weeklyTrainingDays == 1 ? "day" : "days")/week"
    }

    var respectsPlannedRestDays: Bool {
        weeklyTrainingDays < 7
    }

    var sanitized: TrainingGoalsProfile {
        var copy = self
        copy.weeklyTrainingDays = min(max(weeklyTrainingDays, 1), 14)
        copy.sessionLengthMinutes = min(max(sessionLengthMinutes, 10), 240)
        copy.heightValue = heightValue.flatMap { $0 > 0 ? $0 : nil }
        copy.currentWeightValue = currentWeightValue.flatMap { $0 > 0 ? $0 : nil }
        copy.targetWeightValue = targetWeightValue.flatMap { $0 > 0 ? $0 : nil }
        if copy.currentWeightValue == nil {
            copy.currentWeightLoggedAt = nil
            copy.currentWeightSource = nil
        }
        copy.estimatedDailyCalories = estimatedDailyCalories.flatMap { $0 > 0 ? $0 : nil }
        copy.sexSelfDescription = sexSelfDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.updatedAt = .now
        return copy
    }
}

struct RemoteTrainingProfileRow: Codable, Equatable {
    var userId: UUID
    var primaryGoal: String?
    var weeklyTrainingDays: Int?
    var sessionLengthMinutes: Int?
    var trainingStyles: [String]
    var availableEquipment: [String]
    var onboardingCompletedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case primaryGoal = "primary_goal"
        case weeklyTrainingDays = "weekly_training_days"
        case sessionLengthMinutes = "session_length_minutes"
        case trainingStyles = "training_styles"
        case availableEquipment = "available_equipment"
        case onboardingCompletedAt = "onboarding_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        userId: UUID,
        primaryGoal: String?,
        weeklyTrainingDays: Int?,
        sessionLengthMinutes: Int?,
        trainingStyles: [String],
        availableEquipment: [String],
        onboardingCompletedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.userId = userId
        self.primaryGoal = primaryGoal
        self.weeklyTrainingDays = weeklyTrainingDays
        self.sessionLengthMinutes = sessionLengthMinutes
        self.trainingStyles = trainingStyles
        self.availableEquipment = availableEquipment
        self.onboardingCompletedAt = onboardingCompletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        primaryGoal = try container.decodeIfPresent(String.self, forKey: .primaryGoal)
        weeklyTrainingDays = try container.decodeIfPresent(Int.self, forKey: .weeklyTrainingDays)
        sessionLengthMinutes = try container.decodeIfPresent(Int.self, forKey: .sessionLengthMinutes)
        trainingStyles = try container.decodeIfPresent([String].self, forKey: .trainingStyles) ?? []
        availableEquipment = try container.decodeIfPresent([String].self, forKey: .availableEquipment) ?? []
        onboardingCompletedAt = try container.decodeFlexibleDateIfPresent(forKey: .onboardingCompletedAt)
        createdAt = try container.decodeFlexibleDateIfPresent(forKey: .createdAt)
        updatedAt = try container.decodeFlexibleDateIfPresent(forKey: .updatedAt)
    }
}

struct RemoteTrainingProfileUpsert: Encodable, Equatable {
    var userId: UUID
    var primaryGoal: String
    var weeklyTrainingDays: Int
    var sessionLengthMinutes: Int
    var trainingStyles: [String]
    var availableEquipment: [String]
    var onboardingCompletedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case primaryGoal = "primary_goal"
        case weeklyTrainingDays = "weekly_training_days"
        case sessionLengthMinutes = "session_length_minutes"
        case trainingStyles = "training_styles"
        case availableEquipment = "available_equipment"
        case onboardingCompletedAt = "onboarding_completed_at"
    }
}

struct RemoteProfileOnboardingUpdate: Encodable, Equatable {
    var preferredUnits: String
    var bodyweightValue: Double?
    var bodyweightUnit: String?
    var sex: String?
    var sexSelfDescribe: String?
    var onboardingCompletedAt: String?
    var heightValue: Double?
    var heightUnit: String?
    var targetBodyweightValue: Double?
    var currentBodyweightLoggedAt: String?
    var currentBodyweightSource: String?
    var estimatedDailyCalories: Int?

    enum CodingKeys: String, CodingKey {
        case preferredUnits = "preferred_units"
        case bodyweightValue = "bodyweight_value"
        case bodyweightUnit = "bodyweight_unit"
        case sex
        case sexSelfDescribe = "sex_self_describe"
        case onboardingCompletedAt = "onboarding_completed_at"
        case heightValue = "height_value"
        case heightUnit = "height_unit"
        case targetBodyweightValue = "target_bodyweight_value"
        case currentBodyweightLoggedAt = "current_bodyweight_logged_at"
        case currentBodyweightSource = "current_bodyweight_source"
        case estimatedDailyCalories = "estimated_daily_calories"
    }
}

enum TrainingGoalsSupabaseMapper {
    static func profileUpdate(
        from profile: TrainingGoalsProfile,
        onboardingCompletedAt: Date?
    ) -> RemoteProfileOnboardingUpdate {
        let sanitized = profile.sanitized
        return RemoteProfileOnboardingUpdate(
            preferredUnits: sanitized.preferredUnits.weightUnit,
            bodyweightValue: sanitized.currentWeightValue,
            bodyweightUnit: sanitized.currentWeightValue == nil ? nil : sanitized.preferredUnits.weightUnit,
            sex: sanitized.sex?.databaseValue,
            sexSelfDescribe: sanitized.sex == .selfDescribe ? sanitized.sexSelfDescription : nil,
            onboardingCompletedAt: onboardingCompletedAt?.bramDatabaseTimestamp,
            heightValue: sanitized.heightValue,
            heightUnit: sanitized.heightValue == nil ? nil : sanitized.preferredUnits.heightUnit,
            targetBodyweightValue: sanitized.targetWeightValue,
            currentBodyweightLoggedAt: sanitized.currentWeightLoggedAt?.bramDatabaseTimestamp,
            currentBodyweightSource: sanitized.currentWeightSource?.rawValue,
            estimatedDailyCalories: sanitized.estimatedDailyCalories
        )
    }

    static func trainingUpsert(
        from profile: TrainingGoalsProfile,
        userId: UUID,
        onboardingCompletedAt: Date?
    ) -> RemoteTrainingProfileUpsert {
        let sanitized = profile.sanitized
        return RemoteTrainingProfileUpsert(
            userId: userId,
            primaryGoal: sanitized.primaryGoal.rawValue,
            weeklyTrainingDays: sanitized.weeklyTrainingDays,
            sessionLengthMinutes: sanitized.sessionLengthMinutes,
            trainingStyles: sanitized.trainingStyles.map(\.rawValue).sorted(),
            availableEquipment: sanitized.equipment.map(\.rawValue).sorted(),
            onboardingCompletedAt: onboardingCompletedAt?.bramDatabaseTimestamp
        )
    }

    static func profile(from row: RemoteTrainingProfileRow, preferredUnits: String) -> TrainingGoalsProfile {
        TrainingGoalsProfile(
            primaryGoal: row.primaryGoal.flatMap(TrainingPrimaryGoal.init(rawValue:)) ?? .buildMuscle,
            weeklyTrainingDays: row.weeklyTrainingDays ?? 4,
            sessionLengthMinutes: row.sessionLengthMinutes ?? 60,
            trainingStyles: Set(row.trainingStyles.compactMap(TrainingStyle.init(rawValue:))),
            equipment: Set(row.availableEquipment.compactMap(EquipmentContext.init(rawValue:))),
            preferredUnits: MeasurementUnitPreference(weightUnit: preferredUnits),
            updatedAt: row.updatedAt ?? .now
        ).sanitized
    }
}

private extension Date {
    var bramDatabaseTimestamp: String {
        ISO8601FormatStyle(includingFractionalSeconds: true).format(self)
    }
}

private extension BodySex {
    var databaseValue: String {
        switch self {
        case .female: "female"
        case .male: "male"
        case .intersex: "intersex"
        case .selfDescribe: "self_describe"
        case .preferNotToSay: "prefer_not_to_say"
        }
    }
}

private extension MeasurementUnitPreference {
    init(weightUnit: String) {
        self = weightUnit == "kg" ? .metric : .imperial
    }

    var heightUnit: String {
        switch self {
        case .imperial: "in"
        case .metric: "cm"
        }
    }
}
