import SwiftUI

/// Component-level decisions built from primitive and semantic tokens.
///
/// Keep raw values in `UIConstants`, product meaning in `AppTheme`, and exact
/// component construction here. Feature views should consume these tokens
/// instead of introducing unrelated padding, radius, shadow, or motion values.
enum ComponentTokens {
    enum Button {
        static let height = UIConstants.ButtonSize.medium
        static let horizontalPadding = UIConstants.Spacing.lg
        static let cornerRadius = UIConstants.CornerRadius.medium
        static let pressedScale: CGFloat = 0.98
        static let disabledOpacity = 0.44
    }

    enum Card {
        static let padding = UIConstants.Padding.cardInsets
        static let cornerRadius = UIConstants.CornerRadius.large
        static let borderWidth = UIConstants.Border.thin
        static let shadowRadius = UIConstants.Shadow.medium
        static let shadowOffset = UIConstants.Shadow.offset

        static func shadowColor(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? .clear : UIConstants.Shadow.color
        }
    }

    enum Motion {
        static let press = Animation.easeOut(duration: 0.12)
    }
}
