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

    func configure(userId: UUID) async throws {
        let userIdString = userId.uuidString
        if Purchases.isConfigured {
            if configuredUserId != userId {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    Purchases.shared.logIn(userIdString) { _, _, error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }
                        continuation.resume(returning: ())
                    }
                }
                configuredUserId = userId
            }
            return
        }

        Purchases.configure(withAPIKey: apiKey, appUserID: userIdString)
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

        let offering = offerings.current ?? offerings.offering(identifier: "premium")

        guard let offering, !offering.availablePackages.isEmpty else {
            packageById = [:]
            throw BramPaywallError.noOffering
        }

        let availablePackages = offering.availablePackages
            .filter { BramSubscriptionProductID.orderedPremiumProducts.contains($0.storeProduct.productIdentifier) }
            .sorted { lhs, rhs in
                productOrder(lhs.storeProduct.productIdentifier) < productOrder(rhs.storeProduct.productIdentifier)
            }

        guard !availablePackages.isEmpty else {
            packageById = [:]
            throw BramPaywallError.noOffering
        }

        packageById = Dictionary(uniqueKeysWithValues: availablePackages.map { ($0.identifier, $0) })
        let packages = availablePackages.map { package in
            BramPaywallPackage(
                id: package.identifier,
                productId: package.storeProduct.productIdentifier,
                title: title(for: package),
                price: package.storeProduct.localizedPriceString,
                promoPrice: nil,
                period: periodText(for: package),
                detail: detailText(for: package),
                isRecommended: package.packageType == .annual
            )
        }

        return BramPaywallSnapshot(packages: packages, message: nil)
    }

    func trackPaywallImpression() {
        guard Purchases.isConfigured else { return }
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: "bram_v1_hard_paywall")
        )
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
        switch package.storeProduct.productIdentifier {
        case BramSubscriptionProductID.premiumYearly:
            "Yearly"
        case BramSubscriptionProductID.premiumMonthly:
            "Monthly"
        default:
            switch package.packageType {
            case .annual: "Yearly"
            case .monthly: "Monthly"
            default: package.storeProduct.localizedTitle
            }
        }
    }

    private func periodText(for package: Package) -> String {
        switch package.storeProduct.productIdentifier {
        case BramSubscriptionProductID.premiumYearly:
            "per year"
        case BramSubscriptionProductID.premiumMonthly:
            "per month"
        default:
            switch package.packageType {
            case .annual: "per year"
            case .monthly: "per month"
            default: "subscription"
            }
        }
    }

    private func detailText(for package: Package) -> String {
        switch package.storeProduct.productIdentifier {
        case BramSubscriptionProductID.premiumYearly:
            "3 days free, then yearly billing"
        case BramSubscriptionProductID.premiumMonthly:
            "3 days free, then monthly billing"
        default:
            switch package.packageType {
            case .annual: "3 days free, then yearly billing"
            case .monthly: "3 days free, then monthly billing"
            default: "3 days free, then renews automatically"
            }
        }
    }

    private func productOrder(_ productIdentifier: String) -> Int {
        BramSubscriptionProductID.orderedPremiumProducts.firstIndex(of: productIdentifier) ?? Int.max
    }
}
