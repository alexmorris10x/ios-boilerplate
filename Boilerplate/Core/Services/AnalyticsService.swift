import Foundation

/// Analytics service for tracking user events and app metrics
/// Provides a unified interface for multiple analytics providers
@Observable
final class AnalyticsService {
    // MARK: - Properties

    private var isEnabled: Bool
    private var userId: String?
    private var userProperties: [String: Any] = [:]

    // MARK: - Initialization

    init() {
        isEnabled = AppEnvironment.current.analyticsEnabled
    }

    // MARK: - Configuration

    /// Enable or disable analytics tracking
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Logger.shared.app("Analytics \(enabled ? "enabled" : "disabled")", level: .info)
    }

    /// Set the current user ID for analytics
    func setUserId(_ id: String?) {
        userId = id

        guard isEnabled else { return }

        // TODO: Set user ID in analytics provider
        // Example: Analytics.setUserId(id)
        Logger.shared.app("Analytics user ID set: \(id ?? "nil")", level: .debug)
    }

    /// Set user properties for segmentation
    func setUserProperty(_ value: Any?, forKey key: String) {
        if let value {
            userProperties[key] = value
        } else {
            userProperties.removeValue(forKey: key)
        }

        guard isEnabled else { return }

        // TODO: Set user property in analytics provider
        // Example: Analytics.setUserProperty(value, forKey: key)
    }

    // MARK: - Event Tracking

    /// Track an analytics event
    func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }

        Logger.shared.app("Track event: \(event.name) \(event.properties)", level: .debug)

        // TODO: Send event to analytics provider
        // Example: Analytics.track(event.name, properties: event.properties)
    }

    /// Track a screen view
    func trackScreen(_ screenName: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }

        var eventProperties = properties
        eventProperties["screen_name"] = screenName

        Logger.shared.app("Track screen: \(screenName)", level: .debug)

        // TODO: Send screen view to analytics provider
        // Example: Analytics.screen(screenName, properties: eventProperties)
    }

    // MARK: - Timing

    /// Track the duration of an operation
    func trackTiming(category: String, variable: String, duration: TimeInterval) {
        guard isEnabled else { return }

        let event = AnalyticsEvent(
            name: "timing",
            properties: [
                "category": category,
                "variable": variable,
                "duration_ms": Int(duration * 1000)
            ]
        )

        track(event)
    }

    /// Create a timing tracker that automatically measures duration
    func startTiming(category: String, variable: String) -> TimingTracker {
        TimingTracker(analytics: self, category: category, variable: variable)
    }

    // MARK: - Error Tracking

    /// Track an error event
    func trackError(_ error: Error, context: String? = nil) {
        guard isEnabled else { return }

        var properties: [String: Any] = [
            "error_description": error.localizedDescription,
            "error_type": String(describing: type(of: error))
        ]

        if let context {
            properties["context"] = context
        }

        let event = AnalyticsEvent(name: "error", properties: properties)
        track(event)
    }
}

// MARK: - Analytics Event

struct AnalyticsEvent {
    let name: String
    let properties: [String: Any]

    init(name: String, properties: [String: Any] = [:]) {
        self.name = name
        self.properties = properties
    }
}

// MARK: - Predefined Events

extension AnalyticsEvent {
    // Authentication events
    static func signUp(method: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "sign_up", properties: ["method": method])
    }

    static func login(method: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "login", properties: ["method": method])
    }

    static let logout = AnalyticsEvent(name: "logout")

    // App lifecycle events
    static let appOpen = AnalyticsEvent(name: "app_open")

    static func appUpdate(previousVersion: String, currentVersion: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "app_update", properties: [
            "previous_version": previousVersion,
            "current_version": currentVersion
        ])
    }

    // Onboarding events
    static let onboardingStarted = AnalyticsEvent(name: "onboarding_started")
    static let onboardingCompleted = AnalyticsEvent(name: "onboarding_completed")

    static func firstValueAction(_ actionName: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "first_value_action", properties: ["action_name": actionName])
    }

    // Feature events
    static func featureUsed(_ featureName: String, properties: [String: Any] = [:]) -> AnalyticsEvent {
        var props = properties
        props["feature_name"] = featureName
        return AnalyticsEvent(name: "feature_used", properties: props)
    }

    // Monetization events
    static func paywallViewed(placement: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "paywall_viewed", properties: ["placement": placement])
    }

    static func purchaseStarted(productId: String, placement: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "purchase_started", properties: [
            "product_id": productId,
            "placement": placement
        ])
    }

    static func purchaseCompleted(productId: String, placement: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "purchase_completed", properties: [
            "product_id": productId,
            "placement": placement
        ])
    }

    static func purchaseFailed(productId: String, placement: String, reason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "purchase_failed", properties: [
            "product_id": productId,
            "placement": placement,
            "reason": reason
        ])
    }

    static let restorePurchasesStarted = AnalyticsEvent(name: "restore_purchases_started")
    static let restorePurchasesCompleted = AnalyticsEvent(name: "restore_purchases_completed")

    static func restorePurchasesFailed(reason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "restore_purchases_failed", properties: ["reason": reason])
    }

    // Review prompt events
    static func reviewPromptEligible(reason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "review_prompt_eligible", properties: ["reason": reason])
    }

    static func reviewPromptRequested(reason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "review_prompt_requested", properties: ["reason": reason])
    }

    // Item events
    static func itemCreated(type: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "item_created", properties: ["item_type": type])
    }

    static func itemDeleted(type: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "item_deleted", properties: ["item_type": type])
    }

    // Settings events
    static func settingChanged(name: String, value: Any) -> AnalyticsEvent {
        AnalyticsEvent(name: "setting_changed", properties: [
            "setting_name": name,
            "setting_value": String(describing: value)
        ])
    }
}

// MARK: - Timing Tracker

final class TimingTracker {
    private let analytics: AnalyticsService
    private let category: String
    private let variable: String
    private let startTime: Date

    init(analytics: AnalyticsService, category: String, variable: String) {
        self.analytics = analytics
        self.category = category
        self.variable = variable
        self.startTime = Date()
    }

    func finish() {
        let duration = Date().timeIntervalSince(startTime)
        analytics.trackTiming(category: category, variable: variable, duration: duration)
    }
}
