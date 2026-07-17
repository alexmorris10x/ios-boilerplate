import Foundation

#if canImport(UIKit)
import UIKit
#endif

public enum IncidentDeduplicationPolicy {
    public static func shouldRecord(
        now: TimeInterval,
        lastIncidentAt: TimeInterval,
        largestDelay: TimeInterval,
        delay: TimeInterval,
        cooldown: TimeInterval,
        newWorstMargin: TimeInterval
    ) -> Bool {
        now - lastIncidentAt >= cooldown || delay >= largestDelay + newWorstMargin
    }
}

final class PerformanceMonitors: @unchecked Sendable {
    private let runtime: PerformanceRuntime
    private let persistence: PerformancePersistence
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []
    private var watchdog: MainThreadWatchdog?
    #if canImport(UIKit)
    private var hitchMonitor: FrameHitchMonitor?
    #endif

    init(runtime: PerformanceRuntime, persistence: PerformancePersistence) {
        self.runtime = runtime
        self.persistence = persistence
    }

    func start(configuration: PerformanceConfiguration) {
        let center = NotificationCenter.default
        var installed: [NSObjectProtocol] = []
        #if canImport(UIKit)
        installed.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) {
            [weak self] _ in self?.persistence.writeSession(reason: "background", force: false)
        })
        installed.append(center.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: nil) {
            [weak self] _ in self?.persistence.writeSession(reason: "termination", force: true)
        })
        if configuration.monitorHitches {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let monitor = FrameHitchMonitor(runtime: runtime, thresholds: configuration.thresholds)
                self.lock.performanceWithLock { self.hitchMonitor = monitor }
                monitor.start()
            }
        }
        #endif
        installed.append(center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil) {
            [weak self] _ in
            let state = ProcessInfo.processInfo.thermalState
            guard state == .serious || state == .critical else { return }
            self?.persistence.writeSession(reason: "thermal_pressure", force: false)
        })
        lock.performanceWithLock { observers = installed }
        if configuration.monitorMainThread {
            let monitor = MainThreadWatchdog(runtime: runtime, persistence: persistence, thresholds: configuration.thresholds)
            lock.performanceWithLock { watchdog = monitor }
            monitor.start()
        }
    }

    func stop() {
        let values = lock.performanceWithLock { () -> ([NSObjectProtocol], MainThreadWatchdog?) in
            let values = (observers, watchdog)
            observers = []
            watchdog = nil
            return values
        }
        values.0.forEach(NotificationCenter.default.removeObserver)
        values.1?.stop()
        #if canImport(UIKit)
        DispatchQueue.main.async { [weak self] in
            self?.lock.performanceWithLock {
                self?.hitchMonitor?.stop()
                self?.hitchMonitor = nil
            }
        }
        #endif
    }
}

private final class MainThreadWatchdog: @unchecked Sendable {
    private let runtime: PerformanceRuntime
    private let persistence: PerformancePersistence
    private let thresholds: PerformanceThresholds
    private let queue = DispatchQueue(label: "performance-nervous-system.watchdog", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var monitoringStartedAt: TimeInterval = 0
    private var pendingAt: TimeInterval?
    private var pendingIncidentWritten = false
    private var lastSevereAt: TimeInterval = -.infinity
    private var lastWarningAt: TimeInterval = -.infinity
    private var largestSevere = 0.0
    private var largestWarning = 0.0

    init(runtime: PerformanceRuntime, persistence: PerformancePersistence, thresholds: PerformanceThresholds) {
        self.runtime = runtime
        self.persistence = persistence
        self.thresholds = thresholds
    }

    func start() {
        queue.async { [self] in
            guard timer == nil else { return }
            monitoringStartedAt = ProcessInfo.processInfo.systemUptime
            let source = DispatchSource.makeTimerSource(queue: queue)
            let interval = DispatchTimeInterval.milliseconds(Int(thresholds.watchdogPingMilliseconds))
            source.schedule(deadline: .now() + interval, repeating: interval)
            source.setEventHandler { [weak self] in self?.tick() }
            timer = source
            source.resume()
        }
    }

    func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
            pendingAt = nil
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if let pendingAt {
            let delay = now - pendingAt
            let severe = thresholds.watchdogSevereMilliseconds / 1_000
            if delay >= severe, !pendingIncidentWritten, claimSevere(now: now, delay: delay) {
                pendingIncidentWritten = true
                persistence.writeIncident(trigger: "main_thread_stall")
            }
            return
        }
        pendingAt = now
        pendingIncidentWritten = false
        DispatchQueue.main.async { [weak self] in
            self?.queue.async { [weak self] in self?.finishPing(startedAt: now) }
        }
    }

