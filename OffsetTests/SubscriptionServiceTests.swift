import Foundation
import Testing
@testable import Offset

@MainActor
struct SubscriptionServiceTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    @Test func resolvesFreeAndExpiredEntitlementsWithoutGrantingAccess() {
        let free = SubscriptionService.resolve(snapshot(exists: false), now: now)
        let expired = SubscriptionService.resolve(
            snapshot(isActive: false, expirationDate: now.addingTimeInterval(-1)),
            now: now
        )

        #expect(free == .free)
        #expect(expired == .expired(expirationDate: now.addingTimeInterval(-1)))
        #expect(!free.grantsPremiumAccess)
        #expect(!expired.grantsPremiumAccess)
    }

    @Test func activeAndGracePeriodEntitlementsContinueToGrantAccess() {
        let active = SubscriptionService.resolve(
            snapshot(isActive: true, expirationDate: now.addingTimeInterval(3_600), willRenew: false, isTrial: true),
            now: now
        )
        let grace = SubscriptionService.resolve(
            snapshot(isActive: true, expirationDate: now.addingTimeInterval(3_600), hasBillingIssue: true),
            now: now
        )

        #expect(active == .active(expirationDate: now.addingTimeInterval(3_600), willRenew: false, isTrial: true))
        #expect(grace == .billingIssue(expirationDate: now.addingTimeInterval(3_600)))
        #expect(active.grantsPremiumAccess)
        #expect(grace.grantsPremiumAccess)
    }

    private func snapshot(
        exists: Bool = true,
        isActive: Bool = false,
        expirationDate: Date? = nil,
        willRenew: Bool = false,
        isTrial: Bool = false,
        hasBillingIssue: Bool = false
    ) -> SubscriptionService.EntitlementSnapshot {
        .init(
            exists: exists,
            isActive: isActive,
            expirationDate: expirationDate,
            willRenew: willRenew,
            isTrial: isTrial,
            hasBillingIssue: hasBillingIssue
        )
    }
}
