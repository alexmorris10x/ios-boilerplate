import Foundation

public enum PerformanceSeverity: String, Codable, Sendable {
    case normal
    case warning
    case critical
}

public struct PerformanceActiveSpanSnapshot: Codable, Sendable, Equatable {
    public let id: UUID
    public let parentID: UUID?
    public let category: String
    public let name: String
    public let startedAt: Date
    public let elapsedMilliseconds: Double
    public let executionContext: String
    public let metadata: [String: String]
}

public struct PerformanceCompletedSpanSnapshot: Codable, Sendable, Equatable {
    public let id: UUID
    public let parentID: UUID?
    public let category: String
    public let name: String
    public let startedAt: Date
    public let finishedAt: Date
    public let durationMilliseconds: Double
    public let status: String
    public let severity: PerformanceSeverity
    public let executionContext: String
    public let metadata: [String: String]
}

public struct PerformanceAggregateSnapshot: Codable, Sendable, Equatable {
    public let key: String
    public let category: String
    public let name: String
    public let count: Int
    public let averageMilliseconds: Double
    public let maximumMilliseconds: Double
    public let totalMilliseconds: Double
    public let lastMilliseconds: Double
    public let lastStatus: String
    public let lastUpdatedAt: Date
}

public struct PerformanceContextSnapshot: Codable, Sendable, Equatable {
    public let capturedAt: Date
    public let name: String
    public let metadata: [String: String]
    public let hitchCount: Int
    public let worstFrameMilliseconds: Double
}

public struct PerformanceMarkSnapshot: Codable, Sendable, Equatable {
    public let capturedAt: Date
    public let name: String
    public let level: PerformanceLogLevel
    public let context: String
    public let metadata: [String: String]
}

public struct PerformanceSnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let sessionID: UUID
    public let capturedAt: Date
    public let context: PerformanceContextSnapshot
    public let recentMarks: [PerformanceMarkSnapshot]
    public let activeSpans: [PerformanceActiveSpanSnapshot]
    public let recentSpans: [PerformanceCompletedSpanSnapshot]
    public let aggregates: [PerformanceAggregateSnapshot]
}

public struct PerformanceDeviceSnapshot: Codable, Sendable, Equatable {
    public let appVersion: String
    public let buildNumber: String
    public let bundleIdentifier: String
    public let environment: String
    public let deviceModel: String
    public let systemName: String
    public let systemVersion: String
    public let screenScale: Double
    public let maximumFramesPerSecond: Int
    public let appUptimeSeconds: Double
    public let systemUptimeSeconds: Double
    public let thermalState: String
    public let lowPowerModeEnabled: Bool
    public let physicalMemoryBytes: UInt64
}

public struct PerformanceIncidentReport: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let incidentID: UUID
    public let sessionID: UUID
    public let createdAt: Date
    public let trigger: String
    public let device: PerformanceDeviceSnapshot
    public let performance: PerformanceSnapshot
}

public struct PerformanceSessionReport: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let sessionID: UUID
    public let createdAt: Date
    public let reason: String
    public let device: PerformanceDeviceSnapshot
    public let performance: PerformanceSnapshot
}
