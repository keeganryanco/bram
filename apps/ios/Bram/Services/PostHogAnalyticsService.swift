import Foundation
import PostHog

final class PostHogAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    nonisolated(unsafe) private static var didConfigure = false
    private let isConfigured: Bool

    private init(isConfigured: Bool) {
        self.isConfigured = isConfigured
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> any AnalyticsTracking {
        guard let token = resolvedProjectToken(
            bundle.object(forInfoDictionaryKey: "BramPostHogProjectToken") as? String
        ) else {
            return NoopAnalyticsService()
        }

        let host = (bundle.object(forInfoDictionaryKey: "BramPostHogHost") as? String)
            .flatMap(URL.init(string:)) ?? URL(string: "https://us.i.posthog.com")!

        if !didConfigure {
            let config = PostHogConfig(projectToken: token, host: host.absoluteString)
            config.captureApplicationLifecycleEvents = true
            config.captureScreenViews = false
            config.flushAt = 1
            config.flushIntervalSeconds = 5
            config.sendFeatureFlagEvent = false
            config.sessionReplay = false
            config.errorTrackingConfig.autoCapture = true
            PostHogSDK.shared.setup(config)
            didConfigure = true
        }

        return PostHogAnalyticsService(isConfigured: true)
    }

    func track(_ event: AnalyticsEvent) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture(event.name, properties: event.properties)
        PostHogSDK.shared.flush()
    }

    func capture(error: Error, properties: [String: String]) {
        guard isConfigured else { return }
        PostHogSDK.shared.captureException(error, properties: properties)
    }

    func identify(userId: UUID, properties: [String: String]) {
        guard isConfigured else { return }
        PostHogSDK.shared.identify(userId.uuidString.lowercased(), userProperties: properties)
    }

    func reset() {
        guard isConfigured else { return }
        PostHogSDK.shared.reset()
    }

    static func resolvedProjectToken(_ rawToken: String?) -> String? {
        guard let token = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty,
              !token.contains("$("),
              token.hasPrefix("phc_")
        else {
            return nil
        }

        return token
    }
}
