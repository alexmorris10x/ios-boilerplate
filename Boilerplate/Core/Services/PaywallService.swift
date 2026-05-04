import Foundation

/// Provider-neutral subscription and paywall facade.
/// Wire RevenueCat, StoreKit, Superwall, or another provider behind this boundary in derived apps.
@MainActor
@Observable
final class PaywallService {
    // MARK: - State

    private(set) var subscriptionStatus: SubscriptionStatus = .notConfigured
    private(set) var lastMessage: String?

    var isConfigured: Bool {
        false
    }

    var manageSubscriptionURL: URL {
        AppConstants.Support.manageSubscriptionsURL
    }

    // MARK: - Dependencies

    private let analyticsService: AnalyticsService?

    // MARK: - Initialization

    init(analyticsService: AnalyticsService? = nil) {
        self.analyticsService = analyticsService
    }

    // MARK: - Public Methods

    func refreshCustomerInfo() async {
        subscriptionStatus = .notConfigured
        lastMessage = "Connect a purchase provider to load subscription status."
    }

    func purchase(productId: String, placement: String) async throws {
        analyticsService?.track(.purchaseStarted(productId: productId, placement: placement))

        let error = PaywallError.notConfigured
        lastMessage = error.localizedDescription
        analyticsService?.track(.purchaseFailed(productId: productId, placement: placement, reason: error.localizedDescription))
        throw error
    }

    func restorePurchases() async throws {
        analyticsService?.track(.restorePurchasesStarted)

        let error = PaywallError.notConfigured
        lastMessage = error.localizedDescription
        analyticsService?.track(.restorePurchasesFailed(reason: error.localizedDescription))
        throw error
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
