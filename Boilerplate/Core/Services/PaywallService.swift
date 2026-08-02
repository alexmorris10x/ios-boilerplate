import Foundation

/// App-level subscription state machine.
///
/// RevenueCat owns the authoritative access decision. The first frame uses its
/// persisted cache, ordinary refreshes replace that evidence only on success,
/// and catalog failures remain independent from access.
@MainActor
@Observable
final class PaywallService {
    // MARK: - State

    private(set) var accessState: AccessGateState
    private(set) var subscriptionStatus: SubscriptionStatus
    private(set) var lastMessage: String?
    private(set) var offer: SubscriptionOfferSnapshot?
    private(set) var isLoadingOffer = false
    private(set) var offerMessage: String?

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
    private var entitlementUpdatesTask: Task<Void, Never>?

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
                lastMessage = nil
                Self.logTransition(
                    snapshot: cached,
                    trigger: "cache",
                    revision: 0,
                    identityMode: self.provider.identityMode,
                    previous: .checking,
                    next: accessState,
                    latencyMilliseconds: 0
                )
            } else {
                subscriptionStatus = .free
                accessState = .checking
                lastMessage = nil
                Logger.shared.app(
                    "[Subscription] decision trigger=cache revision=0 identity=\(self.provider.identityMode.rawValue) cache=miss previous=checking next=checking",
                    level: .info
                )
            }
        } else {
            subscriptionStatus = .notConfigured
            accessState = .notConfigured
            lastMessage = PaywallError.notConfigured.localizedDescription
        }
    }

    // MARK: - Access Resolution

    /// Start one update stream and an ordinary stale-aware refresh. A provider
    /// cache can unlock immediately; an unknown install becomes recoverable
    /// after the short launch budget without ever bypassing the paywall.
    func resolveInitialAccess(timeoutNanoseconds: UInt64 = 1_500_000_000) async {
        guard isConfigured, !didStart else { return }
        didStart = true
        startEntitlementUpdatesIfNeeded()

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
            let previous = accessState
            accessState = .unavailable
            lastMessage = "We couldn't confirm access yet. Check your connection and try again."
            Logger.shared.app(
                "[Subscription] decision trigger=launch_budget revision=\(accessRevision) identity=\(provider.identityMode.rawValue) previous=\(previous.logLabel) next=\(accessState.logLabel)",
                level: .warning
            )
        }
    }

    func refreshCustomerInfo() async {
        await runRefresh(replacingInFlight: false)
    }

    /// Cancel the launch check and start a new request. Results from the
    /// replaced request are ignored even if the provider cannot cancel it.
    func retryCustomerInfo() async {
        await runRefresh(replacingInFlight: true)
    }

    private func runRefresh(replacingInFlight: Bool) async {
        guard isConfigured else {
            subscriptionStatus = .notConfigured
            accessState = .notConfigured
            lastMessage = PaywallError.notConfigured.localizedDescription
            return
        }

        startEntitlementUpdatesIfNeeded()

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

        Logger.shared.app(
            "[Subscription] refresh start request=\(refreshID) revision=\(revision) identity=\(provider.identityMode.rawValue)",
            level: .info
        )

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
        let startedAt = Date()

        do {
            let snapshot = try await provider.refreshEntitlement()
            guard !Task.isCancelled,
                  activeRefreshID == refreshID,
                  accessRevision == revision else {
                Logger.shared.app(
                    "[Subscription] refresh ignored request=\(refreshID) revision=\(revision) reason=stale",
                    level: .debug
                )
                return
            }
            apply(
                snapshot,
                trigger: "refresh",
                revision: revision,
                latencyMilliseconds: Self.milliseconds(since: startedAt)
            )
        } catch {
            guard !Task.isCancelled,
                  activeRefreshID == refreshID,
                  accessRevision == revision else { return }

            lastMessage = "We couldn't refresh your access. Your last confirmed status is unchanged."
            Self.logProviderError(error, operation: "refresh", revision: revision)

            // A transport failure is not proof that a paid customer lost access.
            // Preserve cached locked or unlocked decisions. Only an unknown
            // install moves to the recoverable unavailable state.
            if accessState == .checking {
                accessState = .unavailable
            }
        }
    }

    // MARK: - Offer

    func loadOffer(productId: String) async {
        guard isConfigured else {
            offer = nil
            offerMessage = PaywallError.notConfigured.localizedDescription
            return
        }
        guard !isLoadingOffer else { return }

        isLoadingOffer = true
        offerMessage = nil
        defer { isLoadingOffer = false }

        let startedAt = Date()
        do {
            let loadedOffer = try await provider.loadOffer(productId: productId)
            guard loadedOffer.productID == productId else {
                throw PaywallError.offerUnavailable
            }
            offer = loadedOffer
            Logger.shared.app(
                "[Subscription] offer result=loaded product_match=true eligibility=\(loadedOffer.eligibility.rawValue) latency_ms=\(Self.milliseconds(since: startedAt))",
                level: .info
            )
        } catch {
            offer = nil
            offerMessage = PaywallError.offerUnavailable.localizedDescription
            Self.logProviderError(error, operation: "offer", revision: accessRevision)
        }
    }

    // MARK: - Purchase And Restore

    func purchase(productId: String, placement: String) async throws {
        invalidateOlderRefreshes()
        let revision = accessRevision
        let startedAt = Date()
        analyticsService?.track(.purchaseStarted(productId: productId, placement: placement))

        do {
            let snapshot = try await provider.purchase(productId: productId)
            guard snapshot.status.isPaidAccess else {
                throw PaywallError.entitlementNotGranted
            }

            applyNewerAuthority(
                snapshot,
                trigger: "purchase",
                latencyMilliseconds: Self.milliseconds(since: startedAt)
            )
            analyticsService?.track(.purchaseCompleted(productId: productId, placement: placement))
        } catch {
            lastMessage = Self.purchaseMessage(for: error)
            let reason = Self.safeErrorReason(error)
            analyticsService?.track(.purchaseFailed(productId: productId, placement: placement, reason: reason))
            Self.logProviderError(error, operation: "purchase", revision: revision)
            throw error
        }
    }

    /// Returns `true` only when the provider's restore result contains the
    /// required active entitlement.
    @discardableResult
    func restorePurchases() async throws -> Bool {
        invalidateOlderRefreshes()
        let revision = accessRevision
        let startedAt = Date()
        analyticsService?.track(.restorePurchasesStarted)

        do {
            let snapshot = try await provider.restorePurchases()
            applyNewerAuthority(
                snapshot,
                trigger: "restore",
                latencyMilliseconds: Self.milliseconds(since: startedAt)
            )
            let accessGranted = snapshot.status.isPaidAccess
            analyticsService?.track(.restorePurchasesCompleted)
            return accessGranted
        } catch {
            lastMessage = "We couldn't restore purchases. Check your connection and try again."
            let reason = Self.safeErrorReason(error)
            analyticsService?.track(.restorePurchasesFailed(reason: reason))
            Self.logProviderError(error, operation: "restore", revision: revision)
            throw error
        }
    }

    /// Apply provider-stream updates without starting a second fetch.
    func receiveEntitlementUpdate(_ snapshot: EntitlementSnapshot) {
        applyNewerAuthority(snapshot, trigger: "stream", latencyMilliseconds: nil)
    }

    private func startEntitlementUpdatesIfNeeded() {
        guard entitlementUpdatesTask == nil else { return }

        entitlementUpdatesTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await snapshot in provider.entitlementUpdates() {
                guard !Task.isCancelled else { break }
                receiveEntitlementUpdate(snapshot)
            }
        }
    }

    private func invalidateOlderRefreshes() {
        accessRevision &+= 1
    }

    private func applyNewerAuthority(
        _ snapshot: EntitlementSnapshot,
        trigger: String,
        latencyMilliseconds: Int?
    ) {
        accessRevision &+= 1
        apply(
            snapshot,
            trigger: trigger,
            revision: accessRevision,
            latencyMilliseconds: latencyMilliseconds
        )
    }

    private func apply(
        _ snapshot: EntitlementSnapshot,
        trigger: String,
        revision: UInt64,
        latencyMilliseconds: Int?
    ) {
        let previous = accessState
        subscriptionStatus = snapshot.status
        accessState = snapshot.status.isPaidAccess ? .unlocked : .locked
        lastMessage = nil

        Self.logTransition(
            snapshot: snapshot,
            trigger: trigger,
            revision: revision,
            identityMode: provider.identityMode,
            previous: previous,
            next: accessState,
            latencyMilliseconds: latencyMilliseconds
        )
    }

    // MARK: - Privacy-Safe Diagnostics

    private static func logTransition(
        snapshot: EntitlementSnapshot,
        trigger: String,
        revision: UInt64,
        identityMode: SubscriptionIdentityMode,
        previous: AccessGateState,
        next: AccessGateState,
        latencyMilliseconds: Int?
    ) {
        let requestAge = snapshot.requestDate.map {
            String(max(0, Int(Date().timeIntervalSince($0))))
        } ?? "unknown"
        let environment = snapshot.isSandbox.map { $0 ? "sandbox" : "production" } ?? "unknown"
        let latency = latencyMilliseconds.map(String.init) ?? "unknown"

        Logger.shared.app(
            "[Subscription] decision trigger=\(trigger) revision=\(revision) identity=\(identityMode.rawValue) " +
                "request_age_seconds=\(requestAge) entitlement_present=\(snapshot.entitlementPresent) " +
                "active=\(snapshot.status.isPaidAccess) period=\(snapshot.periodType ?? "unknown") " +
                "environment=\(environment) verification=\(snapshot.verification ?? "unknown") " +
                "previous=\(previous.logLabel) next=\(next.logLabel) latency_ms=\(latency)",
            level: .info
        )
    }

    private static func logProviderError(_ error: Error, operation: String, revision: UInt64) {
        Logger.shared.app(
            "[Subscription] operation=\(operation) revision=\(revision) result=error reason=\(safeErrorReason(error))",
            level: .error
        )
    }

    private static func safeErrorReason(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain):\(nsError.code)"
    }

    private static func purchaseMessage(for error: Error) -> String {
        switch error {
        case PaywallError.purchaseCancelled:
            return PaywallError.purchaseCancelled.localizedDescription
        case PaywallError.entitlementNotGranted:
            return PaywallError.entitlementNotGranted.localizedDescription
        case PaywallError.offerUnavailable:
            return PaywallError.offerUnavailable.localizedDescription
        case PaywallError.notConfigured:
            return PaywallError.notConfigured.localizedDescription
        default:
            return "The purchase couldn't be completed. No access was changed."
        }
    }

    private static func milliseconds(since start: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(start) * 1_000))
    }
}

