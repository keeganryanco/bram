import Testing
import Foundation
import UIKit
@testable import Bram

struct BramTests {
    @Test func workoutNoteDefaultsToEmptyBody() {
        let note = WorkoutNote()
        #expect(note.body.isEmpty)
    }

    @Test func freePremiumAccountHasPremiumAccess() {
        let account = AccountSnapshot(
            userId: UUID(),
            email: "keegan@trybram.app",
            displayName: "Keegan",
            preferredUnits: "lb",
            onboardingCompletedAt: nil,
            accountTier: .freePremium,
            subscriptionStatus: .freePremium,
            entitlementSource: .manual,
            isDeveloper: true,
            founderOfferEligible: true,
            premiumExpiresAt: nil,
            entitlementsUpdatedAt: .now
        )

        #expect(account.hasPremiumAccess)
        #expect(account.hasDeveloperAccess)
    }

    @Test func emptyDailyWorkoutNoteStartsReady() {
        let note = DailyWorkoutNote()

        #expect(note.body.isEmpty)
        #expect(note.metrics.parseState == .empty)
        #expect(note.parsedSummary == nil)
    }

    @Test func bramLogoAssetIsBundled() {
        #expect(UIImage(named: "BramLogo") != nil)
    }
}
