import XCTest
@testable import PerformanceNervousSystem

final class PerformanceNervousSystemTests: XCTestCase {
    func testPrivacyDropsUnknownKeysAndUnsafeValues() {
        let result = PerformancePrivacy.sanitizedMetadata([
            "itemCount": "42",
            "screen": "library",
            "title": "Private Journal",
            "path": "/private/var/mobile/secret.pdf",
            "reason": "Private Book.pdf",
        ])

        XCTAssertEqual(result["itemcount"], "42")
        XCTAssertEqual(result["screen"], "library")
        XCTAssertNil(result["title"])
        XCTAssertNil(result["path"])
        XCTAssertNil(result["reason"])
        XCTAssertEqual(PerformancePrivacy.sanitizedLabel("Private Book.pdf"), "redacted")
        XCTAssertEqual(PerformancePrivacy.sanitizedLabel("folder/secret"), "redacted")
    }

    func testRuntimeBoundsRecentSpansActiveSpansAggregatesAndMarks() throws {
        let runtime = PerformanceRuntime()
        let retention = PerformanceRetention(
            maximumRecentSpanCount: 2,
            maximumActiveSpanCount: 2,
            maximumAggregateCount: 2
        )
        XCTAssertTrue(runtime.start(.init(retention: retention)))

        for index in 0..<4 {
            let token = try XCTUnwrap(runtime.begin(
                name: "span_\(index)", category: "test", metadata: [:], parentID: nil
            ))
            _ = runtime.end(token, status: "ok", metadata: [:])
            _ = runtime.recordMark(name: "mark_\(index)", metadata: [:], level: .info)
        }
        for index in 0..<4 {
            _ = runtime.begin(name: "active_\(index)", category: "test", metadata: [:], parentID: nil)
        }

        let snapshot = runtime.snapshot()
        XCTAssertEqual(snapshot.recentSpans.count, 2)
        XCTAssertEqual(snapshot.recentMarks.count, 2)
        XCTAssertEqual(snapshot.activeSpans.count, 2)
        XCTAssertEqual(snapshot.aggregates.count, 2)
    }

    func testIncidentDedupeAllowsCooldownOrMaterialNewWorst() {
        XCTAssertFalse(IncidentDeduplicationPolicy.shouldRecord(
            now: 110, lastIncidentAt: 100, largestDelay: 0.6, delay: 0.7,
            cooldown: 20, newWorstMargin: 0.5
        ))
        XCTAssertTrue(IncidentDeduplicationPolicy.shouldRecord(
            now: 121, lastIncidentAt: 100, largestDelay: 0.6, delay: 0.7,
            cooldown: 20, newWorstMargin: 0.5
        ))
        XCTAssertTrue(IncidentDeduplicationPolicy.shouldRecord(
            now: 110, lastIncidentAt: 100, largestDelay: 0.6, delay: 1.1,
            cooldown: 20, newWorstMargin: 0.5
        ))
    }

    func testConfigurationClampsUnsafeBounds() {
        let retention = PerformanceRetention(
            maximumIncidentCount: 0,
            maximumSessionCount: -1,
            maximumBytesPerStore: 1,
            maximumRecentSpanCount: 0,
            maximumActiveSpanCount: 0,
            maximumAggregateCount: 0
        )
        XCTAssertEqual(retention.maximumIncidentCount, 1)
        XCTAssertEqual(retention.maximumSessionCount, 1)
        XCTAssertGreaterThanOrEqual(retention.maximumBytesPerStore, 64 * 1_024)
        XCTAssertEqual(retention.maximumRecentSpanCount, 1)
        XCTAssertEqual(retention.maximumActiveSpanCount, 1)
        XCTAssertEqual(retention.maximumAggregateCount, 1)
    }
}
