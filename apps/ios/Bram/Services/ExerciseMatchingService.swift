import Foundation

struct DefaultExerciseMatchingService: ExerciseMatchingService {
    private let aliases: [String: String] = [
        "single arm preacher": "single_arm_preacher_curl",
        "sa preacher": "single_arm_preacher_curl",
        "preacher curl": "single_arm_preacher_curl",
        "single arm preacher curl": "single_arm_preacher_curl",
        "bench": "bench_press",
        "bench press": "bench_press",
        "barbell bench": "barbell_bench_press",
        "barbell bench press": "barbell_bench_press",
        "flat barbell bench": "barbell_bench_press",
        "flat barbell bench press": "barbell_bench_press",
        "chest barbell bench": "barbell_bench_press",
        "barbell chest": "barbell_bench_press",
        "barbell chest press": "barbell_bench_press",
        "chest press barbell": "barbell_bench_press",
        "flat barbell chest press": "barbell_bench_press",
        "flat chest press barbell": "barbell_bench_press",
        "chest press": "chest_press",
        "flat chest press": "chest_press",
        "incline chest press": "incline_chest_press",
        "incline dumbbell chest press": "incline_dumbbell_chest_press",
        "incline db chest press": "incline_dumbbell_chest_press",
        "incline barbell chest": "incline_barbell_press",
        "incline barbell chest press": "incline_barbell_press",
        "incline chest press barbell": "incline_barbell_press",
        "incline flies": "incline_fly",
        "incline fly": "incline_fly",
        "tricep pushdown": "triceps_pushdown",
        "triceps pushdown": "triceps_pushdown",
        "db tricep pullovers": "dumbbell_triceps_pullover",
        "dumbbell tricep pullovers": "dumbbell_triceps_pullover",
        "db triceps pullovers": "dumbbell_triceps_pullover",
        "tricep dips": "triceps_dip",
        "triceps dips": "triceps_dip",
        "delt raises": "delt_raise",
        "delt raise": "delt_raise",
        "lateral raises": "lateral_raise",
        "cable crunches": "cable_crunch",
        "cable crunch": "cable_crunch",
        "hanging leg raises": "hanging_leg_raise",
        "hanging leg raise": "hanging_leg_raise",
        "db press": "dumbbell_press",
        "incline curl": "incline_dumbbell_curl",
        "incline curls": "incline_dumbbell_curl",
        "incline hammer curl": "incline_hammer_curl",
        "cable pullover": "cable_pullover",
        "calf raise": "calf_raise",
        "calf raises": "calf_raise",
        "standing calf raise": "standing_calf_raise",
        "standing calf raises": "standing_calf_raise",
        "squat": "back_squat",
        "squats": "back_squat",
        "back squat": "back_squat",
        "rdl": "barbell_romanian_deadlift",
        "rdls": "barbell_romanian_deadlift",
        "rdls barbell": "barbell_romanian_deadlift",
        "barbell rdl": "barbell_romanian_deadlift",
        "barbell rdls": "barbell_romanian_deadlift",
        "romanian deadlift": "barbell_romanian_deadlift",
        "leg curl": "leg_curl",
        "leg curls": "leg_curl",
        "sissy squat": "sissy_squat",
        "sissy squats": "sissy_squat",
        "reverse nordic": "reverse_nordic",
        "reverse nordics": "reverse_nordic",
        "reverse nordic curl": "reverse_nordic",
        "reverse nordic curls": "reverse_nordic",
        "tricep overhead dumbbell": "dumbbell_overhead_triceps_extension",
        "triceps overhead dumbbell": "dumbbell_overhead_triceps_extension",
        "dumbbell tricep overhead": "dumbbell_overhead_triceps_extension",
        "dumbbell triceps overhead": "dumbbell_overhead_triceps_extension",
        "single arm tricep overhead dumbbell": "single_arm_dumbbell_overhead_triceps_extension",
        "single arm triceps overhead dumbbell": "single_arm_dumbbell_overhead_triceps_extension",
        "shoulder flies dumbbell standing": "standing_dumbbell_lateral_raise",
        "shoulder fly dumbbell standing": "standing_dumbbell_lateral_raise",
        "standing dumbbell shoulder flies": "standing_dumbbell_lateral_raise",
        "standing dumbbell lateral raises": "standing_dumbbell_lateral_raise"
    ]

