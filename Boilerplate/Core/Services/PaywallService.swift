import Foundation

/// Provider-neutral subscription and paywall facade.
/// Wire RevenueCat, StoreKit, Superwall, or another provider behind this boundary in derived apps.
@MainActor
@Observable
final class PaywallService {
    // MARK: - State

    private(set) var accessState: AccessGateState
    private(set) var subscriptionStatus: SubscriptionStatus
    private(set) var lastMessage: String?

    var isConfigured: Bool {
        provider.isConfigured
    }

    var manageSubscriptionURL: URL {
        AppConstants.Support.manageSubscriptionsURL
    }

    // MARK: - Dependencies

    private let analyticsService: AnalyticsService?
    private let provider: PaywallProviding
    private var didStart = false
    private var accessRevision: UInt64 = 0
    private var refreshSequence: UInt64 = 0
    private var activeRefreshID: UInt64?
    private var refreshTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        analyticsService: AnalyticsService? = nil,
        provider: PaywallProviding? = nil
    ) {
        self.analyticsService = analyticsService
        self.provider = provider ?? UnconfiguredPaywallProvider()

        if self.provider.isConfigured {
            if let cached = self.provider.cachedEntitlement() {
                subscriptionStatus = cached.status
                accessState = cached.status.isPaidAccess ? .unlocked : .locked
            } else {
                subscriptionStatus = .free
                accessState = .checking
            }
        } else {
            subscriptionStatus = .notConfigured
            accessState = .notConfigured
        }
    }

    // MARK: - Public Methods

    /// Starts entitlement resolution without holding the first frame on a
    /// network request. A provider cache can unlock immediately; an unknown
    /// install becomes a recoverable state after the short launch budget.
    func resolveInitialAccess(timeoutNanoseconds: UInt64 = 1_500_000_000) async {
        guard isConfigured, !didStart else { return }
        didStart = true

        Task { @MainActor [weak self] in
            await self?.refreshCustomerInfo()
        }

        guard accessState == .checking else { return }

        do {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
        } catch {
            return
        }

        if accessState == .checking {
            accessState = .unavailable
            lastMessage = "We couldn't confirm access yet. Check your connection and try again."
        }
    }

    func refreshCustomerInfo() async {
        await runRefresh(replacingInFlight: false)
    }

    /// Cancels the launch check and starts a fresh provider request. Results
    /// from the replaced request are ignored even if its provider does not
    /// cooperate with task cancellation.
    func retryCustomerInfo() async {
        await runRefresh(replacingInFlight: true)
    }

    private func runRefresh(replacingInFlight: Bool) async {
        guard isConfigured else {
            subscriptionStatus = .notConfigured
            accessState = .notConfigured
            lastMessage = "Connect a purchase provider to load subscription status."
            return
        }

        if !replacingInFlight, let refreshTask {
            await refreshTask.value
            return
        }

        if replacingInFlight {
            refreshTask?.cancel()
            accessRevision &+= 1
        }

        refreshSequence &+= 1
        let refreshID = refreshSequence
        let revision = accessRevision
        activeRefreshID = refreshID

        let task = Task { @MainActor [weak self] () -> Void in
            guard let self else { return }
            await self.performRefresh(refreshID: refreshID, revision: revision)
        }
        refreshTask = task
        await task.value

        if activeRefreshID == refreshID {
            activeRefreshID = nil
            refreshTask = nil
        }
    }

    private func performRefresh(refreshID: UInt64, revision: UInt64) async {
        do {
            let snapshot = try await provider.refreshEntitlement()
            guard !Task.isCancelled,
                  activeRefreshID == refreshID,
                  accessRevision == revision else { return }
            apply(snapshot)
        } catch {
            guard !Task.isCancelled,
                  activeRefreshID == refreshID,
                  accessRevision == revision else { return }
            lastMessage = error.localizedDescription

            // A transport failure is not proof that a paid customer lost access.
            // Preserve any cached locked or unlocked decision. Only an unknown
            // install moves to the recoverable unavailable state.
            if accessState == .checking {
                accessState = .unavailable
            }
        }
    }

    func purchase(productId: String, placement: String) async throws {
        invalidateOlderRefreshes()
        analyticsService?.track(.purchaseStarted(productId: productId, placement: placement))

        do {
            let snapshot = try await provider.purchase(productId: productId)
            applyNewerAuthority(snapshot)
            analyticsService?.track(.purchaseCompleted(productId: productId, placement: placement))
        } catch {
            lastMessage = error.localizedDescription
            analyticsService?.track(.purchaseFailed(productId: productId, placement: placement, reason: error.localizedDescription))
            throw error
        }
    }

    func restorePurchases() async throws {
        invalidateOlderRefreshes()
        analyticsService?.track(.restorePurchasesStarted)

        do {
            applyNewerAuthority(try await provider.restorePurchases())
            analyticsService?.track(.restorePurchasesCompleted)
        } catch {
            lastMessage = error.localizedDescription
            analyticsService?.track(.restorePurchasesFailed(reason: error.localizedDescription))
            throw error
        }
    }

    /// Apply provider-stream updates without starting a second fetch from an
    /// entitlement callback.
    func receiveEntitlementUpdate(_ snapshot: EntitlementSnapshot) {
        applyNewerAuthority(snapshot)
    }

    private func invalidateOlderRefreshes() {
        accessRevision &+= 1
    }

    private func applyNewerAuthority(_ snapshot: EntitlementSnapshot) {
        accessRevision &+= 1
        apply(snapshot)
    }

    private func apply(_ snapshot: EntitlementSnapshot) {
        subscriptionStatus = snapshot.status
        accessState = snapshot.status.isPaidAccess ? .unlocked : .locked
        lastMessage = nil
    }
}

// MARK: - Access Gate State

enum AccessGateState: Equatable {
    case checking
    case unlocked
    case locked
    case unavailable
    case notConfigured
}

// MARK: - Subscription Status

enum SubscriptionStatus: String, CaseIterable, Equatable {
    case notConfigured
    case free
    case trial
    case active
    case expired

    var displayName: String {
        switch self {
        case .notConfigured:
            return "Not Configured"
        case .free:
            return "Free"
        case .trial:
            return "Trial"
        case .active:
            return "Active"
        case .expired:
            return "Expired"
        }
    }

    var planName: String {
        switch self {
        case .notConfigured:
            return "Not Configured"
        case .free:
            return "Free"
        case .trial:
            return "Trial"
        case .active:
            return "Pro"
        case .expired:
            return "Expired"
        }
    }

    var accessDescription: String {
        switch self {
        case .notConfigured:
            return "Connect Provider"
        case .free:
            return "No Active Purchase"
        case .trial:
            return "Trial Active"
        case .active:
            return "Active"
        case .expired:
            return "Expired"
        }
    }

    var isPaidAccess: Bool {
        self == .trial || self == .active
    }
}

// MARK: - Paywall Error

enum PaywallError: Error, LocalizedError, Equatable {
    case notConfigured
    case purchaseFailed(String)
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Purchases are not configured yet. Connect RevenueCat, StoreKit, or another purchase provider."
        case .purchaseFailed(let message):
            return message
        case .restoreFailed(let message):
            return message
        }
    }
}
