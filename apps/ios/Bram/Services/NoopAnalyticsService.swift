import Foundation

struct NoopAnalyticsService: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
    func capture(error: Error, properties: [String: String]) {}
    func identify(userId: UUID, properties: [String: String]) {}
    func reset() {}
}