    func normalize(_ rawName: String) -> NormalizedExercise {
        let cleaned = ExerciseIdentityResolver.cleanedName(rawName)
        let key = ExerciseIdentityResolver.canonicalKey(forCleanedName: cleaned)
            ?? aliases[cleaned]
            ?? cleaned.replacingOccurrences(of: " ", with: "_")
        let canonical = key
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")

        return NormalizedExercise(
            id: UUID(),
            displayName: rawName.trimmingCharacters(in: .whitespacesAndNewlines),
            exerciseKey: key,
            canonicalName: canonical,
            muscleGroup: muscleGroupHint(for: key)
        )
    }

    private func muscleGroupHint(for key: String) -> String? {
        if key.contains("crunch") || key.contains("ab") || key.contains("plank") || key.contains("leg_raise") { return "Abs" }
        if key.contains("tricep") || key.contains("triceps") || key.contains("curl") || key.contains("preacher") || key.contains("dip") { return "Arms" }
        if key.contains("delt") || key.contains("lateral_raise") || key.contains("shoulder") { return "Shoulders" }
        if key.contains("bench") || key.contains("chest") || key.contains("fly") || key.contains("press") { return "Chest" }
        if key.contains("pullover") || key.contains("row") || key.contains("pulldown") { return "Back" }
        if key.contains("squat") || key.contains("leg") || key.contains("deadlift") || key.contains("nordic") || key.contains("calf") { return "Legs" }
        return nil
    }
}

enum ExerciseIdentityResolver {
    static func cleanedName(_ rawName: String) -> String {
        rawName
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bdbs?\b"#, with: "dumbbell", options: .regularExpression)
            .replacingOccurrences(of: #"\bdumbbells\b"#, with: "dumbbell", options: .regularExpression)
            .replacingOccurrences(of: #"\bbb\b"#, with: "barbell", options: .regularExpression)
            .replacingOccurrences(of: #"\bsa\b"#, with: "single arm", options: .regularExpression)
            .replacingOccurrences(of: #"\btris\b"#, with: "triceps", options: .regularExpression)
            .replacingOccurrences(of: #"\btri\b"#, with: "tricep", options: .regularExpression)
            .replacingOccurrences(of: #"\bextensions?\b"#, with: "extension", options: .regularExpression)
            .replacingOccurrences(of: #"\braises?\b"#, with: "raises", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }

    static func canonicalKey(forCleanedName cleaned: String) -> String? {
        let tokens = Set(cleaned.split(separator: " ").map(String.init))
        guard tokens.contains("press") else { return nil }

        let hasChest = tokens.contains("chest")
        let hasBench = tokens.contains("bench")
        let hasIncline = tokens.contains("incline")
        let hasFlat = tokens.contains("flat")
        let hasDumbbell = tokens.contains("dumbbell")
        let hasBarbell = tokens.contains("barbell")

        if hasIncline, hasChest || hasBench || hasBarbell || hasDumbbell {
            if hasDumbbell { return "incline_dumbbell_chest_press" }
            if hasBarbell { return "incline_barbell_press" }
            return "incline_chest_press"
        }

        if hasChest || hasBench || hasFlat {
            if hasBarbell || hasBench { return "barbell_bench_press" }
            if hasDumbbell { return "dumbbell_chest_press" }
            return "chest_press"
        }

        return nil
    }

    static func dominantKey(
        for currentKey: String,
        counts: [String: Int],
        minimumCount: Int = 2,
        ratio: Double = 0.67
    ) -> String {
        let candidates: [String]
        switch currentKey {
        case "incline_chest_press":
            candidates = ["incline_dumbbell_chest_press", "incline_barbell_press"]
        case "chest_press":
            candidates = ["barbell_bench_press", "dumbbell_chest_press"]
        default:
            return currentKey
        }

        let total = candidates.reduce(0) { $0 + (counts[$1] ?? 0) }
        guard total >= minimumCount,
              let top = candidates.max(by: { (counts[$0] ?? 0) < (counts[$1] ?? 0) }),
              Double(counts[top] ?? 0) / Double(total) >= ratio
        else {
            return currentKey
        }
        return top
    }
}
