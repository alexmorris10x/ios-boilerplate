import Foundation

/// Provider result used by the app-level access gate.
///
/// RevenueCat adapters should build this from `CustomerInfo`, including
/// `Purchases.shared.cachedCustomerInfo` for the synchronous launch snapshot.
struct EntitlementSnapshot: Equatable {
    let status: SubscriptionStatus
}

/// Provider boundary for subscription access, purchase, and restore behavior.
///
/// Keep RevenueCat or StoreKit types inside the concrete adapter so the rest of
/// the app has one deterministic access state machine.
@MainActor
protocol PaywallProviding: AnyObject {
    var isConfigured: Bool { get }

    /// Return the provider's persisted, previously verified entitlement without
    /// waiting for the network. Return `nil` when this install has no snapshot.
    func cachedEntitlement() -> EntitlementSnapshot?

    /// Return current entitlement information using the provider's normal
    /// cache policy. Do not force a network-only fetch during ordinary launch.
    func refreshEntitlement() async throws -> EntitlementSnapshot

    func purchase(productId: String) async throws -> EntitlementSnapshot
    func restorePurchases() async throws -> EntitlementSnapshot
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
