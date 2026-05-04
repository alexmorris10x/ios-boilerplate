import SwiftUI

/// Example paywall shell. Derived apps can keep the interface and replace PaywallService internals.
struct PaywallView: View {
    let placement: String

    @Environment(PaywallService.self) private var paywallService
    @Environment(AnalyticsService.self) private var analyticsService
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var message: String?

    private let defaultProductId = "pro_yearly"

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Unlock Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Connect RevenueCat, StoreKit, or Superwall behind PaywallService to make this screen live.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Remote offerings and pricing", systemImage: "checkmark.circle")
                Label("Restore purchases", systemImage: "checkmark.circle")
                Label("Subscription status in Settings", systemImage: "checkmark.circle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium))

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            PrimaryButton(title: "Start Free Trial", action: {
                purchase()
            }, isLoading: isPurchasing)

            SecondaryButton(title: "Restore Purchases", action: {
                restore()
            }, isLoading: isRestoring)

            Button("Not Now") {
                dismiss()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Pro")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            analyticsService.track(.paywallViewed(placement: placement))
        }
    }

    private func purchase() {
        isPurchasing = true
        message = nil

        Task {
            do {
                try await paywallService.purchase(productId: defaultProductId, placement: placement)
                message = "Purchase completed."
            } catch {
                message = error.localizedDescription
            }
            isPurchasing = false
        }
    }

    private func restore() {
        isRestoring = true
        message = nil

        Task {
            do {
                try await paywallService.restorePurchases()
                message = "Purchases restored."
            } catch {
                message = error.localizedDescription
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
