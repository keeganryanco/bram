import Foundation

enum BramSubscriptionProductID {
    static let premiumMonthly = "app.trybram.Bram.premium.monthly"
    static let premiumYearly = "app.trybram.Bram.premium.year"
    static let orderedPremiumProducts = [premiumYearly, premiumMonthly]
}

struct BramPaywallPackage: Identifiable, Equatable, Hashable {
    var id: String
    var productId: String
    var title: String
    var price: String
    var promoPrice: String?
    var period: String
    var detail: String
    var isRecommended: Bool

    var displayPrice: String {
        promoPrice ?? price
    }
}

struct BramPaywallSnapshot: Equatable {
    var packages: [BramPaywallPackage]
    var message: String?

    static let unavailable = BramPaywallSnapshot(
        packages: [],
        message: "Subscriptions are not configured yet. Restore purchases or try again soon."
    )
}

enum BramPaywallError: LocalizedError, Equatable {
    case notConfigured
    case noOffering
    case packageUnavailable
    case purchaseCancelled
    case refreshFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Subscriptions are not configured yet."
        case .noOffering:
            "Subscription options are not available yet."
        case .packageUnavailable:
            "That subscription option is not available."
        case .purchaseCancelled:
            "Purchase cancelled."
        case .refreshFailed:
            "Could not refresh subscription access."
        }
    }
}
