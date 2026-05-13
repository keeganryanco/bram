import Foundation
@preconcurrency import HealthKit

final class AppleHealthService: AppleHealthProviding, @unchecked Sendable {
    private let store = HKHealthStore()
    private let defaults: UserDefaults
    private let requestedAccessKey = "app.trybram.health.hasRequestedReadAccess"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func authorizationState() -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        return defaults.bool(forKey: requestedAccessKey) ? .requested : .notRequested
    }

    func requestAuthorization() async throws -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let readTypes = Set(healthReadTypes)
        try await store.requestAuthorization(toShare: [], read: readTypes)
        defaults.set(true, forKey: requestedAccessKey)
        return .requested
    }

    func workouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutSample] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let samples: [HKWorkout] = try await sampleQuery(type: .workoutType(), predicate: predicate, sortDescriptors: [sort])
        return samples.map(makeWorkoutSample)
    }

    func dailyMetrics(from startDate: Date, to endDate: Date) async throws -> [HealthDailyMetric] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        var metrics: [HealthDailyMetric] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        var cursor = calendar.startOfDay(for: startDate)
        while cursor < endDate {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            let dayStart = cursor
            let dayEnd = nextDay
            let energy = try await quantitySum(.activeEnergyBurned, unit: .kilocalorie(), from: dayStart, to: dayEnd)
            let heartRateAverage = try await quantityAverage(.heartRate, unit: heartRateUnit, from: dayStart, to: dayEnd)
            let heartRateMax = try await quantityMax(.heartRate, unit: heartRateUnit, from: dayStart, to: dayEnd)
            let bodyMass = try await latestQuantity(.bodyMass, unit: .pound(), from: dayStart, to: dayEnd)
            let dayWorkouts = try await workouts(from: dayStart, to: dayEnd)
            let duration = dayWorkouts.reduce(0) { $0 + $1.durationMinutes }
            metrics.append(
                HealthDailyMetric(
                    date: dayStart,
                    activeEnergyCalories: energy.map { Int($0.rounded()) },
                    averageHeartRate: heartRateAverage.map { Int($0.rounded()) },
                    maxHeartRate: heartRateMax.map { Int($0.rounded()) },
                    bodyweightValue: bodyMass,
                    bodyweightUnit: "lb",
                    workoutDurationMinutes: duration > 0 ? duration : nil
                )
            )
            cursor = nextDay
        }

        return metrics
    }

    func matchWorkout(note: DailyWorkoutNote, workouts: [HealthWorkoutSample]) -> HealthWorkoutMatch? {
        HealthWorkoutMatcher.bestMatch(for: note, workouts: workouts)
    }

    func refreshHealthData(for date: Date) async throws -> (dailyMetric: HealthDailyMetric?, workouts: [HealthWorkoutSample]) {
        let interval = Calendar.current.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
        async let dayWorkouts = workouts(from: interval.start, to: interval.end)
        async let dayMetrics = dailyMetrics(from: interval.start, to: interval.end)
        let metrics = try await dayMetrics
        return (metrics.first, try await dayWorkouts)
    }

    private var healthReadTypes: [HKObjectType] {
        [
            .workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .distanceCycling)
        ].compactMap { $0 }
    }

    private var heartRateUnit: HKUnit {
        HKUnit.count().unitDivided(by: .minute())
    }

    private func makeWorkoutSample(_ workout: HKWorkout) -> HealthWorkoutSample {
        HealthWorkoutSample(
            healthWorkoutId: workout.uuid.uuidString,
            activityType: label(for: workout.workoutActivityType),
            startDate: workout.startDate,
            endDate: workout.endDate,
            durationMinutes: max(Int((workout.duration / 60).rounded()), 1),
            activeEnergyCalories: workout.totalEnergyBurned.map { Int($0.doubleValue(for: .kilocalorie()).rounded()) },
            distanceValue: workout.totalDistance.map { $0.doubleValue(for: .mile()) },
            distanceUnit: workout.totalDistance == nil ? nil : "mi"
        )
    }

    private func label(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .traditionalStrengthTraining: "Strength training"
        case .functionalStrengthTraining: "Functional strength"
        case .highIntensityIntervalTraining: "HIIT"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .stairClimbing: "Stairs"
        default: "Workout"
        }
    }

    private func sampleQuery<T: HKSample>(
        type: HKSampleType,
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]? = nil,
        limit: Int = HKObjectQueryNoLimit
    ) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [T]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func quantitySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> Double? {
        try await quantityStatistic(identifier, option: .cumulativeSum, unit: unit, from: startDate, to: endDate)
    }

    private func quantityAverage(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> Double? {
        try await quantityStatistic(identifier, option: .discreteAverage, unit: unit, from: startDate, to: endDate)
    }

    private func quantityMax(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> Double? {
        try await quantityStatistic(identifier, option: .discreteMax, unit: unit, from: startDate, to: endDate)
    }

    private func quantityStatistic(
        _ identifier: HKQuantityTypeIdentifier,
        option: HKStatisticsOptions,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: option) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value: Double?
                switch option {
                case .cumulativeSum:
                    value = statistics?.sumQuantity()?.doubleValue(for: unit)
                case .discreteAverage:
                    value = statistics?.averageQuantity()?.doubleValue(for: unit)
                case .discreteMax:
                    value = statistics?.maximumQuantity()?.doubleValue(for: unit)
                default:
                    value = nil
                }
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let samples: [HKQuantitySample] = try await sampleQuery(type: type, predicate: predicate, sortDescriptors: [sort], limit: 1)
        return samples.first?.quantity.doubleValue(for: unit)
    }
}
