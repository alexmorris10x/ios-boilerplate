import Foundation
import OSLog

extension NSLock {
    @inline(__always)
    func performanceWithLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

public final class PerformanceSpanToken: @unchecked Sendable {
    public let id: UUID
    public let parentID: UUID?
    public let name: String
    public let category: String

    fileprivate let startedAt: Date
    fileprivate let startedAtUptime: TimeInterval
    fileprivate let executionContext: String
    fileprivate let metadata: [String: String]
    fileprivate let signpostID: OSSignpostID
    private let completionLock = NSLock()
    private var completed = false

    fileprivate init(
        id: UUID,
        parentID: UUID?,
        name: String,
        category: String,
        startedAt: Date,
        startedAtUptime: TimeInterval,
        executionContext: String,
        metadata: [String: String],
        signpostID: OSSignpostID
    ) {
        self.id = id
        self.parentID = parentID
        self.name = name
        self.category = category
        self.startedAt = startedAt
        self.startedAtUptime = startedAtUptime
        self.executionContext = executionContext
        self.metadata = metadata
        self.signpostID = signpostID
    }

    @discardableResult
    public func end(status: String = "ok", metadata: [String: String] = [:]) -> Double? {
        let claimed = completionLock.performanceWithLock {
            guard !completed else { return false }
            completed = true
            return true
        }
        guard claimed else { return nil }
        return PerformanceNervousSystem.shared.endSpan(self, status: status, metadata: metadata)
    }

    @discardableResult
    public func cancel(reason: String = "cancelled") -> Double? {
        end(status: "cancelled", metadata: ["reason": reason])
    }
}

public typealias PerformanceJourneyToken = PerformanceSpanToken

final class PerformanceRuntime: @unchecked Sendable {
    struct Aggregate {
        let category: String
        let name: String
        var count: Int
        var total: Double
        var maximum: Double
        var last: Double
        var status: String
        var updatedAt: Date
    }

    static let signpostLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "performance-nervous-system",
        category: "Performance"
    )

    let sessionID = UUID()
    let launchedAt = Date()
    private let lock = NSLock()
    private var configuration = PerformanceConfiguration(isEnabled: false)
    private var started = false
    private var active: [UUID: PerformanceSpanToken] = [:]
    private var recent: [PerformanceCompletedSpanSnapshot] = []
    private var aggregates: [String: Aggregate] = [:]
    private var contextName = "startup"
    private var contextMetadata: [String: String] = [:]
    private var recentMarks: [PerformanceMarkSnapshot] = []
    private var hitchCount = 0
    private var worstFrameMilliseconds = 0.0
    private var lastSessionWriteAt = Date.distantPast

    func start(_ configuration: PerformanceConfiguration) -> Bool {
        lock.performanceWithLock {
            guard !started else { return false }
            self.configuration = configuration
            started = true
            return configuration.isEnabled
        }
    }

    var config: PerformanceConfiguration { lock.performanceWithLock { configuration } }
    var isEnabled: Bool { lock.performanceWithLock { started && configuration.isEnabled } }

    func begin(name: String, category: String, metadata: [String: String], parentID: UUID?) -> PerformanceSpanToken? {
        let values = lock.performanceWithLock { () -> (PerformanceConfiguration, Bool) in
            (configuration, started && configuration.isEnabled)
        }
        guard values.1 else { return nil }
        let safeName = PerformancePrivacy.sanitizedLabel(name, fallback: "span")
        let safeCategory = PerformancePrivacy.sanitizedLabel(category, fallback: "general")
        let safeMetadata = PerformancePrivacy.sanitizedMetadata(metadata, allowedKeys: values.0.allowedMetadataKeys)
        let signpostID = OSSignpostID(log: Self.signpostLog)
        os_signpost(.begin, log: Self.signpostLog, name: "PerformanceSpan", signpostID: signpostID,
                    "%{public}@/%{public}@", safeCategory, safeName)
        let token = PerformanceSpanToken(
            id: UUID(), parentID: parentID, name: safeName, category: safeCategory,
            startedAt: Date(), startedAtUptime: ProcessInfo.processInfo.systemUptime,
            executionContext: Thread.isMainThread ? "main" : "background",
            metadata: safeMetadata, signpostID: signpostID
        )
        lock.performanceWithLock {
            pruneActive(now: token.startedAt, retention: values.0.retention)
            active[token.id] = token
            boundActive(retention: values.0.retention)
        }
        return token
    }

