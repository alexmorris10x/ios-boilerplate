import Foundation
import StoreKit

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

// MARK: - Positive StoreKit Access Evidence

/// A short-lived, positive-only continuity record. It is not a second purchase
/// owner and deliberately contains no account, receipt, JWS, or transaction ID.
struct VerifiedSubscriptionAccessEvidence: Codable, Equatable, Sendable {
    static let maximumCacheAge: TimeInterval = 24 * 60 * 60

    let productID: String
    let expirationDate: Date?
    let verifiedAt: Date

    func isUsable(
        mappedProductIDs: Set<String>,
        now: Date,
        maximumAge: TimeInterval = Self.maximumCacheAge
    ) -> Bool {
        guard mappedProductIDs.contains(productID),
              let expirationDate,
              expirationDate > now,
              verifiedAt <= now else { return false }
        return now.timeIntervalSince(verifiedAt) <= maximumAge
    }
}

enum PositiveSubscriptionAccessResult: Equatable, Sendable {
    case active(VerifiedSubscriptionAccessEvidence)
    case inactive
    case uncertain
}

/// Optional positive access source used only to reconcile a verified Apple
/// subscription that is missing from RevenueCat's current customer record.
@MainActor
protocol PositiveSubscriptionAccessProviding: AnyObject {
    func cachedVerifiedAccess(now: Date) -> VerifiedSubscriptionAccessEvidence?
    func refreshVerifiedAccess(now: Date) async -> PositiveSubscriptionAccessResult
    func accessUpdates() -> AsyncStream<Void>
}

extension PositiveSubscriptionAccessProviding {
    func accessUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

/// Reads StoreKit 2 only for verified positive continuity evidence. RevenueCat
/// remains the sole purchase and transaction-finishing owner.
@MainActor
final class StoreKitPositiveSubscriptionAccessProvider: PositiveSubscriptionAccessProviding {
    private let mappedProductIDs: Set<String>
    private let defaultsKey: String

    init(
        mappedProductIDs: Set<String>,
        defaultsKey: String = "Subscription.verifiedStoreKitAccess.v1"
    ) {
        self.mappedProductIDs = mappedProductIDs
        self.defaultsKey = defaultsKey
    }

    func cachedVerifiedAccess(now: Date = .now) -> VerifiedSubscriptionAccessEvidence? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let evidence = try? JSONDecoder().decode(
                VerifiedSubscriptionAccessEvidence.self,
                from: data
              ),
              evidence.isUsable(mappedProductIDs: mappedProductIDs, now: now) else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            Logger.shared.app("[Subscription] storekit_evidence cache=miss", level: .info)
            return nil
        }

        Logger.shared.app(
            "[Subscription] storekit_evidence cache=hit product_match=true " +
                "evidence_age_ms=\(Self.milliseconds(now.timeIntervalSince(evidence.verifiedAt)))",
            level: .info
        )
        return evidence
    }

    func refreshVerifiedAccess(now: Date = .now) async -> PositiveSubscriptionAccessResult {
        let startedAt = Date()
        var verifiedEvidence: VerifiedSubscriptionAccessEvidence?
        var mappedUnverified = false

        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard mappedProductIDs.contains(transaction.productID),
                      transaction.revocationDate == nil else { continue }
                if let expirationDate = transaction.expirationDate,
                   expirationDate <= now {
                    continue
                }
                verifiedEvidence = VerifiedSubscriptionAccessEvidence(
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    verifiedAt: now
                )
            case .unverified(let transaction, _):
                if mappedProductIDs.contains(transaction.productID) {
                    mappedUnverified = true
                }
            }
        }

        if let verifiedEvidence {
            if verifiedEvidence.isUsable(mappedProductIDs: mappedProductIDs, now: now),
               let data = try? JSONEncoder().encode(verifiedEvidence) {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            }
            Logger.shared.app(
                "[Subscription] storekit_scan result=active product_match=true " +
                    "latency_ms=\(Self.milliseconds(Date().timeIntervalSince(startedAt)))",
                level: .info
            )
            return .active(verifiedEvidence)
        }

        if mappedUnverified {
            Logger.shared.app(
                "[Subscription] storekit_scan result=uncertain mapped_unverified=true " +
                    "latency_ms=\(Self.milliseconds(Date().timeIntervalSince(startedAt)))",
                level: .warning
            )
            return .uncertain
        }

        UserDefaults.standard.removeObject(forKey: defaultsKey)
        Logger.shared.app(
            "[Subscription] storekit_scan result=inactive " +
                "latency_ms=\(Self.milliseconds(Date().timeIntervalSince(startedAt)))",
            level: .info
        )
        return .inactive
    }

    func accessUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task { @MainActor [mappedProductIDs] in
                for await result in StoreKit.Transaction.updates {
                    guard !Task.isCancelled else { break }
                    let productID: String
                    switch result {
                    case .verified(let transaction): productID = transaction.productID
                    case .unverified(let transaction, _): productID = transaction.productID
                    }
                    if mappedProductIDs.contains(productID) {
                        continuation.yield(())
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func milliseconds(_ interval: TimeInterval) -> Int {
        max(0, Int(interval * 1_000))
    }
}
