import Foundation

/// Decides when the app may ask for an App Store review.
/// The SwiftUI host owns the actual StoreKit prompt so this service stays testable.
@MainActor
@Observable
final class ReviewPromptService {
    // MARK: - Configuration

    struct Configuration: Equatable {
        var minimumSuccessfulActions = 3
        var cooldownDays = 90
    }

    // MARK: - State

    private(set) var pendingRequestID: UUID?
    private(set) var pendingReason: String?

    // MARK: - Dependencies

    private let storage: UserDefaults
    private let appVersion: String
    private let currentDate: () -> Date
    private let configuration: Configuration
    private let analyticsService: AnalyticsService?

    // MARK: - Initialization

    init(
        storage: UserDefaults = .standard,
        appVersion: String = AppConstants.appVersion,
        currentDate: @escaping () -> Date = Date.init,
        configuration: Configuration = Configuration(),
        analyticsService: AnalyticsService? = nil
    ) {
        self.storage = storage
        self.appVersion = appVersion
        self.currentDate = currentDate
        self.configuration = configuration
        self.analyticsService = analyticsService
    }

    // MARK: - Public Methods

    func recordSuccessfulAction(reason: String) {
        successfulActionCount += 1
        analyticsService?.track(.firstValueAction(reason))

        guard isEligibleForPrompt else { return }

        pendingReason = reason
        pendingRequestID = UUID()
        analyticsService?.track(.reviewPromptEligible(reason: reason))
    }

    func markPromptAttempted() {
        guard let pendingReason else { return }

        lastPromptDate = currentDate()
        lastPromptedVersion = appVersion
        analyticsService?.track(.reviewPromptRequested(reason: pendingReason))
        self.pendingReason = nil
        pendingRequestID = nil
    }

    func resetForTesting() {
        storage.removeObject(forKey: Keys.successfulActionCount)
        storage.removeObject(forKey: Keys.lastPromptDate)
        storage.removeObject(forKey: Keys.lastPromptedVersion)
        pendingReason = nil
        pendingRequestID = nil
    }

    var isEligibleForPrompt: Bool {
        successfulActionCount >= configuration.minimumSuccessfulActions &&
            lastPromptedVersion != appVersion &&
            isPastCooldown
    }

    // MARK: - Stored Values

    private var successfulActionCount: Int {
        get { storage.integer(forKey: Keys.successfulActionCount) }
        set { storage.set(newValue, forKey: Keys.successfulActionCount) }
    }

    private var lastPromptDate: Date? {
        get { storage.object(forKey: Keys.lastPromptDate) as? Date }
        set { storage.set(newValue, forKey: Keys.lastPromptDate) }
    }

    private var lastPromptedVersion: String? {
        get { storage.string(forKey: Keys.lastPromptedVersion) }
        set { storage.set(newValue, forKey: Keys.lastPromptedVersion) }
    }

    private var isPastCooldown: Bool {
        guard let lastPromptDate else { return true }

        let cooldownSeconds = TimeInterval(configuration.cooldownDays * 24 * 60 * 60)
        return currentDate().timeIntervalSince(lastPromptDate) >= cooldownSeconds
    }
}

// MARK: - Keys

private enum Keys {
    static let successfulActionCount = "reviewPrompt.successfulActionCount"
    static let lastPromptDate = "reviewPrompt.lastPromptDate"
    static let lastPromptedVersion = "reviewPrompt.lastPromptedVersion"
}
