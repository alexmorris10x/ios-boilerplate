import SwiftUI

/// Native component workbench. Keep this view on the same production
/// components used by features; do not maintain gallery-only replicas.
struct DesignSystemGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.xl) {
                galleryHeader
                colorSection
                typeSection
                componentSection
            }
            .padding(UIConstants.Padding.horizontal)
            .padding(.vertical, UIConstants.Spacing.xl)
        }
        .background(AppTheme.Colors.groupedBackground)
        .accessibilityIdentifier("design-system.gallery")
    }

    private var galleryHeader: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
            Text("NATIVE UI WORKBENCH")
                .font(AppTheme.Typography.sectionHeader)
                .tracking(1.1)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            Text("Design System")
                .font(AppTheme.Typography.largeTitle)

            Text("Production tokens and components rendered together for visual review.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private var colorSection: some View {
        GallerySection(title: "Semantic color") {
            HStack(spacing: UIConstants.Spacing.sm) {
                ColorSwatch(name: "Action", color: AppTheme.Colors.primary)
                ColorSwatch(name: "Success", color: AppTheme.Colors.success)
                ColorSwatch(name: "Warning", color: AppTheme.Colors.warning)
                ColorSwatch(name: "Error", color: AppTheme.Colors.error)
            }
        }
    }

    private var typeSection: some View {
        GallerySection(title: "Type hierarchy") {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
                Text("One clear answer")
                    .font(AppTheme.Typography.title)
                Text("A supporting section title")
                    .font(AppTheme.Typography.headline)
                Text("Explanation gives the next useful piece of context.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Text("SOURCE · UPDATED 2M AGO")
                    .font(AppTheme.Typography.sectionHeader)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyleMinimal()
        }
    }

    private var componentSection: some View {
        GallerySection(title: "Components") {
            VStack(spacing: UIConstants.Spacing.md) {
                PrimaryButton(title: "Primary action", action: {})

                PrimaryButton(
                    title: "Working",
                    action: {},
                    isLoading: true)

                PrimaryButton(title: "Unavailable", action: {})
                    .disabled(true)

                HStack {
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
                        Text("Result card")
                            .font(AppTheme.Typography.headline)
                        Text("A real component should expose meaning, state, and action.")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                .cardStyle()
            }
        }
    }
}

private struct GallerySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text(title)
                .font(AppTheme.Typography.title3)
            content
        }
    }
}

private struct ColorSwatch: View {
    let name: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.xs) {
            RoundedRectangle(cornerRadius: ComponentTokens.Card.cornerRadius)
                .fill(color)
                .frame(height: 52)
            Text(name)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Design System · Light") {
    DesignSystemGallery()
        .preferredColorScheme(.light)
}

#Preview("Design System · Dark") {
    DesignSystemGallery()
        .preferredColorScheme(.dark)
}

#Preview("Design System · Large Text") {
    DesignSystemGallery()
        .environment(\.dynamicTypeSize, .accessibility3)
}
