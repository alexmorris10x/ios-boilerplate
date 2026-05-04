import Foundation
import Testing
@testable import Boilerplate

struct ReviewPromptServiceTests {
    @Test("Review prompt waits for enough success moments")
    @MainActor
    func testReviewPromptEligibilityThreshold() {
        let storage = makeStorage()
        let service = ReviewPromptService(
            storage: storage,
            appVersion: "1.0",
            configuration: .init(minimumSuccessfulActions: 3, cooldownDays: 90)
        )

        service.recordSuccessfulAction(reason: "first")
        service.recordSuccessfulAction(reason: "second")

        #expect(service.pendingRequestID == nil)

        service.recordSuccessfulAction(reason: "third")

        #expect(service.pendingRequestID != nil)
        #expect(service.pendingReason == "third")
    }

    @Test("Review prompt does not repeat for the same app version")
    @MainActor
    func testReviewPromptVersionGate() {
        let storage = makeStorage()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let service = ReviewPromptService(
            storage: storage,
            appVersion: "1.0",
            currentDate: { now },
            configuration: .init(minimumSuccessfulActions: 1, cooldownDays: 90)
        )

        service.recordSuccessfulAction(reason: "saved_item")
        #expect(service.pendingRequestID != nil)

        service.markPromptAttempted()
        service.recordSuccessfulAction(reason: "saved_item_again")

        #expect(service.pendingRequestID == nil)
    }

    @Test("Review prompt respects cooldown")
    @MainActor
    func testReviewPromptCooldown() {
        let storage = makeStorage()
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let serviceV1 = ReviewPromptService(
            storage: storage,
            appVersion: "1.0",
            currentDate: { now },
            configuration: .init(minimumSuccessfulActions: 1, cooldownDays: 90)
        )

        serviceV1.recordSuccessfulAction(reason: "completed_project")
        serviceV1.markPromptAttempted()

        now = now.addingTimeInterval(10 * 24 * 60 * 60)
        let serviceV2 = ReviewPromptService(
            storage: storage,
            appVersion: "1.1",
            currentDate: { now },
            configuration: .init(minimumSuccessfulActions: 1, cooldownDays: 90)
        )
        serviceV2.recordSuccessfulAction(reason: "completed_project")

        #expect(serviceV2.pendingRequestID == nil)
    }

    private nonisolated func makeStorage() -> UserDefaults {
        let suiteName = "ReviewPromptServiceTests.\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suiteName)!
        storage.removePersistentDomain(forName: suiteName)
        return storage
    }
}
