import Foundation

enum BramAccountTier: String, Codable, Equatable {
    case free = "FREE"
    case premium = "PREMIUM"
    case freePremium = "FREE_PREMIUM"
}

enum BramSubscriptionStatus: String, Codable, Equatable {
    case none = "NONE"
    case trial = "TRIAL"
    case active = "ACTIVE"
    case gracePeriod = "GRACE_PERIOD"
    case expired = "EXPIRED"
    case canceled = "CANCELED"
    case billingRetry = "BILLING_RETRY"
    case freePremium = "FREE_PREMIUM"
}

enum BramEntitlementSource: String, Codable, Equatable {
    case none = "NONE"
    case appStore = "APP_STORE"
    case revenueCat = "REVENUECAT"
    case founderOffer = "FOUNDER_OFFER"
    case manual = "MANUAL"
    case dev = "DEV"
}

struct AccountSnapshot: Codable, Equatable {
    let userId: UUID
    let email: String
    var displayName: String?
    var preferredUnits: String
    var onboardingCompletedAt: Date?
    var accountTier: BramAccountTier
    var subscriptionStatus: BramSubscriptionStatus
    var entitlementSource: BramEntitlementSource
    var isDeveloper: Bool
    var founderOfferEligible: Bool
    var premiumExpiresAt: Date?
    var entitlementsUpdatedAt: Date

    var hasPremiumAccess: Bool {
        accountTier == .premium || accountTier == .freePremium
    }

    var hasDeveloperAccess: Bool {
        isDeveloper
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case displayName = "display_name"
        case preferredUnits = "preferred_units"
        case onboardingCompletedAt = "onboarding_completed_at"
        case accountTier = "account_tier"
        case subscriptionStatus = "subscription_status"
        case entitlementSource = "entitlement_source"
        case isDeveloper = "is_developer"
        case founderOfferEligible = "founder_offer_eligible"
        case premiumExpiresAt = "premium_expires_at"
        case entitlementsUpdatedAt = "entitlements_updated_at"
    }
}