// MARK: - Access Gate State

enum AccessGateState: Equatable {
    case checking
    case unlocked
    case locked
    case unavailable
    case notConfigured

    fileprivate var logLabel: String {
        switch self {
        case .checking: "checking"
        case .unlocked: "unlocked"
        case .locked: "locked"
        case .unavailable: "unavailable"
        case .notConfigured: "not_configured"
        }
    }
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
        case .notConfigured: "Not Configured"
        case .free: "Free"
        case .trial: "Trial"
        case .active: "Active"
        case .expired: "Expired"
        }
    }

    var planName: String {
        switch self {
        case .notConfigured: "Not Configured"
        case .free: "Free"
        case .trial: "Trial"
        case .active: "Pro"
        case .expired: "Expired"
        }
    }

    var accessDescription: String {
        switch self {
        case .notConfigured: "Connect Provider"
        case .free: "No Active Purchase"
        case .trial: "Trial Active"
        case .active: "Active"
        case .expired: "Expired"
        }
    }

    var isPaidAccess: Bool {
        self == .trial || self == .active
    }
}

// MARK: - Paywall Error

enum PaywallError: Error, LocalizedError, Equatable {
    case notConfigured
    case offerUnavailable
    case purchaseCancelled
    case entitlementNotGranted
    case purchaseFailed(String)
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Purchases are unavailable in this build."
        case .offerUnavailable:
            return "The subscription option is temporarily unavailable. Try again shortly."
        case .purchaseCancelled:
            return "Purchase cancelled."
        case .entitlementNotGranted:
            return "Apple completed the purchase, but access was not confirmed. Try Restore Purchases."
        case .purchaseFailed(let message):
            return message
        case .restoreFailed(let message):
            return message
        }
    }
}
