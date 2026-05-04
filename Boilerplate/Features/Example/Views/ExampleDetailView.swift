import SwiftData
import SwiftUI

/// Example detail view
struct ExampleDetailView: View {
    // MARK: - Properties

    let itemId: String

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    // MARK: - Query

    @Query private var items: [ExampleItem]

    // MARK: - State

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    // MARK: - Computed Properties

    private var item: ExampleItem? {
        items.first { $0.id == itemId }
    }

    // MARK: - Initialization

    init(itemId: String) {
        self.itemId = itemId
        _items = Query(filter: #Predicate<ExampleItem> { item in
            item.id == itemId
        })
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let item {
                contentView(item)
            } else {
                EmptyStateView(
                    icon: "questionmark.folder",
                    title: "Item Not Found",
                    message: "The item you're looking for doesn't exist."
                )
            }
        }
        .navigationTitle(item?.title ?? "Details")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingEditSheet) {
            if let item {
                ExampleFormView(existingItem: item)
            }
        }
        .confirmationDialog(
            "Delete Item",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteItem()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
    }

    // MARK: - Content View

    private func contentView(_ item: ExampleItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.lg) {
                // Header card
                headerCard(item)

                // Description
                if let description = item.itemDescription {
                    descriptionSection(description)
                }

                // Metadata
                metadataSection(item)

                // Actions
                actionsSection(item)
            }
            .padding(UIConstants.Padding.section)
        }
    }

    private func headerCard(_ item: ExampleItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
                Text(item.title)
                    .font(AppTheme.Typography.title2)

                HStack {
                    if item.isFavorite {
                        Label("Favorite", systemImage: "star.fill")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.yellow)
                    }

                    Text("Updated \(item.updatedAt.relativeFormatted)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }

            Spacer()

            Button {
                toggleFavorite(item)
            } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundStyle(item.isFavorite ? .yellow : AppTheme.Colors.secondaryText)
            }
        }
        .cardStyle()
    }

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
            Text("Description")
                .font(AppTheme.Typography.headline)

            Text(description)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func metadataSection(_ item: ExampleItem) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.md) {
            Text("Details")
                .font(AppTheme.Typography.headline)

            VStack(spacing: UIConstants.Spacing.sm) {
                metadataRow(label: "ID", value: item.id)
                metadataRow(label: "Created", value: item.createdAt.dateTimeFormatted)
                metadataRow(label: "Updated", value: item.updatedAt.dateTimeFormatted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            Spacer()

            Text(value)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.text)
        }
    }

    private func actionsSection(_ item: ExampleItem) -> some View {
        VStack(spacing: UIConstants.Spacing.md) {
            SecondaryButton(title: "Edit Item", action: {
                showingEditSheet = true
            }, icon: "pencil")

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Item")
                }
                .frame(maxWidth: .infinity)
                .frame(height: UIConstants.ButtonSize.medium)
            }
            .buttonStyle(.destructive)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button {
                    if let item {
                        toggleFavorite(item)
                    }
                } label: {
                    Label(
                        item?.isFavorite == true ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: item?.isFavorite == true ? "star.slash" : "star"
                    )
                }

                Divider()

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Actions

    private func toggleFavorite(_ item: ExampleItem) {
        item.toggleFavorite()
        modelContext.saveIfNeeded()
        HapticService.shared.lightImpact()
    }

    private func deleteItem() {
        guard let item else { return }

        modelContext.delete(item)
        modelContext.saveIfNeeded()
        HapticService.shared.itemDeleted()
        router.pop()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExampleDetailView(itemId: "preview")
    }
    .modelContainer(SwiftDataContainer.preview)
    .environment(Router.shared)
}
