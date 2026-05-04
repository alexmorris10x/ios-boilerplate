import SwiftUI

/// Settings-ready subscription status surface.
struct SubscriptionStatusView: View {
    @Environment(PaywallService.self) private var paywallService

    @State private var isRestoring = false
    @State private var message: String?

    var body: some View {
        Section("Subscription") {
            LabeledContent("Status", value: paywallService.subscriptionStatus.displayName)

            Link(destination: paywallService.manageSubscriptionURL) {
                Label("Manage Subscription", systemImage: "creditcard")
            }

            Button {
                restore()
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
            }
            .disabled(isRestoring)

            if isRestoring {
                ProgressView("Restoring purchases...")
            }

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
    List {
        SubscriptionStatusView()
    }
    .environment(PaywallService())
}
