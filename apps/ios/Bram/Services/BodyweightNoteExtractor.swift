import Foundation

struct BodyweightObservation: Hashable {
    var value: Double
    var unit: String
    var loggedAt: Date
    var source: BodyweightSource
}

enum BodyweightNoteExtractor {
    static func extract(from line: String, date: Date) -> BodyweightObservation? {
        explicitBodyweight(in: line, date: date)
    }

    static func extract(from note: DailyWorkoutNote, existingWeight: Double?) -> BodyweightObservation? {
        let lines = note.body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        for line in lines {
            if let explicit = explicitBodyweight(in: line, date: note.date) {
                return explicit
            }
        }

        guard let existingWeight else { return nil }
        for line in lines {
            if let inferred = inferredBodyweight(in: line, existingWeight: existingWeight, date: note.date) {
                return inferred
            }
        }

        return nil
    }

    private static func explicitBodyweight(in line: String, date: Date) -> BodyweightObservation? {
        let lower = line.lowercased()
        let patterns = [
            #"(?:body\s*weight|bodyweight|current\s*weight|weighed|weight\s*at)[^\n]{0,40}?(\d{2,3}(?:\.\d+)?)\s*(lb|lbs|pounds?|kg)?"#,
            #"(\d{2,3}(?:\.\d+)?)\s*(lb|lbs|pounds?|kg)\s*(?:body\s*weight|bodyweight|current\s*weight|weighed)"#,
            #"(\d{2,3}(?:\.\d+)?)\s*(lb|lbs|pounds?|kg)?[^\n]{0,40}?\b(?:body\s*weight|bodyweight|current\s*weight|weighed)\b"#
        ]

        for pattern in patterns {
            guard let match = firstMatch(pattern, in: lower),
                  let value = Double(match[1])
            else { continue }
            return BodyweightObservation(
                value: value,
                unit: normalizedUnit(match[safe: 2]),
                loggedAt: date,
                source: .note
            )
        }

        return nil
    }

    private static func inferredBodyweight(in line: String, existingWeight: Double, date: Date) -> BodyweightObservation? {
        let lower = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return nil }
        guard !looksLikeSetLine(lower), !looksLikeExerciseLine(lower) else { return nil }
        guard let match = firstMatch(#"\b(\d{2,3}(?:\.\d+)?)\s*(lb|lbs|pounds?|kg)\b"#, in: lower),
              let value = Double(match[1]),
              abs(value - existingWeight) <= 10
        else { return nil }

        return BodyweightObservation(
            value: value,
            unit: normalizedUnit(match[safe: 2]),
            loggedAt: date,
            source: .note
        )
    }

    private static func looksLikeSetLine(_ line: String) -> Bool {
        firstMatch(#"^\s*\d+\s*[-:]\s*(?:\d|bw|bodyweight)"#, in: line) != nil ||
            firstMatch(#"\b\d+\s*(?:x|for)\s*\d+\b"#, in: line) != nil
    }

    private static func looksLikeExerciseLine(_ line: String) -> Bool {
        let exerciseWords = [
            "bench", "squat", "deadlift", "curl", "press", "raise", "row",
            "pulldown", "pushdown", "fly", "flies", "extension", "lunge",
            "rdl", "dips", "pullup", "pushup", "crunch"
        ]
        return exerciseWords.contains { line.contains($0) }
    }

    private static func normalizedUnit(_ rawUnit: String?) -> String {
        guard let rawUnit else { return "lb" }
        return rawUnit == "kg" ? "kg" : "lb"
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard let swiftRange = Range(range, in: text) else { return "" }
            return String(text[swiftRange])
        }
    }
}

private extension Array where Element == String {
    subscript(safe index: Int) -> String? {
        indices.contains(index) && !self[index].isEmpty ? self[index] : nil
    }
}
