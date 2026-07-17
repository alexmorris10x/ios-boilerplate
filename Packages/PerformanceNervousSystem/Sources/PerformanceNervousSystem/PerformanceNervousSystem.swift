import Foundation

public enum PerformanceNervousSystemError: Error, Sendable {
    case disabled
}

public final class PerformanceNervousSystem: @unchecked Sendable {
    public static let shared = PerformanceNervousSystem()

    private let runtime = PerformanceRuntime()
    private lazy var persistence = PerformancePersistence(runtime: runtime)
    private lazy var monitors = PerformanceMonitors(runtime: runtime, persistence: persistence)

    private init() {}

    public var sessionID: UUID { runtime.sessionID }
    public var isEnabled: Bool { runtime.isEnabled }

    /// Starts the process-wide nervous system. The first call wins.
    public func start(_ configuration: PerformanceConfiguration = .init()) {
        guard runtime.start(configuration) else { return }
        persistence.prepare()
        monitors.start(configuration: configuration)
        mark("performance_system_started", metadata: ["environment": configuration.environment])
    }

    public func stop() {
        monitors.stop()
        writeSession(reason: "stop", force: true)
    }

    @discardableResult
    public func beginSpan(
        _ name: String,
        category: String = "general",
        metadata: [String: String] = [:],
        parent: PerformanceSpanToken? = nil
    ) -> PerformanceSpanToken? {
        runtime.begin(name: name, category: category, metadata: metadata, parentID: parent?.id)
    }

    @discardableResult
    public func endSpan(
        _ span: PerformanceSpanToken,
        status: String = "ok",
        metadata: [String: String] = [:]
    ) -> Double? {
        runtime.end(span, status: status, metadata: metadata)
    }

    public func setContext(_ name: String, metadata: [String: String] = [:]) {
        runtime.setContext(name, metadata: metadata)
    }

    @discardableResult
    public func beginJourney(
        _ name: String,
        metadata: [String: String] = [:],
        parent: PerformanceSpanToken? = nil
    ) -> PerformanceJourneyToken? {
        beginSpan(name, category: "journey", metadata: metadata, parent: parent)
    }

    public func mark(
        _ name: String,
        metadata: [String: String] = [:],
        level: PerformanceLogLevel = .info
    ) {
        guard runtime.isEnabled else { return }
        guard let mark = runtime.recordMark(name: name, metadata: metadata, level: level) else { return }
        let suffix = mark.metadata.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        runtime.emit(.init(level: level, message: suffix.isEmpty ? "mark \(mark.name)" : "mark \(mark.name) \(suffix)"))
    }

    public func snapshot() -> PerformanceSnapshot { runtime.snapshot() }

    public func writeIncident(trigger: String) {
        guard runtime.isEnabled, runtime.config.persistIncidents else { return }
        persistence.writeIncident(trigger: trigger)
    }

    @discardableResult
    public func writeIncidentReport(trigger: String) async throws -> URL {
        guard runtime.isEnabled, runtime.config.persistIncidents else {
            throw PerformanceNervousSystemError.disabled
        }
        return try await withCheckedThrowingContinuation { continuation in
            persistence.writeIncident(trigger: trigger) { result in
                continuation.resume(with: result)
            }
        }
    }

    public func writeSession(reason: String, force: Bool = false) {
        guard runtime.isEnabled, runtime.config.persistSessions else { return }
        persistence.writeSession(reason: reason, force: force)
    }
}
