import SwiftUI

/// Card styling modifier
struct CardModifier: ViewModifier {

    // MARK: - Properties

    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let padding: EdgeInsets

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Initialization

    init(
        backgroundColor: Color = AppTheme.Colors.secondaryBackground,
        cornerRadius: CGFloat = ComponentTokens.Card.cornerRadius,
        shadowRadius: CGFloat = ComponentTokens.Card.shadowRadius,
        padding: EdgeInsets = ComponentTokens.Card.padding)
    {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.padding = padding
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.Colors.separator, lineWidth: ComponentTokens.Card.borderWidth)
            }
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: ComponentTokens.Card.shadowOffset.width,
                y: ComponentTokens.Card.shadowOffset.height)
    }

    // MARK: - Computed Properties

    private var shadowColor: Color {
        ComponentTokens.Card.shadowColor(for: colorScheme)
    }
}

// MARK: - View Extension

extension View {
    /// Apply card styling
    func cardStyle(
        backgroundColor: Color = AppTheme.Colors.secondaryBackground,
        cornerRadius: CGFloat = ComponentTokens.Card.cornerRadius,
        shadowRadius: CGFloat = ComponentTokens.Card.shadowRadius,
        padding: EdgeInsets = ComponentTokens.Card.padding) -> some View
    {
        modifier(CardModifier(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            padding: padding))
    }

    /// Apply minimal card styling (no shadow)
    func cardStyleMinimal(
        backgroundColor: Color = AppTheme.Colors.secondaryBackground,
        cornerRadius: CGFloat = ComponentTokens.Card.cornerRadius) -> some View
    {
        modifier(CardModifier(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            shadowRadius: 0))
    }
}

// MARK: - Interactive Card Modifier

struct InteractiveCardModifier: ViewModifier {

    // MARK: - Properties

    let isSelected: Bool
    let onTap: () -> Void

    // MARK: - State

    @State private var isPressed = false

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .padding(ComponentTokens.Card.padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: ComponentTokens.Card.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ComponentTokens.Card.cornerRadius)
                    .stroke(borderColor, lineWidth: isSelected ? UIConstants.Border.thick : 0))
            .shadow(
                color: shadowColor,
                radius: ComponentTokens.Card.shadowRadius,
                x: ComponentTokens.Card.shadowOffset.width,
                y: ComponentTokens.Card.shadowOffset.height)
            .scaleEffect(isPressed ? ComponentTokens.Button.pressedScale : 1.0)
            .animation(ComponentTokens.Motion.press, value: isPressed)
            .onTapGesture {
                HapticService.shared.lightImpact()
                onTap()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false })
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        isSelected
            ? Color.accentColor.opacity(0.1)
            : AppTheme.Colors.secondaryBackground
    }

    private var borderColor: Color {
        isSelected ? .accentColor : .clear
    }

    private var shadowColor: Color {
        ComponentTokens.Card.shadowColor(for: colorScheme)
    }
}

extension View {
    /// Apply interactive card styling
    func interactiveCard(isSelected: Bool = false, onTap: @escaping () -> Void) -> some View {
        modifier(InteractiveCardModifier(isSelected: isSelected, onTap: onTap))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Standard Card")
                .frame(maxWidth: .infinity)
                .cardStyle()

            Text("Minimal Card")
                .frame(maxWidth: .infinity)
                .cardStyleMinimal()

            Text("Interactive Card")
                .frame(maxWidth: .infinity)
                .interactiveCard {
                    print("Card tapped")
                }

            Text("Selected Card")
                .frame(maxWidth: .infinity)
                .interactiveCard(isSelected: true) {
                    print("Card tapped")
                }
        }
        .padding()
    }
}
