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
    var activePromoKind: String?
    var activePromoCode: String?
    var activePromoLabel: String?
    var entitlementsUpdatedAt: Date

    var hasPremiumAccess: Bool {
        accountTier == .premium || accountTier == .freePremium
    }

    var hasDeveloperAccess: Bool {
        isDeveloper
    }

    init(
        userId: UUID,
        email: String,
        displayName: String?,
        preferredUnits: String,
        onboardingCompletedAt: Date?,
        accountTier: BramAccountTier,
        subscriptionStatus: BramSubscriptionStatus,
        entitlementSource: BramEntitlementSource,
        isDeveloper: Bool,
        founderOfferEligible: Bool,
        premiumExpiresAt: Date?,
        activePromoKind: String? = nil,
        activePromoCode: String? = nil,
        activePromoLabel: String? = nil,
        entitlementsUpdatedAt: Date
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.preferredUnits = preferredUnits
        self.onboardingCompletedAt = onboardingCompletedAt
        self.accountTier = accountTier
        self.subscriptionStatus = subscriptionStatus
        self.entitlementSource = entitlementSource
        self.isDeveloper = isDeveloper
        self.founderOfferEligible = founderOfferEligible
        self.premiumExpiresAt = premiumExpiresAt
        self.activePromoKind = activePromoKind
        self.activePromoCode = activePromoCode
        self.activePromoLabel = activePromoLabel
        self.entitlementsUpdatedAt = entitlementsUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        preferredUnits = try container.decode(String.self, forKey: .preferredUnits)
        onboardingCompletedAt = try container.decodeFlexibleDateIfPresent(forKey: .onboardingCompletedAt)
        accountTier = try container.decode(BramAccountTier.self, forKey: .accountTier)
        subscriptionStatus = try container.decode(BramSubscriptionStatus.self, forKey: .subscriptionStatus)
        entitlementSource = try container.decode(BramEntitlementSource.self, forKey: .entitlementSource)
        isDeveloper = try container.decode(Bool.self, forKey: .isDeveloper)
        founderOfferEligible = try container.decode(Bool.self, forKey: .founderOfferEligible)
        premiumExpiresAt = try container.decodeFlexibleDateIfPresent(forKey: .premiumExpiresAt)
        activePromoKind = try container.decodeIfPresent(String.self, forKey: .activePromoKind)
        activePromoCode = try container.decodeIfPresent(String.self, forKey: .activePromoCode)
        activePromoLabel = try container.decodeIfPresent(String.self, forKey: .activePromoLabel)
        entitlementsUpdatedAt = try container.decodeFlexibleDate(forKey: .entitlementsUpdatedAt)
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
        case activePromoKind = "active_promo_kind"
        case activePromoCode = "active_promo_code"
        case activePromoLabel = "active_promo_label"
        case entitlementsUpdatedAt = "entitlements_updated_at"
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleDate(forKey key: Key) throws -> Date {
        if let date = try? decode(Date.self, forKey: key) {
            return date
        }
        let value = try decode(String.self, forKey: key)
        if let date = Date.bramDate(from: value) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected ISO-8601 date string."
        )
    }

    func decodeFlexibleDateIfPresent(forKey key: Key) throws -> Date? {
        if try decodeNil(forKey: key) {
            return nil
        }
        if let date = try? decode(Date.self, forKey: key) {
            return date
        }
        guard let value = try decodeIfPresent(String.self, forKey: key), !value.isEmpty else {
            return nil
        }
        if let date = Date.bramDate(from: value) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected optional ISO-8601 date string."
        )
    }
}

private extension Date {
    static func bramDate(from value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
