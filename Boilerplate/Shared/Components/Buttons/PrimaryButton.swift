import SwiftUI

/// Primary action button with optional loading state and icon
struct PrimaryButton: View {
    // MARK: - Properties

    let title: String
    let action: () -> Void

    var icon: String?
    var isLoading: Bool = false
    var isFullWidth: Bool = true

    // MARK: - Environment

    @Environment(\.isEnabled) private var isEnabled

    // MARK: - Body

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            HapticService.shared.buttonTap()
            action()
        }) {
            HStack(spacing: UIConstants.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.body.weight(.semibold))
                    }
                    Text(title)
                        .font(AppTheme.Typography.buttonLabel)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: UIConstants.ButtonSize.medium)
            .padding(.horizontal, isFullWidth ? 0 : UIConstants.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .fill(backgroundColor)
            )
        }
        .disabled(isLoading)
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        if !isEnabled {
            return .gray
        }
        return .accentColor
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue") {
            print("Tapped")
        }

        PrimaryButton(title: "Submit", action: {
            print("Tapped")
        }, icon: "paperplane.fill")

        PrimaryButton(title: "Loading", action: {
            print("Tapped")
        }, isLoading: true)

        PrimaryButton(title: "Disabled") {
            print("Tapped")
        }
        .disabled(true)

        PrimaryButton(title: "Compact", action: {
            print("Tapped")
        }, isFullWidth: false)
    }
    .padding()
}
