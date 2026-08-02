import Foundation
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

    @Test("Verified StoreKit evidence unlocks when RevenueCat cache is inactive")
    @MainActor
    func testStoreKitEvidenceUnlocksInactiveRevenueCatCache() {
        let now = Date()
        let provider = MockPaywallProvider(cached: .init(status: .free))
        let positiveProvider = MockPositiveAccessProvider(
            cached: .init(
                productID: "pro_yearly",
                expirationDate: now.addingTimeInterval(3_600),
                verifiedAt: now
            )
        )
        let service = PaywallService(
            provider: provider,
            positiveAccessProvider: positiveProvider
        )

        #expect(service.accessState == .unlocked)
        #expect(service.subscriptionStatus == .active)
    }

    @Test("Inactive RevenueCat cache waits for StoreKit before showing the paywall")
    @MainActor
    func testInactiveRevenueCatWaitsForStoreKitResolution() async {
        let now = Date()
        let provider = MockPaywallProvider(cached: .init(status: .free))
        let positiveProvider = MockPositiveAccessProvider(
            refreshed: .active(
                .init(
                    productID: "pro_yearly",
                    expirationDate: now.addingTimeInterval(3_600),
                    verifiedAt: now
                )
            )
        )
        let service = PaywallService(
            provider: provider,
            positiveAccessProvider: positiveProvider
        )

        #expect(service.accessState == .checking)
        await service.refreshAccess(trigger: "test")
        #expect(service.accessState == .unlocked)
    }

    @Test("Empty StoreKit result cannot erase active RevenueCat access")
    @MainActor
    func testInactiveStoreKitDoesNotVetoRevenueCat() async {
        let provider = MockPaywallProvider(cached: .init(status: .active))
        let positiveProvider = MockPositiveAccessProvider(refreshed: .inactive)
        let service = PaywallService(
            provider: provider,
            positiveAccessProvider: positiveProvider
        )

        await service.refreshAccess(trigger: "test")

        #expect(service.accessState == .unlocked)
        #expect(service.subscriptionStatus == .active)
    }

    @Test("Uncertain StoreKit refresh preserves saved positive access")
    @MainActor
    func testUncertainStoreKitPreservesCachedPositiveAccess() async {
        let now = Date()
        let positiveProvider = MockPositiveAccessProvider(
            cached: .init(
                productID: "pro_yearly",
                expirationDate: now.addingTimeInterval(3_600),
                verifiedAt: now
            ),
            refreshed: .uncertain
        )
        let service = PaywallService(
            provider: MockPaywallProvider(cached: .init(status: .free)),
            positiveAccessProvider: positiveProvider
        )

        await service.refreshAccess(trigger: "test")

        #expect(service.accessState == .unlocked)
        #expect(service.subscriptionStatus == .active)
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

    @Test("Purchase is not reported complete without the required entitlement")
    @MainActor
    func testInactivePurchaseDoesNotUnlock() async {
        let provider = MockPaywallProvider(cached: .init(status: .free))
        provider.purchased = .init(status: .free)
        let service = PaywallService(provider: provider)

        await #expect(throws: PaywallError.entitlementNotGranted) {
            try await service.purchase(productId: "pro_yearly", placement: "test")
        }

        #expect(service.accessState == .locked)
        #expect(service.subscriptionStatus == .free)
    }

    @Test("Restore reports whether active access was found")
    @MainActor
    func testRestoreReportsAccessResult() async throws {
        let provider = MockPaywallProvider(cached: .init(status: .free))
        let service = PaywallService(provider: provider)

        provider.restored = .init(status: .active)
        #expect(try await service.restorePurchases())
        #expect(service.accessState == .unlocked)

        provider.restored = .init(status: .expired)
        #expect(try await service.restorePurchases() == false)
        #expect(service.accessState == .locked)
    }

    @Test("An older launch refresh cannot revoke a completed purchase")
    @MainActor
    func testStaleRefreshCannotReplacePurchase() async throws {
        let provider = ControlledPaywallProvider()
        provider.purchased = .init(status: .trial)
        let service = PaywallService(provider: provider)

        let launchRefresh = Task { await service.refreshCustomerInfo() }
        await waitForRefreshCount(1, provider: provider)

        try await service.purchase(productId: "pro_yearly", placement: "test")
        provider.completeRefresh(at: 0, with: .init(status: .free))
        await launchRefresh.value

        #expect(service.accessState == .unlocked)
        #expect(service.subscriptionStatus == .trial)
    }

    @Test("Retry replaces a timed-out refresh and ignores its late result")
    @MainActor
    func testRetryReplacesTimedOutRefresh() async {
        let provider = ControlledPaywallProvider()
        let service = PaywallService(provider: provider)

        let launchRefresh = Task { await service.refreshCustomerInfo() }
        await waitForRefreshCount(1, provider: provider)

        let retry = Task { await service.retryCustomerInfo() }
        await waitForRefreshCount(2, provider: provider)

        provider.completeRefresh(at: 1, with: .init(status: .active))
        await retry.value
        provider.completeRefresh(at: 0, with: .init(status: .free))
        await launchRefresh.value

        #expect(service.accessState == .unlocked)
        #expect(service.subscriptionStatus == .active)
    }

    @Test("The stream's duplicate cached value does not suppress a newer refresh")
    @MainActor
    func testDuplicateInitialStreamValueDoesNotInvalidateRefresh() async {
        let cachedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let provider = ControlledPaywallProvider(
            cached: .init(status: .active, requestDate: cachedAt)
        )
        let service = PaywallService(provider: provider)

        let launchRefresh = Task { await service.refreshCustomerInfo() }
        await waitForRefreshCount(1, provider: provider)

        service.receiveEntitlementUpdate(
            .init(status: .active, requestDate: cachedAt)
        )
        provider.completeRefresh(
            at: 0,
            with: .init(status: .expired, requestDate: cachedAt.addingTimeInterval(60))
        )
        await launchRefresh.value

        #expect(service.accessState == .locked)
        #expect(service.subscriptionStatus == .expired)
    }

    @MainActor
    private func waitForRefreshCount(
        _ expectedCount: Int,
        provider: ControlledPaywallProvider
    ) async {
        for _ in 0..<100 {
            if provider.pendingRefreshCount == expectedCount { return }
            await Task.yield()
        }
        #expect(provider.pendingRefreshCount == expectedCount)
    }
}

