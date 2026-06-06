import SwiftUI

struct SettingsView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @State private var hapticsEnabled = true
    @State private var showDailySummary = true
    @State private var requireConfirmationBeforeDelete = true
    @State private var defaultCategory = "Health"

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    var body: some View {
        NavigationStack {
            List {
                loggingSection
                categoriesSection
                dataSection
                privacySection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear(perform: updateDefaultCategoryIfNeeded)
            .onChange(of: storedCategories) { _, _ in
                updateDefaultCategoryIfNeeded()
            }
        }
    }

    private var loggingSection: some View {
        Section("Logging") {
            Picker("Default Category", selection: $defaultCategory) {
                ForEach(categories) { category in
                    Label(category.name, systemImage: category.icon)
                        .tag(category.name)
                }
            }

            Toggle("Subtle Haptics", isOn: $hapticsEnabled)
            Toggle("Daily Summary", isOn: $showDailySummary)
            Toggle("Confirm Before Delete", isOn: $requireConfirmationBeforeDelete)
        }
    }

    private var categoriesSection: some View {
        Section("Categories") {
            NavigationLink {
                CategoriesView()
            } label: {
                SettingsRowContent(
                    title: "Manage Categories",
                    detail: "\(categories.count) active",
                    systemImage: "square.grid.2x2",
                    color: .blue
                )
            }

            SettingsNavigationRow(
                title: "Preset Items",
                detail: "\(categories.reduce(0) { $0 + $1.presetItems.count }) presets",
                systemImage: "list.bullet.rectangle",
                color: .indigo
            )
        }
    }

    private var dataSection: some View {
        Section("Data") {
            SettingsActionRow(
                title: "Export CSV",
                detail: "Create a local backup",
                systemImage: "square.and.arrow.up",
                color: .green
            )

            SettingsNavigationRow(
                title: "Storage",
                detail: "Local only",
                systemImage: "internaldrive",
                color: .gray
            )
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            SettingsInfoRow(
                title: "Sync",
                detail: "Off for MVP",
                systemImage: "icloud.slash",
                color: .teal
            )

            SettingsInfoRow(
                title: "Health Access",
                detail: "Not connected",
                systemImage: "heart.text.square",
                color: .red
            )
        }
    }

    private var aboutSection: some View {
        Section("About") {
            SettingsInfoRow(
                title: "EventTrace",
                detail: "Mock MVP build",
                systemImage: "app.badge",
                color: .blue
            )

            SettingsInfoRow(
                title: "Version",
                detail: "0.1",
                systemImage: "number",
                color: .secondary
            )
        }
    }

    private func updateDefaultCategoryIfNeeded() {
        guard !categories.contains(where: { $0.name == defaultCategory }) else { return }
        defaultCategory = categories.first?.name ?? ""
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        NavigationLink {
            SettingsPlaceholderDetail(title: title, detail: detail)
        } label: {
            SettingsRowContent(title: title, detail: detail, systemImage: systemImage, color: color)
        }
    }
}

private struct SettingsActionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        Button {
        } label: {
            SettingsRowContent(title: title, detail: detail, systemImage: systemImage, color: color)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        SettingsRowContent(title: title, detail: detail, systemImage: systemImage, color: color)
    }
}

private struct SettingsRowContent: View {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(title)
                .font(.body)

            Spacer()

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsPlaceholderDetail: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.weight(.semibold))

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
    }
}

#Preview {
    SettingsView()
}
