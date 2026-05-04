import SwiftUI

/// Secondary action button with outline style
struct SecondaryButton: View {
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
                        .tint(.accentColor)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.body.weight(.semibold))
                    }
                    Text(title)
                        .font(AppTheme.Typography.buttonLabel)
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: UIConstants.ButtonSize.medium)
            .padding(.horizontal, isFullWidth ? 0 : UIConstants.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(strokeColor, lineWidth: UIConstants.Border.standard)
            )
        }
        .disabled(isLoading)
    }

    // MARK: - Computed Properties

    private var foregroundColor: Color {
        isEnabled ? .accentColor : .gray
    }

    private var strokeColor: Color {
        isEnabled ? .accentColor : .gray
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SecondaryButton(title: "Cancel") {
            print("Tapped")
        }

        SecondaryButton(title: "Add Item", action: {
            print("Tapped")
        }, icon: "plus")

        SecondaryButton(title: "Loading", action: {
            print("Tapped")
        }, isLoading: true)

        SecondaryButton(title: "Disabled") {
            print("Tapped")
        }
        .disabled(true)
    }
    .padding()
}
