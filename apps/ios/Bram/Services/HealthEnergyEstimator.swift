import Foundation

enum HealthEnergyEstimator {
    static let fallbackBodyMassKg = 82.0

    static func applyingEnergy(
        to metrics: WorkoutMetricSnapshot,
        goals: TrainingGoalsProfile,
        dailyHealth: HealthDailyMetric?,
        matchedWorkout: HealthWorkoutSample? = nil,
        note: DailyWorkoutNote? = nil
    ) -> WorkoutMetricSnapshot {
        var output = metrics
        output.workoutDurationMinutes = resolvedDuration(
            metrics: metrics,
            goals: goals,
            dailyHealth: dailyHealth,
            matchedWorkout: matchedWorkout,
            note: note
        )

        if let workoutEnergy = matchedWorkout?.activeEnergyCalories {
            output.activeEnergyCalories = workoutEnergy
            output.energyIsEstimated = false
        } else if let dailyEnergy = dailyHealth?.activeEnergyCalories {
            output.activeEnergyCalories = dailyEnergy
            output.energyIsEstimated = false
        } else if metrics.totalSets > 0 || metrics.cardioMinutes > 0 {
            output.activeEnergyCalories = estimateEnergyCalories(metrics: output, goals: goals)
            output.energyIsEstimated = true
        }

        output.averageHeartRate = matchedWorkout?.averageHeartRate ?? dailyHealth?.averageHeartRate ?? output.averageHeartRate
        return output
    }

    static func estimateEnergyCalories(metrics: WorkoutMetricSnapshot, goals: TrainingGoalsProfile) -> Int {
        let minutes = estimatedDuration(metrics: metrics, goals: goals)
        let met = metrics.cardioMinutes > 0 ? 7.0 : 4.5
        let calories = met * 3.5 * bodyMassKg(from: goals) / 200 * Double(minutes)
        return max(Int(calories.rounded()), 0)
    }

    static func estimatedDuration(metrics: WorkoutMetricSnapshot, goals: TrainingGoalsProfile) -> Int {
        if let duration = metrics.workoutDurationMinutes, duration > 0 { return duration }
        if metrics.cardioMinutes > 0 { return metrics.cardioMinutes }
        if metrics.totalSets > 0 { return min(max(metrics.totalSets * 3 + 10, 20), goals.sessionLengthMinutes) }
        return goals.sessionLengthMinutes
    }

    static func resolvedDuration(
        metrics: WorkoutMetricSnapshot,
        goals: TrainingGoalsProfile,
        dailyHealth: HealthDailyMetric? = nil,
        matchedWorkout: HealthWorkoutSample? = nil,
        note: DailyWorkoutNote? = nil
    ) -> Int {
        if let duration = matchedWorkout?.durationMinutes, duration > 0 { return duration }
        if let duration = dailyHealth?.workoutDurationMinutes, duration > 0 { return duration }
        if let duration = plausibleTrackingDuration(from: note) { return duration }
        return estimatedDuration(metrics: metrics, goals: goals)
    }

    static func plausibleTrackingDuration(from note: DailyWorkoutNote?) -> Int? {
        guard let note,
              !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        let minutes = note.updatedAt.timeIntervalSince(note.createdAt) / 60
        guard minutes >= 5, minutes <= 240 else { return nil }
        return max(Int(minutes.rounded()), 1)
    }

    private static func bodyMassKg(from goals: TrainingGoalsProfile) -> Double {
        guard let weight = goals.currentWeightValue, weight > 0 else {
            return fallbackBodyMassKg
        }
        switch goals.preferredUnits {
        case .imperial:
            return weight / 2.20462
        case .metric:
            return weight
        }
    }
}

enum HealthWorkoutMatcher {
    static func bestMatch(for note: DailyWorkoutNote, workouts: [HealthWorkoutSample]) -> HealthWorkoutMatch? {
        let sameDay = workouts.filter { Calendar.current.isDate($0.startDate, inSameDayAs: note.date) }
        guard !sameDay.isEmpty else { return nil }

        let scored = sameDay.map { workout in
            (workout: workout, score: score(note: note, workout: workout))
        }
        guard let best = scored.max(by: { $0.score < $1.score }), best.score >= 35 else {
            return nil
        }

        let quality: HealthWorkoutMatchQuality = best.score >= 75 ? .strong : .possible
        return HealthWorkoutMatch(
            noteId: note.id,
            noteDate: note.date,
            healthWorkoutId: best.workout.healthWorkoutId,
            matchQuality: quality
        )
    }

    private static func score(note: DailyWorkoutNote, workout: HealthWorkoutSample) -> Int {
        var score = 35
        let updateDistance = abs(note.updatedAt.timeIntervalSince(workout.endDate)) / 60
        if updateDistance <= 45 { score += 25 }
        if updateDistance <= 15 { score += 15 }

        if let noteDuration = note.metrics.workoutDurationMinutes, noteDuration > 0 {
            let durationDelta = abs(noteDuration - workout.durationMinutes)
            if durationDelta <= 15 { score += 20 }
            if durationDelta <= 5 { score += 10 }
        }

        let lowerBody = note.body.lowercased()
        if lowerBody.contains("run"), workout.activityType.lowercased().contains("run") { score += 20 }
        if lowerBody.contains("bike") || lowerBody.contains("cycle"), workout.activityType.lowercased().contains("cycling") { score += 20 }
        if lowerBody.contains("walk"), workout.activityType.lowercased().contains("walk") { score += 15 }
        if note.metrics.cardioMinutes > 0, workout.distanceValue != nil { score += 10 }

        return min(score, 100)
    }
}