    private func finishPing(startedAt: TimeInterval) {
        let now = ProcessInfo.processInfo.systemUptime
        let delay = max(0, now - startedAt)
        let hadPendingIncident = pendingIncidentWritten
        pendingAt = nil
        pendingIncidentWritten = false
        let warning = thresholds.watchdogWarningMilliseconds / 1_000
        let severe = thresholds.watchdogSevereMilliseconds / 1_000
        guard delay >= warning else { return }
        runtime.emit(.init(level: delay >= severe ? .error : .warning,
                           message: "main thread delay \(Int(delay * 1_000))ms context=\(runtime.snapshot().context.name)"))
        if delay >= severe {
            if !hadPendingIncident, claimSevere(now: now, delay: delay) {
                persistence.writeIncident(trigger: "main_thread_stall")
            }
        } else if now - monitoringStartedAt >= thresholds.startupGraceSeconds, claimWarning(now: now, delay: delay) {
            persistence.writeIncident(trigger: "main_thread_warning_stall")
        }
    }

    private func claimSevere(now: TimeInterval, delay: TimeInterval) -> Bool {
        guard IncidentDeduplicationPolicy.shouldRecord(
            now: now, lastIncidentAt: lastSevereAt, largestDelay: largestSevere, delay: delay,
            cooldown: thresholds.incidentCooldownSeconds,
            newWorstMargin: thresholds.severeNewWorstMarginMilliseconds / 1_000
        ) else { return false }
        lastSevereAt = now
        largestSevere = max(largestSevere, delay)
        return true
    }

    private func claimWarning(now: TimeInterval, delay: TimeInterval) -> Bool {
        guard IncidentDeduplicationPolicy.shouldRecord(
            now: now, lastIncidentAt: lastWarningAt, largestDelay: largestWarning, delay: delay,
            cooldown: thresholds.warningIncidentCooldownSeconds,
            newWorstMargin: thresholds.warningNewWorstMarginMilliseconds / 1_000
        ) else { return false }
        lastWarningAt = now
        largestWarning = max(largestWarning, delay)
        return true
    }
}

#if canImport(UIKit)
private final class FrameHitchMonitor: NSObject {
    private let runtime: PerformanceRuntime
    private let thresholds: PerformanceThresholds
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?

    init(runtime: PerformanceRuntime, thresholds: PerformanceThresholds) {
        self.runtime = runtime
        self.thresholds = thresholds
    }

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(fired(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
    }

    @objc private func fired(_ link: CADisplayLink) {
        guard let previous = lastTimestamp else {
            lastTimestamp = link.timestamp
            return
        }
        let milliseconds = max(0, (link.timestamp - previous) * 1_000)
        lastTimestamp = link.timestamp
        guard milliseconds >= thresholds.hitchMilliseconds else { return }
        runtime.recordHitch(milliseconds: milliseconds)
        if milliseconds >= thresholds.severeHitchMilliseconds {
            runtime.emit(.init(level: .warning, message: "frame hitch \(Int(milliseconds))ms context=\(runtime.snapshot().context.name)"))
        }
    }
}
#endif
