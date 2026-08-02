import Foundation
import RevenueCat

struct RevenueCatSubscriptionConfiguration {
    let entitlementID: String
    let offeringID: String
    let packageID: String
    let productID: String
    let billingPeriodLabel: String
    let trialLabel: String

    static let app = RevenueCatSubscriptionConfiguration(
        entitlementID: AppConstants.Subscription.entitlementID,
        offeringID: AppConstants.Subscription.offeringID,
        packageID: AppConstants.Subscription.yearlyPackageID,
        productID: AppConstants.Subscription.yearlyProductID,
        billingPeriodLabel: AppConstants.Subscription.yearlyBillingPeriodLabel,
        trialLabel: AppConstants.Subscription.trialLabel
    )
}

/// Compiled RevenueCat reference adapter.
///
/// RevenueCat is the sole purchase owner. StoreKit must not independently
/// finish the same transactions or veto an active RevenueCat entitlement.
@MainActor
final class RevenueCatPaywallProvider: PaywallProviding {
    private let configuration: RevenueCatSubscriptionConfiguration
    private var purchasePackage: Package?

    private(set) var isConfigured = false

    var identityMode: SubscriptionIdentityMode {
        guard isConfigured else { return .unknown }
        return Purchases.shared.isAnonymous ? .anonymous : .accountLinked
    }

    init(configuration: RevenueCatSubscriptionConfiguration = .app) {
        self.configuration = configuration

        guard let apiKey = AppConstants.Subscription.revenueCatAPIKey else {
            Logger.shared.app(
                "[Subscription] configuration provider=revenuecat result=missing_public_key",
                level: .error
            )
            return
        }

        if !Purchases.isConfigured {
#if DEBUG
            Purchases.logLevel = .debug
#else
            Purchases.logLevel = .error
#endif
            Purchases.configure(withAPIKey: apiKey)
        }

        isConfigured = true
        Logger.shared.app(
            "[Subscription] configuration provider=revenuecat result=configured identity=\(identityMode.rawValue)",
            level: .info
        )
    }

    func cachedEntitlement() -> EntitlementSnapshot? {
        Purchases.shared.cachedCustomerInfo.map(snapshot(from:))
    }

    func refreshEntitlement() async throws -> EntitlementSnapshot {
        snapshot(from: try await Purchases.shared.customerInfo())
    }

    func loadOffer(productId: String) async throws -> SubscriptionOfferSnapshot {
        guard productId == configuration.productID else {
            throw PaywallError.offerUnavailable
        }

        let package = try await resolvePackage()
        let status = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            product: package.storeProduct
        )
        let eligibility = trialEligibility(from: status)

        return SubscriptionOfferSnapshot(
            productID: package.storeProduct.productIdentifier,
            localizedPrice: package.localizedPriceString,
            billingPeriodLabel: configuration.billingPeriodLabel,
            trialLabel: eligibility == .eligible ? configuration.trialLabel : nil,
            eligibility: eligibility
        )
    }

    func purchase(productId: String) async throws -> EntitlementSnapshot {
        guard productId == configuration.productID else {
            throw PaywallError.offerUnavailable
        }

        let package = try await resolvePackage()
        let result = try await Purchases.shared.purchase(package: package)
        guard !result.userCancelled else {
            throw PaywallError.purchaseCancelled
        }
        return snapshot(from: result.customerInfo)
    }

    func restorePurchases() async throws -> EntitlementSnapshot {
        snapshot(from: try await Purchases.shared.restorePurchases())
    }

    func entitlementUpdates() -> AsyncStream<EntitlementSnapshot> {
        AsyncStream { continuation in
            let task = Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                for await customerInfo in Purchases.shared.customerInfoStream {
                    guard !Task.isCancelled else { break }
                    continuation.yield(snapshot(from: customerInfo))
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func resolvePackage() async throws -> Package {
        if let purchasePackage {
            return purchasePackage
        }

        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.offering(identifier: configuration.offeringID) else {
            throw PaywallError.offerUnavailable
        }

        let candidate = offering.package(identifier: configuration.packageID)
            ?? offering.availablePackages.first {
                $0.storeProduct.productIdentifier == configuration.productID
            }

        guard let candidate,
              candidate.storeProduct.productIdentifier == configuration.productID else {
            throw PaywallError.offerUnavailable
        }

        purchasePackage = candidate
        return candidate
    }

    private func snapshot(from customerInfo: CustomerInfo) -> EntitlementSnapshot {
        let entitlement = customerInfo.entitlements[configuration.entitlementID]
        let status: SubscriptionStatus

        if entitlement?.isActive == true {
            status = entitlement?.periodType == .trial ? .trial : .active
        } else {
            status = entitlement == nil ? .free : .expired
        }

        return EntitlementSnapshot(
            status: status,
            requestDate: customerInfo.requestDate,
            entitlementPresent: entitlement != nil,
            isSandbox: entitlement?.isSandbox,
            periodType: entitlement.map { periodLabel($0.periodType) },
            verification: verificationLabel(customerInfo.entitlements.verification)
        )
    }

    private func trialEligibility(from status: IntroEligibilityStatus) -> SubscriptionTrialEligibility {
        switch status {
        case .eligible: .eligible
        case .ineligible: .ineligible
        case .noIntroOfferExists: .noOffer
        case .unknown: .unknown
        @unknown default: .unknown
        }
    }

    private func periodLabel(_ periodType: PeriodType) -> String {
        switch periodType {
        case .normal: "normal"
        case .intro: "intro"
        case .trial: "trial"
        case .prepaid: "prepaid"
        @unknown default: "unknown"
        }
    }

    private func verificationLabel(_ result: VerificationResult) -> String {
        switch result {
        case .notRequested: "not_requested"
        case .verified: "verified"
        case .verifiedOnDevice: "verified_on_device"
        case .failed: "failed"
        @unknown default: "unknown"
        }
    }
}