    func end(_ token: PerformanceSpanToken, status: String, metadata: [String: String]) -> Double? {
        let now = Date()
        let duration = max(0, (ProcessInfo.processInfo.systemUptime - token.startedAtUptime) * 1_000)
        os_signpost(.end, log: Self.signpostLog, name: "PerformanceSpan", signpostID: token.signpostID,
                    "%{public}@/%{public}@", token.category, token.name)
        let config = self.config
        let safeStatus = PerformancePrivacy.sanitizedLabel(status, fallback: "unknown")
        let safeMetadata = token.metadata.merging(
            PerformancePrivacy.sanitizedMetadata(metadata, allowedKeys: config.allowedMetadataKeys)
        ) { _, new in new }
        let severity: PerformanceSeverity = duration >= 1_000 ? .critical : (duration >= 250 ? .warning : .normal)
        let completed = PerformanceCompletedSpanSnapshot(
            id: token.id, parentID: token.parentID, category: token.category, name: token.name,
            startedAt: token.startedAt, finishedAt: now, durationMilliseconds: duration,
            status: safeStatus, severity: severity, executionContext: token.executionContext,
            metadata: safeMetadata
        )
        let found = lock.performanceWithLock { () -> Bool in
            guard active.removeValue(forKey: token.id) != nil else { return false }
            recent.append(completed)
            if recent.count > config.retention.maximumRecentSpanCount {
                recent.removeFirst(recent.count - config.retention.maximumRecentSpanCount)
            }
            let key = "\(token.category).\(token.name)"
            if var aggregate = aggregates[key] {
                aggregate.count += 1
                aggregate.total += duration
                aggregate.maximum = max(aggregate.maximum, duration)
                aggregate.last = duration
                aggregate.status = safeStatus
                aggregate.updatedAt = now
                aggregates[key] = aggregate
            } else {
                if aggregates.count >= config.retention.maximumAggregateCount,
                   let oldest = aggregates.min(by: { $0.value.updatedAt < $1.value.updatedAt })?.key {
                    aggregates.removeValue(forKey: oldest)
                }
                aggregates[key] = Aggregate(category: token.category, name: token.name, count: 1,
                                             total: duration, maximum: duration, last: duration,
                                             status: safeStatus, updatedAt: now)
            }
            return true
        }
        guard found else { return nil }
        if severity != .normal || safeStatus != "ok" {
            emit(.init(level: severity == .critical ? .warning : .info,
                       message: "span \(token.category)/\(token.name) \(Int(duration))ms status=\(safeStatus)"))
        }
        return duration
    }

    func setContext(_ name: String, metadata: [String: String]) {
        let config = self.config
        guard isEnabled else { return }
        let safeName = PerformancePrivacy.sanitizedLabel(name, fallback: "unknown")
        let safeMetadata = PerformancePrivacy.sanitizedMetadata(metadata, allowedKeys: config.allowedMetadataKeys)
        lock.performanceWithLock {
            contextName = safeName
            contextMetadata = safeMetadata
        }
    }

    func recordHitch(milliseconds: Double) {
        lock.performanceWithLock {
            hitchCount += 1
            worstFrameMilliseconds = max(worstFrameMilliseconds, milliseconds)
        }
    }

    func recordMark(name: String, metadata: [String: String], level: PerformanceLogLevel) -> PerformanceMarkSnapshot? {
        let config = self.config
        guard isEnabled else { return nil }
        let safeName = PerformancePrivacy.sanitizedLabel(name, fallback: "mark")
        let safeMetadata = PerformancePrivacy.sanitizedMetadata(metadata, allowedKeys: config.allowedMetadataKeys)
        return lock.performanceWithLock {
            let mark = PerformanceMarkSnapshot(
                capturedAt: Date(), name: safeName, level: level,
                context: contextName, metadata: safeMetadata
            )
            recentMarks.append(mark)
            if recentMarks.count > config.retention.maximumRecentSpanCount {
                recentMarks.removeFirst(recentMarks.count - config.retention.maximumRecentSpanCount)
            }
            return mark
        }
    }

    func snapshot() -> PerformanceSnapshot {
        let now = Date()
        return lock.performanceWithLock {
            pruneActive(now: now, retention: configuration.retention)
            let context = PerformanceContextSnapshot(
                capturedAt: now, name: contextName, metadata: contextMetadata,
                hitchCount: hitchCount, worstFrameMilliseconds: worstFrameMilliseconds
            )
            let activeSnapshots = active.values.map {
                PerformanceActiveSpanSnapshot(
                    id: $0.id, parentID: $0.parentID, category: $0.category, name: $0.name,
                    startedAt: $0.startedAt, elapsedMilliseconds: max(0, now.timeIntervalSince($0.startedAt) * 1_000),
                    executionContext: $0.executionContext, metadata: $0.metadata
                )
            }.sorted { $0.startedAt < $1.startedAt }
            let aggregateSnapshots = aggregates.map { key, value in
                PerformanceAggregateSnapshot(
                    key: key, category: value.category, name: value.name, count: value.count,
                    averageMilliseconds: value.total / Double(max(1, value.count)),
                    maximumMilliseconds: value.maximum, totalMilliseconds: value.total,
                    lastMilliseconds: value.last, lastStatus: value.status, lastUpdatedAt: value.updatedAt
                )
            }.sorted { $0.totalMilliseconds > $1.totalMilliseconds }
            return PerformanceSnapshot(schemaVersion: 1, sessionID: sessionID, capturedAt: now,
                                       context: context, recentMarks: recentMarks, activeSpans: activeSnapshots,
                                       recentSpans: recent, aggregates: aggregateSnapshots)
        }
    }

    func claimSessionWrite(now: Date, force: Bool) -> Bool {
        lock.performanceWithLock {
            guard force || now.timeIntervalSince(lastSessionWriteAt) >= configuration.retention.minimumSessionWriteIntervalSeconds
            else { return false }
            lastSessionWriteAt = now
            return true
        }
    }

    func emit(_ event: PerformanceLogEvent) { config.logSink?(event) }

    private func pruneActive(now: Date, retention: PerformanceRetention) {
        active = active.filter { now.timeIntervalSince($0.value.startedAt) < retention.maximumActiveSpanAgeSeconds }
    }

    private func boundActive(retention: PerformanceRetention) {
        let overflow = active.count - retention.maximumActiveSpanCount
        guard overflow > 0 else { return }
        for token in active.values.sorted(by: { $0.startedAt < $1.startedAt }).prefix(overflow) {
            active.removeValue(forKey: token.id)
        }
    }
}
