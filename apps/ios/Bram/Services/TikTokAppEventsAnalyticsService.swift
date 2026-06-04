import Foundation
import CryptoKit
import AppTrackingTransparency
import TikTokBusinessSDK

final class TikTokAppEventsAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    private let configURL: URL
    private let lock = NSLock()
    private var isConfigured = false
    private var pendingUserId: UUID?
    private var pendingEvents: [TikTokMappedEvent] = []

    private init(configURL: URL) {
        self.configURL = configURL
        Task { await configure() }
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> any AnalyticsTracking {
        guard let baseURLString = bundle.object(forInfoDictionaryKey: "BramAPIBaseURL") as? String,
              let baseURL = URL(string: baseURLString),
              let configURL = URL(string: "/api/tiktok/app-config", relativeTo: baseURL)?.absoluteURL
        else {
            return NoopAnalyticsService()
        }

        return TikTokAppEventsAnalyticsService(configURL: configURL)
    }

    func track(_ event: AnalyticsEvent) {
        guard let mapped = TikTokMappedEvent(event) else { return }

        lock.lock()
        let shouldQueue = !isConfigured
        if shouldQueue {
            pendingEvents.append(mapped)
        }
        lock.unlock()

        if !shouldQueue {
            track(mapped)
        }
    }

    func capture(error: Error, properties: [String: String]) {}

    func identify(userId: UUID, properties: [String: String]) {
        lock.lock()
        let shouldQueue = !isConfigured
        if shouldQueue {
            pendingUserId = userId
        }
        lock.unlock()

        if !shouldQueue {
            identify(userId: userId)
        }
    }

    func reset() {
        lock.lock()
        pendingUserId = nil
        pendingEvents.removeAll()
        let configured = isConfigured
        lock.unlock()

        guard configured else { return }
        TikTokBusiness.logout()
    }

    private func configure() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: configURL)
            let config = try JSONDecoder().decode(TikTokAppEventsConfig.self, from: data)
            guard config.enabled,
                  let accessToken = config.accessToken,
                  let appId = config.appId,
                  let tiktokAppId = config.tiktokAppId
            else { return }

            await MainActor.run {
                requestTrackingAuthorizationIfNeeded()

                guard let tiktokConfig = TikTokConfig(
                    accessToken: accessToken,
                    appId: appId,
                    tiktokAppId: tiktokAppId
                ) else { return }

                if config.debugMode == true {
                    tiktokConfig.enableDebugMode()
                }
                TikTokBusiness.initializeSdk(tiktokConfig)
            }

            let (queuedUserId, queuedEvents) = markConfiguredAndDrainQueuedWork()

            if let queuedUserId {
                identify(userId: queuedUserId)
            }
            queuedEvents.forEach(track)
        } catch {
            return
        }
    }

    @MainActor
    private func requestTrackingAuthorizationIfNeeded() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        ATTrackingManager.requestTrackingAuthorization { _ in }
    }

    private func identify(userId: UUID) {
        TikTokBusiness.identify(
            withExternalID: Self.sha256(userId.uuidString),
            externalUserName: nil,
            phoneNumber: nil,
            email: nil
        )
    }

    private func track(_ event: TikTokMappedEvent) {
        let tiktokEvent = TikTokBaseEvent(
            eventName: event.name,
            properties: event.properties,
            eventId: event.eventId
        )
        TikTokBusiness.trackTTEvent(tiktokEvent)
        TikTokBusiness.explicitlyFlush()
    }

    private static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func markConfiguredAndDrainQueuedWork() -> (UUID?, [TikTokMappedEvent]) {
        lock.lock()
        defer { lock.unlock() }
        isConfigured = true
        let queuedUserId = pendingUserId
        let queuedEvents = pendingEvents
        pendingEvents.removeAll()
        return (queuedUserId, queuedEvents)
    }
}

private struct TikTokAppEventsConfig: Decodable {
    var enabled: Bool
    var accessToken: String?
    var appId: String?
    var tiktokAppId: String?
    var debugMode: Bool?
}

private struct TikTokMappedEvent {
    var name: String
    var properties: [String: String]
    var eventId: String

    init?(_ event: AnalyticsEvent) {
        switch event.name {
        case "onboarding_completed":
            name = "CompleteTutorial"
            properties = Self.onboardingProperties(event.properties)
        case "subscription_access_confirmed":
            guard let status = event.properties["subscription_status"] else { return nil }
            switch status {
            case BramSubscriptionStatus.trial.rawValue:
                name = "StartTrial"
            case BramSubscriptionStatus.active.rawValue:
                name = "Subscribe"
            default:
                return nil
            }
            properties = Self.subscriptionProperties(event.properties)
        default:
            return nil
        }

        eventId = "bram:\(event.name):\(UUID().uuidString.lowercased())"
    }

    private static func onboardingProperties(_ properties: [String: String]) -> [String: String] {
        [
            "content_type": "onboarding",
            "onboarding_experiment_key": properties["onboarding_experiment_key"] ?? "",
            "onboarding_variant": properties["onboarding_variant"] ?? ""
        ].filter { !$0.value.isEmpty }
    }

    private static func subscriptionProperties(_ properties: [String: String]) -> [String: String] {
        [
            "content_type": "subscription",
            "content_id": "bram_premium",
            "subscription_status": properties["subscription_status"] ?? "",
            "account_tier": properties["account_tier"] ?? ""
        ].filter { !$0.value.isEmpty }
    }
}
