import Testing
@testable import Boilerplate

struct AnalyticsEventTests {
    @Test("Production SOP event names are stable")
    func testProductionEventNames() {
        #expect(AnalyticsEvent.onboardingStarted.name == "onboarding_started")
        #expect(AnalyticsEvent.onboardingCompleted.name == "onboarding_completed")
        #expect(AnalyticsEvent.paywallViewed(placement: "test").name == "paywall_viewed")
        #expect(AnalyticsEvent.purchaseStarted(productId: "pro_yearly", placement: "test").name == "purchase_started")
        #expect(AnalyticsEvent.purchaseCompleted(productId: "pro_yearly", placement: "test").name == "purchase_completed")
        #expect(AnalyticsEvent.purchaseFailed(productId: "pro_yearly", placement: "test", reason: "failed").name == "purchase_failed")
        #expect(AnalyticsEvent.restorePurchasesStarted.name == "restore_purchases_started")
        #expect(AnalyticsEvent.restorePurchasesCompleted.name == "restore_purchases_completed")
        #expect(AnalyticsEvent.restorePurchasesFailed(reason: "failed").name == "restore_purchases_failed")
        #expect(AnalyticsEvent.reviewPromptEligible(reason: "success").name == "review_prompt_eligible")
        #expect(AnalyticsEvent.reviewPromptRequested(reason: "success").name == "review_prompt_requested")
    }
}