private enum MockPaywallError: Error {
    case offline
}

@MainActor
private final class MockPositiveAccessProvider: PositiveSubscriptionAccessProviding {
    var cached: VerifiedSubscriptionAccessEvidence?
    var refreshed: PositiveSubscriptionAccessResult

    init(
        cached: VerifiedSubscriptionAccessEvidence? = nil,
        refreshed: PositiveSubscriptionAccessResult = .inactive
    ) {
        self.cached = cached
        self.refreshed = refreshed
    }

    func cachedVerifiedAccess(now: Date) -> VerifiedSubscriptionAccessEvidence? {
        cached
    }

    func refreshVerifiedAccess(now: Date) async -> PositiveSubscriptionAccessResult {
        refreshed
    }
}

@MainActor
private final class MockPaywallProvider: PaywallProviding {
    let isConfigured = true
    var cached: EntitlementSnapshot?
    var refreshed = EntitlementSnapshot(status: .free)
    var purchased = EntitlementSnapshot(status: .free)
    var restored = EntitlementSnapshot(status: .free)
    var refreshError: Error?
    var loadedOffer = SubscriptionOfferSnapshot(
        productID: "pro_yearly",
        localizedPrice: "$29.99",
        billingPeriodLabel: "year",
        trialLabel: nil,
        eligibility: .unknown
    )

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

    func loadOffer(productId: String) async throws -> SubscriptionOfferSnapshot {
        loadedOffer
    }

    func restorePurchases() async throws -> EntitlementSnapshot {
        restored
    }
}

@MainActor
private final class ControlledPaywallProvider: PaywallProviding {
    let isConfigured = true
    var cached: EntitlementSnapshot?
    var purchased = EntitlementSnapshot(status: .free)
    private var refreshContinuations: [CheckedContinuation<EntitlementSnapshot, Error>] = []

    init(cached: EntitlementSnapshot? = nil) {
        self.cached = cached
    }

    var pendingRefreshCount: Int {
        refreshContinuations.count
    }

    func cachedEntitlement() -> EntitlementSnapshot? {
        cached
    }

    func refreshEntitlement() async throws -> EntitlementSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            refreshContinuations.append(continuation)
        }
    }

    func purchase(productId: String) async throws -> EntitlementSnapshot {
        purchased
    }

    func restorePurchases() async throws -> EntitlementSnapshot {
        purchased
    }

    func completeRefresh(at index: Int, with snapshot: EntitlementSnapshot) {
        refreshContinuations[index].resume(returning: snapshot)
    }
}
