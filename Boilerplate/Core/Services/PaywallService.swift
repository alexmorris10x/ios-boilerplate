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
    private let positiveAccessProvider: PositiveSubscriptionAccessProviding?
    private var providerSubscriptionStatus: SubscriptionStatus
    private var positiveAccessState: PositiveAccessState
    private var didStart = false
    private var accessRevision: UInt64 = 0
    private var refreshSequence: UInt64 = 0
    private var activeRefreshID: UInt64?
    private var refreshTask: Task<Void, Never>?
    private var entitlementUpdatesTask: Task<Void, Never>?
    private var positiveAccessUpdatesTask: Task<Void, Never>?
    private var isRefreshingPositiveAccess = false
    private var initialBudgetExpired = false
    private var lastAppliedRequestDate: Date?

    // MARK: - Initialization

    init(
        analyticsService: AnalyticsService? = nil,
        provider: PaywallProviding? = nil,
        positiveAccessProvider: PositiveSubscriptionAccessProviding? = nil
    ) {
        self.analyticsService = analyticsService
        self.provider = provider ?? UnconfiguredPaywallProvider()
        self.positiveAccessProvider = positiveAccessProvider

        let cachedPositiveAccess = positiveAccessProvider?.cachedVerifiedAccess(now: .now)
        positiveAccessState = cachedPositiveAccess == nil
            ? (positiveAccessProvider == nil ? .notUsed : .checking)
            : .active

        if self.provider.isConfigured {
            if let cached = self.provider.cachedEntitlement() {
                providerSubscriptionStatus = cached.status
                subscriptionStatus = cached.status.isPaidAccess || cachedPositiveAccess == nil
                    ? cached.status
                    : .active
                accessState = cached.status.isPaidAccess || cachedPositiveAccess != nil
                    ? .unlocked
                    : (positiveAccessProvider == nil ? .locked : .checking)
                lastMessage = nil
                lastAppliedRequestDate = cached.requestDate
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
                providerSubscriptionStatus = .free
                subscriptionStatus = .free
                if cachedPositiveAccess != nil {
                    subscriptionStatus = .active
                    accessState = .unlocked
                } else {
                    accessState = .checking
                }
                lastMessage = nil
                Logger.shared.app(
                    "[Subscription] decision trigger=cache revision=0 identity=\(self.provider.identityMode.rawValue) cache=miss previous=checking next=checking",
                    level: .info
                )
            }
        } else {
            providerSubscriptionStatus = .notConfigured
            if cachedPositiveAccess != nil {
                subscriptionStatus = .active
                accessState = .unlocked
                lastMessage = nil
            } else {
                subscriptionStatus = .notConfigured
                accessState = positiveAccessProvider == nil ? .notConfigured : .checking
                lastMessage = positiveAccessProvider == nil
                    ? PaywallError.notConfigured.localizedDescription
                    : nil
            }
        }
    }

    // MARK: - Access Resolution

    /// Start one update stream and an ordinary stale-aware refresh. A provider
    /// cache can unlock immediately; an unknown install becomes recoverable
    /// after the short launch budget without ever bypassing the paywall.
    func resolveInitialAccess(timeoutNanoseconds: UInt64 = 1_500_000_000) async {
        guard !didStart, isConfigured || positiveAccessProvider != nil else { return }
        didStart = true
        startEntitlementUpdatesIfNeeded()
        startPositiveAccessUpdatesIfNeeded()

        Task { @MainActor [weak self] in
            await self?.refreshAccess(trigger: "launch")
        }

        guard accessState == .checking else { return }

        do {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
        } catch {
            return
        }

        if accessState == .checking {
            let previous = accessState
            initialBudgetExpired = true
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

    func refreshAccess(trigger: String = "manual") async {
        async let revenueCat: Void = refreshCustomerInfo()
        async let positiveAccess: Void = refreshPositiveAccess(trigger: trigger)
        _ = await (revenueCat, positiveAccess)
    }

    /// Cancel the launch check and start a new request. Results from the
    /// replaced request are ignored even if the provider cannot cancel it.
    func retryCustomerInfo() async {
        initialBudgetExpired = false
        if accessState == .unavailable {
            accessState = .checking
        }
        async let revenueCat: Void = runRefresh(replacingInFlight: true)
        async let positiveAccess: Void = refreshPositiveAccess(trigger: "retry")
        _ = await (revenueCat, positiveAccess)
    }

    private func runRefresh(replacingInFlight: Bool) async {
        guard isConfigured else {
            providerSubscriptionStatus = .notConfigured
            recomputeEffectiveAccess()
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
            guard shouldApply(snapshot, trigger: "refresh") else { return }
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
                initialBudgetExpired = true
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
            guard accessState == .unlocked else {
                throw PaywallError.entitlementNotGranted
            }
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
            let accessGranted = accessState == .unlocked
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

    private func startPositiveAccessUpdatesIfNeeded() {
        guard positiveAccessUpdatesTask == nil,
              let positiveAccessProvider else { return }

        positiveAccessUpdatesTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await _ in positiveAccessProvider.accessUpdates() {
                guard !Task.isCancelled else { break }
                await refreshPositiveAccess(trigger: "transaction_update")
            }
        }
    }

    private func refreshPositiveAccess(trigger: String) async {
        guard let positiveAccessProvider else { return }
        guard !isRefreshingPositiveAccess else {
            Logger.shared.app(
                "[Subscription] storekit_scan trigger=\(trigger) result=skipped reason=in_flight",
                level: .debug
            )
            return
        }

        isRefreshingPositiveAccess = true
        defer { isRefreshingPositiveAccess = false }
        let previous = accessState
        let result = await positiveAccessProvider.refreshVerifiedAccess(now: .now)

        switch result {
        case .active:
            positiveAccessState = .active
        case .inactive:
            positiveAccessState = .inactive
        case .uncertain:
            if positiveAccessState != .active {
                positiveAccessState = .unavailable
                lastMessage = "We couldn't confirm Apple access yet. Try again or restore purchases."
            }
        }

        recomputeEffectiveAccess()
        Logger.shared.app(
            "[Subscription] storekit_decision trigger=\(trigger) result=\(positiveAccessState.logLabel) " +
                "previous=\(previous.logLabel) next=\(accessState.logLabel)",
            level: positiveAccessState == .unavailable ? .warning : .info
        )
    }

    private func invalidateOlderRefreshes() {
        accessRevision &+= 1
    }

    private func applyNewerAuthority(
        _ snapshot: EntitlementSnapshot,
        trigger: String,
        latencyMilliseconds: Int?
    ) {
        guard shouldApply(snapshot, trigger: trigger) else { return }
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
        if let requestDate = snapshot.requestDate,
           lastAppliedRequestDate.map({ requestDate > $0 }) ?? true {
            lastAppliedRequestDate = requestDate
        }
        providerSubscriptionStatus = snapshot.status
        recomputeEffectiveAccess()
        if accessState != .unavailable {
            lastMessage = nil
        }

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

    private func recomputeEffectiveAccess() {
        if providerSubscriptionStatus.isPaidAccess || positiveAccessState == .active {
            subscriptionStatus = providerSubscriptionStatus.isPaidAccess
                ? providerSubscriptionStatus
                : .active
            accessState = .unlocked
            return
        }

        subscriptionStatus = providerSubscriptionStatus

        if !isConfigured {
            switch positiveAccessState {
            case .checking:
                accessState = initialBudgetExpired ? .unavailable : .checking
            case .unavailable:
                accessState = .unavailable
            case .active:
                accessState = .unlocked
            case .inactive, .notUsed:
                accessState = .notConfigured
                lastMessage = PaywallError.notConfigured.localizedDescription
            }
            return
        }

        switch positiveAccessState {
        case .checking:
            accessState = initialBudgetExpired ? .unavailable : .checking
        case .unavailable:
            accessState = .unavailable
        case .active:
            accessState = .unlocked
        case .inactive, .notUsed:
            accessState = .locked
        }
    }

    /// RevenueCat's update stream starts with its last known value. Ignore that
    /// duplicate (and any older snapshot) so it cannot invalidate a genuinely
    /// newer refresh, purchase, or restore result.
    private func shouldApply(_ snapshot: EntitlementSnapshot, trigger: String) -> Bool {
        guard let requestDate = snapshot.requestDate,
              let lastAppliedRequestDate,
              requestDate <= lastAppliedRequestDate else {
            return true
        }

        let requestAge = max(0, Int(Date().timeIntervalSince(requestDate)))
        Logger.shared.app(
            "[Subscription] decision trigger=\(trigger) revision=\(accessRevision) result=ignored " +
                "reason=not_newer request_age_seconds=\(requestAge)",
            level: .debug
        )
        return false
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

private enum PositiveAccessState: Equatable {
    case notUsed
    case checking
    case active
    case inactive
    case unavailable

    var logLabel: String {
        switch self {
        case .notUsed: "not_used"
        case .checking: "checking"
        case .active: "active"
        case .inactive: "inactive"
        case .unavailable: "unavailable"
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
