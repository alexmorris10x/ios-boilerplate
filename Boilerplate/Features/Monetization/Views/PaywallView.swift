import SwiftUI

/// Eligibility-aware paywall backed by the exact RevenueCat offering package.
struct PaywallView: View {
    let placement: String
    var allowsDismissal = true

    @Environment(PaywallService.self) private var paywallService
    @Environment(AnalyticsService.self) private var analyticsService
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var message: String?

    private let productID = AppConstants.Subscription.yearlyProductID

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(headline)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("The complete app", systemImage: "checkmark.circle")
                Label("Restore on another device", systemImage: "checkmark.circle")
                Label("Manage through Apple", systemImage: "checkmark.circle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium))

            if let visibleMessage {
                Text(visibleMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            PrimaryButton(title: purchaseButtonTitle, action: purchase, isLoading: isPurchasing || paywallService.isLoadingOffer)
                .disabled(paywallService.offer == nil || isRestoring)

            SecondaryButton(title: "Restore Purchases", action: restore, isLoading: isRestoring)
                .disabled(isPurchasing)

            if allowsDismissal {
                Button("Not Now") {
                    dismiss()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Text(terms)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms", destination: AppConstants.Support.termsURL)
                Link("Privacy", destination: AppConstants.Support.privacyURL)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Pro")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            analyticsService.track(.paywallViewed(placement: placement))
        }
        .task {
            await paywallService.loadOffer(productId: productID)
        }
        .onChange(of: paywallService.accessState) { _, current in
            if current == .unlocked, allowsDismissal {
                dismiss()
            }
        }
    }

    private var visibleMessage: String? {
        message ?? paywallService.offerMessage
    }

    private var headline: String {
        guard let offer = paywallService.offer else { return "Unlock Pro" }
        if offer.eligibility == .eligible, let trialLabel = offer.trialLabel {
            return "Start Your \(trialLabel)"
        }
        return "Unlock Pro"
    }

    private var detail: String {
        guard let offer = paywallService.offer else {
            return "Loading the subscription option from Apple."
        }

        if offer.eligibility == .eligible, let trialLabel = offer.trialLabel {
            return "Use the complete app during your \(trialLabel.lowercased()), then continue for \(offer.localizedPrice) per \(offer.billingPeriodLabel)."
        }
        return "Get the complete app for \(offer.localizedPrice) per \(offer.billingPeriodLabel)."
    }

    private var purchaseButtonTitle: String {
        guard let offer = paywallService.offer else {
            return paywallService.isLoadingOffer ? "Loading Plan" : "Try Again"
        }

        if offer.eligibility == .eligible, let trialLabel = offer.trialLabel {
            return "Start \(trialLabel)"
        }
        return "Subscribe · \(offer.localizedPrice)"
    }

    private var terms: String {
        guard let offer = paywallService.offer else {
            return "Apple confirms the price and terms before purchase."
        }

        switch offer.eligibility {
        case .eligible:
            return "\(offer.trialLabel ?? "Introductory period"), then \(offer.localizedPrice) per \(offer.billingPeriodLabel). Renews automatically until canceled."
        case .ineligible, .noOffer:
            return "\(offer.localizedPrice) per \(offer.billingPeriodLabel). Renews automatically until canceled."
        case .unknown:
            return "\(offer.localizedPrice) per \(offer.billingPeriodLabel). Apple confirms eligibility and terms before purchase. Renews automatically until canceled."
        }
    }

    private func purchase() {
        guard paywallService.offer != nil else {
            Task { await paywallService.loadOffer(productId: productID) }
            return
        }

        isPurchasing = true
        message = nil

        Task {
            do {
                try await paywallService.purchase(productId: productID, placement: placement)
                message = "Pro is active."
            } catch {
                message = paywallService.lastMessage
            }
            isPurchasing = false
        }
    }

    private func restore() {
        isRestoring = true
        message = nil

        Task {
            do {
                let accessGranted = try await paywallService.restorePurchases()
                message = accessGranted ? "Pro is active." : "No active purchase was found."
            } catch {
                message = paywallService.lastMessage
            }
            isRestoring = false
        }
    }
}

#Preview {
    NavigationStack {
        PaywallView(placement: "preview")
    }
    .environment(PaywallService())
    .environment(AnalyticsService())
}
