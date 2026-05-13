import Foundation
import RevenueCat
import StoreKit

@MainActor
final class RevenueCatPaywallService: BramPaywallServicing {
    private let apiKey: String
    private var packageById: [String: Package] = [:]
    private var configuredUserId: UUID?

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    static func configuredFromBundle(_ bundle: Bundle = .main) -> RevenueCatPaywallService? {
        guard let apiKey = bundle.object(forInfoDictionaryKey: "BramRevenueCatAPIKey") as? String,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        return RevenueCatPaywallService(apiKey: apiKey)
    }

    func configure(userId: UUID) throws {
        if Purchases.isConfigured {
            if configuredUserId != userId {
                Purchases.shared.logIn(userId.uuidString) { _, _, _ in }
                configuredUserId = userId
            }
            return
        }

        Purchases.configure(withAPIKey: apiKey, appUserID: userId.uuidString)
        configuredUserId = userId
    }

    func loadPaywall() async throws -> BramPaywallSnapshot {
        guard Purchases.isConfigured else { throw BramPaywallError.notConfigured }

        let offerings: Offerings = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Offerings, Error>) in
            Purchases.shared.getOfferings { offerings, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let offerings else {
                    continuation.resume(throwing: BramPaywallError.noOffering)
                    return
                }
                continuation.resume(returning: offerings)
            }
        }

        guard let offering = offerings.current, !offering.availablePackages.isEmpty else {
            packageById = [:]
            throw BramPaywallError.noOffering
        }

        packageById = Dictionary(uniqueKeysWithValues: offering.availablePackages.map { ($0.identifier, $0) })
        let packages = offering.availablePackages.map { package in
            BramPaywallPackage(
                id: package.identifier,
                title: title(for: package),
                price: package.storeProduct.localizedPriceString,
                period: periodText(for: package),
                detail: detailText(for: package),
                isRecommended: package.packageType == .annual
            )
        }

        return BramPaywallSnapshot(packages: packages, message: nil)
    }

    func purchase(packageId: String) async throws {
        guard let package = packageById[packageId] else {
            throw BramPaywallError.packageUnavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Purchases.shared.purchase(package: package) { _, _, error, userCancelled in
                if userCancelled {
                    continuation.resume(throwing: BramPaywallError.purchaseCancelled)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func restorePurchases() async throws {
        guard Purchases.isConfigured else { throw BramPaywallError.notConfigured }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Purchases.shared.restorePurchases { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func presentCodeRedemption() {
        SKPaymentQueue.default().presentCodeRedemptionSheet()
    }

    private func title(for package: Package) -> String {
        switch package.packageType {
        case .annual: "Yearly"
        case .monthly: "Monthly"
        default: package.storeProduct.localizedTitle
        }
    }

    private func periodText(for package: Package) -> String {
        switch package.packageType {
        case .annual: "per year"
        case .monthly: "per month"
        default: "subscription"
        }
    }

    private func detailText(for package: Package) -> String {
        switch package.packageType {
        case .annual: "3 days free, then yearly billing"
        case .monthly: "3 days free, then monthly billing"
        default: "3 days free, then renews automatically"
        }
    }
}
