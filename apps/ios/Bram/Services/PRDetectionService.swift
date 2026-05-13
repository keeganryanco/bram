import Foundation

struct DefaultPRDetectionService: PRDetectionService {
    private let estimatedOneRepMaxBaseline: [String: Double] = [
        "bench_press": 230,
        "single_arm_preacher_curl": 41,
        "incline_hammer_curl": 43,
        "cable_pullover": 50
    ]

    func detectPR(for exercise: NormalizedExercise, sets: [StrengthSetRecord]) -> PRDetectionResult {
        guard let bestSet = sets.max(by: { $0.estimatedOneRepMax < $1.estimatedOneRepMax }) else {
            return PRDetectionResult(isPR: false, events: [], badge: nil, bestSetId: nil)
        }

        let baseline = estimatedOneRepMaxBaseline[exercise.exerciseKey] ?? max(bestSet.estimatedOneRepMax - 1, 0)
        guard bestSet.estimatedOneRepMax > baseline else {
            return PRDetectionResult(isPR: false, events: [], badge: nil, bestSetId: nil)
        }

        let event = WorkoutPREvent(
            id: UUID(),
            noteId: UUID(),
            exerciseName: exercise.displayName,
            kind: PRKind.estimatedOneRepMax.rawValue,
            value: bestSet.estimatedOneRepMax,
            unit: bestSet.unit,
            achievedAt: bestSet.performedAt
        )

        return PRDetectionResult(
            isPR: true,
            events: [event],
            badge: WorkoutLineBadge(kind: .pr, label: "PR", colorRole: .violet),
            bestSetId: bestSet.id
        )
    }
}
