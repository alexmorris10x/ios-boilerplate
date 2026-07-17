import Foundation

#if canImport(UIKit)
import UIKit
#endif

final class PerformancePersistence: @unchecked Sendable {
    private let runtime: PerformanceRuntime
    private let queue = DispatchQueue(label: "performance-nervous-system.persistence", qos: .utility)

    init(runtime: PerformanceRuntime) {
        self.runtime = runtime
    }

    func prepare() {
        queue.async { [self] in
            let config = runtime.config
            try? prepareDirectory(rootDirectory(config: config))
            try? prune(directory: incidentDirectory(config: config), maximumCount: config.retention.maximumIncidentCount,
                       retention: config.retention, preserving: nil, now: Date())
            try? prune(directory: sessionDirectory(config: config), maximumCount: config.retention.maximumSessionCount,
                       retention: config.retention, preserving: nil, now: Date())
        }
    }

    func writeIncident(
        trigger: String,
        completion: (@Sendable (Result<URL, Error>) -> Void)? = nil
    ) {
        queue.async { [self] in
            let config = runtime.config
            guard config.isEnabled, config.persistIncidents else {
                completion?(.failure(PerformanceNervousSystemError.disabled))
                return
            }
            let safeTrigger = PerformancePrivacy.sanitizedLabel(trigger, fallback: "performance_incident")
            let snapshot = runtime.snapshot()
            let report = PerformanceIncidentReport(
                schemaVersion: 1,
                incidentID: UUID(),
                sessionID: runtime.sessionID,
                createdAt: Date(),
                trigger: safeTrigger,
                device: deviceSnapshot(configuration: config),
                performance: snapshot
            )
            do {
                let directory = incidentDirectory(config: config)
                let url = directory.appendingPathComponent(
                    "\(milliseconds(report.createdAt))-\(safeTrigger)-\(report.incidentID.uuidString.prefix(8)).json"
                )
                try write(report, to: url)
                try prune(directory: directory, maximumCount: config.retention.maximumIncidentCount,
                          retention: config.retention, preserving: url, now: report.createdAt)
                runtime.emit(.init(level: .warning, message: "incident \(safeTrigger) persisted"))
                completion?(.success(url))
            } catch {
                runtime.emit(.init(level: .error, message: "incident persistence failed"))
                completion?(.failure(error))
            }
        }
    }

    func writeSession(reason: String, force: Bool) {
        let now = Date()
        guard runtime.claimSessionWrite(now: now, force: force) else { return }
        queue.async { [self] in
            let config = runtime.config
            guard config.isEnabled, config.persistSessions else { return }
            let safeReason = PerformancePrivacy.sanitizedLabel(reason, fallback: "lifecycle")
            let report = PerformanceSessionReport(
                schemaVersion: 1, sessionID: runtime.sessionID, createdAt: now, reason: safeReason,
                device: deviceSnapshot(configuration: config), performance: runtime.snapshot()
            )
            do {
                let directory = sessionDirectory(config: config)
                let url = directory.appendingPathComponent(
                    "\(milliseconds(now))-\(safeReason)-\(runtime.sessionID.uuidString.prefix(8)).json"
                )
                try write(report, to: url)
                try prune(directory: directory, maximumCount: config.retention.maximumSessionCount,
                          retention: config.retention, preserving: url, now: now)
            } catch {
                runtime.emit(.init(level: .error, message: "session persistence failed"))
            }
        }
    }

    private func rootDirectory(config: PerformanceConfiguration) -> URL {
        if let configured = config.storageDirectory { return configured }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("PerformanceNervousSystem", isDirectory: true)
    }

    private func incidentDirectory(config: PerformanceConfiguration) -> URL {
        rootDirectory(config: config).appendingPathComponent("Incidents/v1", isDirectory: true)
    }

    private func sessionDirectory(config: PerformanceConfiguration) -> URL {
        rootDirectory(config: config).appendingPathComponent("Sessions/v1", isDirectory: true)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try prepareDirectory(url.deletingLastPathComponent())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        #if os(iOS) || targetEnvironment(macCatalyst)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    private func prepareDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var mutable = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutable.setResourceValues(values)
    }

    private struct Candidate {
        let url: URL
        let date: Date
        let bytes: Int
    }

    private func prune(
        directory: URL,
        maximumCount: Int,
        retention: PerformanceRetention,
        preserving: URL?,
        now: Date
    ) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .creationDateKey, .fileSizeKey, .isRegularFileKey]
        var candidates = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> Candidate? in
                guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { return nil }
                return Candidate(url: url, date: values.contentModificationDate ?? values.creationDate ?? .distantPast,
                                 bytes: values.fileSize ?? 0)
            }
        let oldest = now.addingTimeInterval(-retention.maximumAgeSeconds)
        for candidate in candidates where candidate.url != preserving && candidate.date < oldest {
            try? FileManager.default.removeItem(at: candidate.url)
        }
        candidates = candidates.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        candidates.sort {
            if $0.url == preserving { return true }
            if $1.url == preserving { return false }
            return $0.date > $1.date
        }
        var count = 0
        var bytes = 0
        for candidate in candidates {
            let preserve = candidate.url == preserving
            if !preserve, (count >= maximumCount || bytes + candidate.bytes > retention.maximumBytesPerStore) {
                try? FileManager.default.removeItem(at: candidate.url)
            } else {
                count += 1
                bytes += candidate.bytes
            }
        }
    }

    private func milliseconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1_000)
    }

    private func deviceSnapshot(configuration: PerformanceConfiguration) -> PerformanceDeviceSnapshot {
        let bundle = Bundle.main
        let process = ProcessInfo.processInfo
        #if canImport(UIKit)
        let device = UIDevice.current
        let deviceModel = Self.machineIdentifier()
        let systemName = device.systemName
        let systemVersion = device.systemVersion
        let scale = UIScreen.main.scale
        let frames = UIScreen.main.maximumFramesPerSecond
        #else
        let deviceModel = Self.machineIdentifier()
        let systemName = "macOS"
        let systemVersion = process.operatingSystemVersionString
        let scale = 1.0
        let frames = 0
        #endif
        return PerformanceDeviceSnapshot(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
            environment: configuration.environment,
            deviceModel: deviceModel,
            systemName: systemName,
            systemVersion: systemVersion,
            screenScale: scale,
            maximumFramesPerSecond: frames,
            appUptimeSeconds: Date().timeIntervalSince(runtime.launchedAt),
            systemUptimeSeconds: process.systemUptime,
            thermalState: Self.thermalDescription(process.thermalState),
            lowPowerModeEnabled: process.isLowPowerModeEnabled,
            physicalMemoryBytes: process.physicalMemory
        )
    }

    private static func thermalDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private static func machineIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}
