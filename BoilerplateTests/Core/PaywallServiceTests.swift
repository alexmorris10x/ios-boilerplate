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
}
