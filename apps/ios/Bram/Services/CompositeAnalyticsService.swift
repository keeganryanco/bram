import Foundation

final class CompositeAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    private let services: [any AnalyticsTracking]

    init(_ services: [any AnalyticsTracking]) {
        self.services = services
    }

    func track(_ event: AnalyticsEvent) {
        services.forEach { $0.track(event) }
    }

    func capture(error: Error, properties: [String: String]) {
        services.forEach { $0.capture(error: error, properties: properties) }
    }

    func identify(userId: UUID, properties: [String: String]) {
        services.forEach { $0.identify(userId: userId, properties: properties) }
    }

    func reset() {
        services.forEach { $0.reset() }
    }
}
