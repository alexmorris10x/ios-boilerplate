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
    private var refreshInFlight = false

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
        guard isConfigured else {
            subscriptionStatus = .notConfigured
            accessState = .notConfigured
            lastMessage = "Connect a purchase provider to load subscription status."
            return
        }

        guard !refreshInFlight else { return }
        refreshInFlight = true
        defer { refreshInFlight = false }

        do {
            apply(try await provider.refreshEntitlement())
        } catch {
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
        analyticsService?.track(.purchaseStarted(productId: productId, placement: placement))

        do {
            let snapshot = try await provider.purchase(productId: productId)
            apply(snapshot)
            analyticsService?.track(.purchaseCompleted(productId: productId, placement: placement))
        } catch {
            lastMessage = error.localizedDescription
            analyticsService?.track(.purchaseFailed(productId: productId, placement: placement, reason: error.localizedDescription))
            throw error
        }
    }

    func restorePurchases() async throws {
        analyticsService?.track(.restorePurchasesStarted)

        do {
            apply(try await provider.restorePurchases())
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
