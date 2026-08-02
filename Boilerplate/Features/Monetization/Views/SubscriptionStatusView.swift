import SwiftUI

/// Settings-ready paid access surface.
struct SubscriptionStatusView: View {
    @Environment(PaywallService.self) private var paywallService

    @State private var isRestoring = false
    @State private var message: String?

    var body: some View {
        Section("Plan") {
            LabeledContent("Status", value: paywallService.subscriptionStatus.planName)
            LabeledContent("Access", value: paywallService.subscriptionStatus.accessDescription)

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

#if DEBUG
        Section("Developer Testing") {
            Text("Add provider-specific test reset controls here, such as rotating a RevenueCat Test Store customer. This section must remain debug-only.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
#endif
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
    List {
        SubscriptionStatusView()
    }
    .environment(PaywallService())
}
