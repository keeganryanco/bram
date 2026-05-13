import Foundation

struct BramFeatureAccess: Equatable {
    var canUseInterpretation: Bool
    var canUseStats: Bool
    var canUseHealth: Bool
    var canUseSuggestions: Bool
    var canUseDeveloperFeatures: Bool

    static let free = BramFeatureAccess(
        canUseInterpretation: false,
        canUseStats: false,
        canUseHealth: false,
        canUseSuggestions: false,
        canUseDeveloperFeatures: false
    )

    static let previewPremium = BramFeatureAccess(
        canUseInterpretation: true,
        canUseStats: true,
        canUseHealth: true,
        canUseSuggestions: true,
        canUseDeveloperFeatures: true
    )
}

enum BramEntitlementPolicy {
    static func access(for account: AccountSnapshot?) -> BramFeatureAccess {
        guard let account else { return .free }

        let premium = account.hasPremiumAccess || account.hasDeveloperAccess
        return BramFeatureAccess(
            canUseInterpretation: premium,
            canUseStats: premium,
            canUseHealth: premium,
            canUseSuggestions: premium,
            canUseDeveloperFeatures: account.hasDeveloperAccess
        )
    }
}
