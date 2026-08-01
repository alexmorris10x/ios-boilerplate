import SwiftUI

/// A bounded, recoverable launch state for installs with no cached entitlement.
/// It prevents both an indefinite blank spinner and an unverified free bypass.
struct EntitlementResolutionView: View {
    @Environment(PaywallService.self) private var paywallService

    @State private var isRetrying = false
    @State private var isRestoring = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: paywallService.accessState == .checking ? "checkmark.shield" : "wifi.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(paywallService.accessState == .checking ? "Checking Access" : "Access Check Needed")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if paywallService.accessState == .checking {
                ProgressView()
                    .controlSize(.large)
            } else {
                PrimaryButton(title: "Try Again", action: retry, isLoading: isRetrying)
                SecondaryButton(title: "Restore Purchases", action: restore, isLoading: isRestoring)
            }

            Spacer()
        }
        .padding(24)
    }

    private var message: String {
        if paywallService.accessState == .checking {
            return "This should only take a moment."
        }
        return paywallService.lastMessage ?? "Check your connection, then try again or restore an existing purchase."
    }

    private func retry() {
        isRetrying = true
        Task {
            await paywallService.refreshCustomerInfo()
            isRetrying = false
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            _ = try? await paywallService.restorePurchases()
            isRestoring = false
        }
    }
}

#Preview {
    EntitlementResolutionView()
        .environment(PaywallService())
}
