import Foundation
import UserNotifications

struct BramNotificationService: WorkoutReminderScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleReminder(after note: DailyWorkoutNote, goals: TrainingGoalsProfile) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: ["bram.next-workout"])

        let content = UNMutableNotificationContent()
        content.title = "Bram"
        content.body = reminderBody(after: note, goals: goals)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminderDelay(for: goals), repeats: false)
        let request = UNNotificationRequest(identifier: "bram.next-workout", content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelReminders() async {
        center.removePendingNotificationRequests(withIdentifiers: ["bram.next-workout"])
    }

    private func reminderBody(after note: DailyWorkoutNote, goals: TrainingGoalsProfile) -> String {
        if note.metrics.prCount > 0 {
            return "You logged a PR last time. Keep the rhythm going today."
        }
        if note.metrics.cardioMinutes > 0, note.metrics.totalSets == 0 {
            return "Last session had cardio. Ready to keep the streak moving?"
        }
        if note.metrics.totalSets > 0 {
            return "Planning to train today? A quick note keeps your progress remembered."
        }
        switch goals.primaryGoal {
        case .stronger:
            return "Ready for the next lift? Bram is ready when you are."
        case .buildMuscle:
            return "A steady session today keeps the week moving."
        case .betterCardio:
            return "Time for another session? Track it naturally in Bram."
        case .leaner, .healthyRoutine, .maintain:
            return "Planning to train today? Keep the habit simple."
        }
    }

    private func reminderDelay(for goals: TrainingGoalsProfile) -> TimeInterval {
        let daysPerWeek = max(1, min(7, goals.weeklyTrainingDays))
        let daysBetweenSessions = max(1, Int((7.0 / Double(daysPerWeek)).rounded()))
        return TimeInterval(daysBetweenSessions * 24 * 60 * 60)
    }
}
