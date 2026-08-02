import Foundation

enum SubscriptionIdentityMode: String, Equatable {
    case anonymous
    case accountLinked
    case unknown
}

enum SubscriptionTrialEligibility: String, Equatable {
    case eligible
    case ineligible
    case noOffer
    case unknown
}

struct SubscriptionOfferSnapshot: Equatable {
    let productID: String
    let localizedPrice: String
    let billingPeriodLabel: String
    let trialLabel: String?
    let eligibility: SubscriptionTrialEligibility
}

/// Provider result used by the app-level access gate.
///
/// The diagnostic fields are deliberately privacy-safe. Never add app-user
/// IDs, receipt data, JWS payloads, or transaction identifiers here.
struct EntitlementSnapshot: Equatable {
    let status: SubscriptionStatus
    let requestDate: Date?
    let entitlementPresent: Bool
    let isSandbox: Bool?
    let periodType: String?
    let verification: String?

    init(
        status: SubscriptionStatus,
        requestDate: Date? = nil,
        entitlementPresent: Bool? = nil,
        isSandbox: Bool? = nil,
        periodType: String? = nil,
        verification: String? = nil
    ) {
        self.status = status
        self.requestDate = requestDate
        self.entitlementPresent = entitlementPresent ?? (status != .free && status != .notConfigured)
        self.isSandbox = isSandbox
        self.periodType = periodType
        self.verification = verification
    }
}

/// One boundary for access, catalog, purchase, restore, and provider updates.
/// RevenueCat owns purchase processing and transaction completion in the
/// boilerplate implementation.
@MainActor
protocol PaywallProviding: AnyObject {
    var isConfigured: Bool { get }
    var identityMode: SubscriptionIdentityMode { get }

    /// Return the provider's persisted, previously verified entitlement without
    /// waiting for the network. Return `nil` when this install has no snapshot.
    func cachedEntitlement() -> EntitlementSnapshot?

    /// Use the provider's normal stale-aware cache policy. Do not force a
    /// network-only fetch during ordinary launch.
    func refreshEntitlement() async throws -> EntitlementSnapshot

    /// Offer loading is separate from access. A failed catalog must never lock
    /// an already-paid customer out of the app.
    func loadOffer(productId: String) async throws -> SubscriptionOfferSnapshot

    func purchase(productId: String) async throws -> EntitlementSnapshot
    func restorePurchases() async throws -> EntitlementSnapshot

    /// Consume one provider update stream. Do not fetch again from its callback.
    func entitlementUpdates() -> AsyncStream<EntitlementSnapshot>
}

extension PaywallProviding {
    var identityMode: SubscriptionIdentityMode { .unknown }

    func loadOffer(productId: String) async throws -> SubscriptionOfferSnapshot {
        throw PaywallError.offerUnavailable
    }

    func entitlementUpdates() -> AsyncStream<EntitlementSnapshot> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

@MainActor
final class UnconfiguredPaywallProvider: PaywallProviding {
    let isConfigured = false

    func cachedEntitlement() -> EntitlementSnapshot? {
        nil
    }

    func refreshEntitlement() async throws -> EntitlementSnapshot {
        throw PaywallError.notConfigured
    }

    func purchase(productId: String) async throws -> EntitlementSnapshot {
        throw PaywallError.notConfigured
    }

    func restorePurchases() async throws -> EntitlementSnapshot {
        throw PaywallError.notConfigured
    }
}
