import Foundation

public struct PerformanceThresholds: Sendable, Equatable {
    public var hitchMilliseconds: Double
    public var severeHitchMilliseconds: Double
    public var watchdogPingMilliseconds: Double
    public var watchdogWarningMilliseconds: Double
    public var watchdogSevereMilliseconds: Double
    public var incidentCooldownSeconds: Double
    public var warningIncidentCooldownSeconds: Double
    public var severeNewWorstMarginMilliseconds: Double
    public var warningNewWorstMarginMilliseconds: Double
    public var startupGraceSeconds: Double

    public init(
        hitchMilliseconds: Double = 50,
        severeHitchMilliseconds: Double = 100,
        watchdogPingMilliseconds: Double = 100,
        watchdogWarningMilliseconds: Double = 250,
        watchdogSevereMilliseconds: Double = 500,
        incidentCooldownSeconds: Double = 20,
        warningIncidentCooldownSeconds: Double = 60,
        severeNewWorstMarginMilliseconds: Double = 500,
        warningNewWorstMarginMilliseconds: Double = 250,
        startupGraceSeconds: Double = 5
    ) {
        self.hitchMilliseconds = max(1, hitchMilliseconds)
        self.severeHitchMilliseconds = max(self.hitchMilliseconds, severeHitchMilliseconds)
        self.watchdogPingMilliseconds = max(16, watchdogPingMilliseconds)
        self.watchdogWarningMilliseconds = max(self.watchdogPingMilliseconds, watchdogWarningMilliseconds)
        self.watchdogSevereMilliseconds = max(self.watchdogWarningMilliseconds, watchdogSevereMilliseconds)
        self.incidentCooldownSeconds = max(0, incidentCooldownSeconds)
        self.warningIncidentCooldownSeconds = max(0, warningIncidentCooldownSeconds)
        self.severeNewWorstMarginMilliseconds = max(0, severeNewWorstMarginMilliseconds)
        self.warningNewWorstMarginMilliseconds = max(0, warningNewWorstMarginMilliseconds)
        self.startupGraceSeconds = max(0, startupGraceSeconds)
    }
}

public struct PerformanceRetention: Sendable, Equatable {
    public var maximumIncidentCount: Int
    public var maximumSessionCount: Int
    public var maximumAgeSeconds: TimeInterval
    public var maximumBytesPerStore: Int
    public var maximumRecentSpanCount: Int
    public var maximumActiveSpanCount: Int
    public var maximumAggregateCount: Int
    public var maximumActiveSpanAgeSeconds: TimeInterval
    public var minimumSessionWriteIntervalSeconds: TimeInterval

    public init(
        maximumIncidentCount: Int = 40,
        maximumSessionCount: Int = 30,
        maximumAgeSeconds: TimeInterval = 14 * 24 * 60 * 60,
        maximumBytesPerStore: Int = 10 * 1_024 * 1_024,
        maximumRecentSpanCount: Int = 500,
        maximumActiveSpanCount: Int = 200,
        maximumAggregateCount: Int = 200,
        maximumActiveSpanAgeSeconds: TimeInterval = 5 * 60,
        minimumSessionWriteIntervalSeconds: TimeInterval = 15
    ) {
        self.maximumIncidentCount = max(1, maximumIncidentCount)
        self.maximumSessionCount = max(1, maximumSessionCount)
        self.maximumAgeSeconds = max(60, maximumAgeSeconds)
        self.maximumBytesPerStore = max(64 * 1_024, maximumBytesPerStore)
        self.maximumRecentSpanCount = max(1, maximumRecentSpanCount)
        self.maximumActiveSpanCount = max(1, maximumActiveSpanCount)
        self.maximumAggregateCount = max(1, maximumAggregateCount)
        self.maximumActiveSpanAgeSeconds = max(1, maximumActiveSpanAgeSeconds)
        self.minimumSessionWriteIntervalSeconds = max(0, minimumSessionWriteIntervalSeconds)
    }
}

public enum PerformanceLogLevel: String, Codable, Sendable {
    case debug
    case info
    case warning
    case error
}

public struct PerformanceLogEvent: Sendable, Equatable {
    public let timestamp: Date
    public let level: PerformanceLogLevel
    public let message: String

    public init(timestamp: Date = Date(), level: PerformanceLogLevel, message: String) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

public struct PerformanceConfiguration: Sendable {
    public var isEnabled: Bool
    public var monitorHitches: Bool
    public var monitorMainThread: Bool
    public var persistSessions: Bool
    public var persistIncidents: Bool
    public var environment: String
    public var thresholds: PerformanceThresholds
    public var retention: PerformanceRetention
    public var allowedMetadataKeys: Set<String>
    public var storageDirectory: URL?
    public var logSink: (@Sendable (PerformanceLogEvent) -> Void)?

    public init(
        isEnabled: Bool = true,
        monitorHitches: Bool = true,
        monitorMainThread: Bool = true,
        persistSessions: Bool = true,
        persistIncidents: Bool = true,
        environment: String = "production",
        thresholds: PerformanceThresholds = .init(),
        retention: PerformanceRetention = .init(),
        allowedMetadataKeys: Set<String> = PerformancePrivacy.defaultAllowedMetadataKeys,
        storageDirectory: URL? = nil,
        logSink: (@Sendable (PerformanceLogEvent) -> Void)? = nil
    ) {
        self.isEnabled = isEnabled
        self.monitorHitches = monitorHitches
        self.monitorMainThread = monitorMainThread
        self.persistSessions = persistSessions
        self.persistIncidents = persistIncidents
        self.environment = PerformancePrivacy.sanitizedLabel(environment, fallback: "unknown")
        self.thresholds = thresholds
        self.retention = retention
        self.allowedMetadataKeys = Set(allowedMetadataKeys.map(PerformancePrivacy.normalizedKey))
        self.storageDirectory = storageDirectory
        self.logSink = logSink
    }
}
