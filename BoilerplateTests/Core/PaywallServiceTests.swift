import Testing
@testable import Boilerplate

struct PaywallServiceTests {
    @Test("Not-configured paywall reports restore failure")
    @MainActor
    func testRestorePurchasesNotConfigured() async {
        let service = PaywallService()

        await #expect(throws: PaywallError.notConfigured) {
            try await service.restorePurchases()
        }

        #expect(service.subscriptionStatus == .notConfigured)
        #expect(service.lastMessage == PaywallError.notConfigured.localizedDescription)
    }

    @Test("Not-configured paywall reports purchase failure")
    @MainActor
    func testPurchaseNotConfigured() async {
        let service = PaywallService()

        await #expect(throws: PaywallError.notConfigured) {
            try await service.purchase(productId: "pro_yearly", placement: "test")
        }

        #expect(service.lastMessage == PaywallError.notConfigured.localizedDescription)
    }

    @Test("Subscription status exposes plan and access labels")
    func testSubscriptionStatusPlanLabels() {
        #expect(SubscriptionStatus.free.planName == "Free")
        #expect(SubscriptionStatus.free.accessDescription == "No Active Purchase")
        #expect(SubscriptionStatus.active.planName == "Pro")
        #expect(SubscriptionStatus.active.accessDescription == "Active")
    }

    @Test("Cached paid access unlocks the first frame")
    @MainActor
    func testCachedPaidAccessUnlocksImmediately() {
        let provider = MockPaywallProvider(cached: .init(status: .trial))
        let service = PaywallService(provider: provider)

        #expect(service.accessState == .unlocked)
        #expect(service.subscriptionStatus == .trial)
    }

    @Test("Refresh failure preserves cached paid access")
    @MainActor
    func testRefreshFailurePreservesPaidAccess() async {
        let provider = MockPaywallProvider(cached: .init(status: .active))
        provider.refreshError = MockPaywallError.offline
        let service = PaywallService(provider: provider)

        await service.refreshCustomerInfo()

        #expect(service.accessState == .unlocked)
        #expect(service.subscriptionStatus == .active)
    }

    @Test("Confirmed expiry replaces cached paid access")
    @MainActor
    func testConfirmedExpiryLocksAccess() async {
        let provider = MockPaywallProvider(cached: .init(status: .active))
        provider.refreshed = .init(status: .expired)
        let service = PaywallService(provider: provider)

        await service.refreshCustomerInfo()

        #expect(service.accessState == .locked)
        #expect(service.subscriptionStatus == .expired)
    }

    @Test("Unknown access failure becomes recoverable, not unlocked")
    @MainActor
    func testUnknownFailureDoesNotUnlock() async {
        let provider = MockPaywallProvider()
        provider.refreshError = MockPaywallError.offline
        let service = PaywallService(provider: provider)

        await service.refreshCustomerInfo()

        #expect(service.accessState == .unavailable)
        #expect(service.subscriptionStatus == .free)
    }

    @Test("Successful purchase unlocks immediately")
    @MainActor
    func testPurchaseUnlocksImmediately() async throws {
        let provider = MockPaywallProvider()
        provider.purchased = .init(status: .trial)
        let service = PaywallService(provider: provider)

        try await service.purchase(productId: "pro_yearly", placement: "test")

        #expect(service.accessState == .unlocked)
        #expect(service.subscriptionStatus == .trial)
    }
}

private enum MockPaywallError: Error {
    case offline
}

@MainActor
private final class MockPaywallProvider: PaywallProviding {
    let isConfigured = true
    var cached: EntitlementSnapshot?
    var refreshed = EntitlementSnapshot(status: .free)
    var purchased = EntitlementSnapshot(status: .free)
    var restored = EntitlementSnapshot(status: .free)
    var refreshError: Error?

    init(cached: EntitlementSnapshot? = nil) {
        self.cached = cached
    }

    func cachedEntitlement() -> EntitlementSnapshot? {
        cached
    }

    func refreshEntitlement() async throws -> EntitlementSnapshot {
        if let refreshError { throw refreshError }
        return refreshed
    }

    func purchase(productId: String) async throws -> EntitlementSnapshot {
        purchased
    }

    func restorePurchases() async throws -> EntitlementSnapshot {
        restored
    }
}
