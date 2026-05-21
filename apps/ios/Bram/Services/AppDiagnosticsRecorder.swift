import Foundation

struct AppDiagnosticsRecorder: @unchecked Sendable {
    static let shared = AppDiagnosticsRecorder()

    private let defaults: UserDefaults
    private let sessionActiveKey = "bram.diagnostics.session_active"
    private let crashPromptDismissedKey = "bram.diagnostics.crash_prompt_dismissed"
    private let crashPromptSuppressedUntilKey = "bram.diagnostics.crash_prompt_suppressed_until"
    private let recentLogsKey = "bram.diagnostics.recent_logs"
    private let maxLogCount = 40

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func beginSession() -> Bool {
        let previousSessionWasActive = defaults.bool(forKey: sessionActiveKey)
        defaults.set(true, forKey: sessionActiveKey)
        return previousSessionWasActive &&
            !defaults.bool(forKey: crashPromptDismissedKey) &&
            !isCrashPromptTemporarilySuppressed()
    }

    func markCleanExit() {
        defaults.set(false, forKey: sessionActiveKey)
    }

    func dismissCrashPrompt() {
        defaults.set(true, forKey: crashPromptDismissedKey)
    }

    func suppressCrashPromptTemporarily(duration: TimeInterval = 600) {
        defaults.set(Date().addingTimeInterval(duration).timeIntervalSince1970, forKey: crashPromptSuppressedUntilKey)
    }

    func clearPendingCrashPrompt() {
        defaults.set(false, forKey: crashPromptDismissedKey)
        defaults.set(false, forKey: sessionActiveKey)
        defaults.removeObject(forKey: crashPromptSuppressedUntilKey)
    }

    func record(eventName: String, properties: [String: String]) {
        var logs = recentLogs()
        logs.append(
            DiagnosticLogEntry(
                timestamp: Date().ISO8601Format(),
                name: eventName,
                properties: properties
            )
        )
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }
        if let data = try? JSONEncoder().encode(logs) {
            defaults.set(data, forKey: recentLogsKey)
        }
    }

    func recentLogs() -> [DiagnosticLogEntry] {
        guard let data = defaults.data(forKey: recentLogsKey),
              let logs = try? JSONDecoder().decode([DiagnosticLogEntry].self, from: data)
        else { return [] }

        return logs
    }

    private func isCrashPromptTemporarilySuppressed() -> Bool {
        let suppressUntil = defaults.double(forKey: crashPromptSuppressedUntilKey)
        guard suppressUntil > 0 else { return false }

        if Date().timeIntervalSince1970 < suppressUntil {
            return true
        }

        defaults.removeObject(forKey: crashPromptSuppressedUntilKey)
        return false
    }
}

struct DiagnosticLogEntry: Codable, Hashable, Sendable {
    var timestamp: String
    var name: String
    var properties: [String: String]
}
