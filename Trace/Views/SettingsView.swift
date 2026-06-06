import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @AppStorage(EventPresetStorage.key) private var storedPresets = ""
    @State private var hapticsEnabled = true
    @State private var showDailySummary = true
    @State private var requireConfirmationBeforeDelete = true
    @State private var defaultCategory = "Health"
    @State private var exportItem: TraceExportItem?
    @State private var exportErrorMessage = ""
    @State private var isShowingExportError = false

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    private var presets: [EventPresetItem] {
        EventPresetStorage.decode(storedPresets, categoriesData: storedCategories)
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
            .sheet(item: $exportItem) { item in
                ActivityShareView(activityItems: [item.url])
            }
            .alert("Export Failed", isPresented: $isShowingExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportErrorMessage)
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

            NavigationLink {
                PresetItemsView()
            } label: {
                SettingsRowContent(
                    title: "Preset Items",
                    detail: "\(presets.count) presets",
                    systemImage: "list.bullet.rectangle",
                    color: .indigo
                )
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            SettingsActionRow(
                title: "Export Categories CSV",
                detail: "Categories and presets",
                systemImage: "tablecells",
                color: .green,
                action: exportExcel
            )

            SettingsActionRow(
                title: "Export Categories PDF",
                detail: "Categories and presets",
                systemImage: "doc.richtext",
                color: .red,
                action: exportPDF
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

    private func exportExcel() {
        exportFile { generator in
            try generator.makeExcelFile(categories: categories, presets: presets)
        }
    }

    private func exportPDF() {
        exportFile { generator in
            try generator.makePDFFile(categories: categories, presets: presets)
        }
    }

    private func exportFile(_ makeURL: (TraceExportGenerator) throws -> URL) {
        do {
            let url = try makeURL(TraceExportGenerator())
            exportItem = TraceExportItem(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
            isShowingExportError = true
        }
    }
}

private struct TraceExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityShareView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
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

private struct PresetItemsView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @AppStorage(EventPresetStorage.key) private var storedPresets = ""

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    private var presets: [EventPresetItem] {
        EventPresetStorage.decode(storedPresets, categoriesData: storedCategories)
    }

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    NavigationLink {
                        PresetCategoryEditorView(categoryID: category.id)
                    } label: {
                        SettingsRowContent(
                            title: category.name,
                            detail: presetCountText(for: category, presets: presets),
                            systemImage: category.icon,
                            color: category.tintColor
                        )
                    }
                }
            } footer: {
                Text("Presets appear as quick-log shortcuts for each category.")
            }
        }
        .navigationTitle("Preset Items")
        .onAppear(perform: persistPresetsIfNeeded)
    }

    private func presetCountText(for category: EventCategory, presets: [EventPresetItem]) -> String {
        let count = presets.filter { $0.categoryID == category.id }.count
        return count == 1 ? "1 preset" : "\(count) presets"
    }

    private func persistPresetsIfNeeded() {
        if storedPresets.isEmpty {
            storedPresets = EventPresetStorage.encode(presets)
        }
    }
}

private struct PresetCategoryEditorView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @AppStorage(EventPresetStorage.key) private var storedPresets = ""
    let categoryID: UUID
    @State private var newPresetName = ""
    @FocusState private var isAddingPreset: Bool

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    private var category: EventCategory? {
        categories.first { $0.id == categoryID }
    }

    private var presets: [EventPresetItem] {
        EventPresetStorage.decode(storedPresets, categoriesData: storedCategories)
    }

    private var categoryPresets: [EventPresetItem] {
        presets.filter { $0.categoryID == categoryID }
    }

    private var canAddPreset: Bool {
        guard category != nil else { return false }
        let trimmedName = trimmedNewPresetName
        return !trimmedName.isEmpty && !categoryPresets.contains { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    private var trimmedNewPresetName: String {
        newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            if let category {
                Section {
                    ForEach(categoryPresets) { preset in
                        Text(preset.name)
                            .font(.body)
                    }
                    .onDelete(perform: deletePresets)
                    .onMove(perform: movePresets)
                } header: {
                    Text(category.name)
                } footer: {
                    if categoryPresets.isEmpty {
                        Text("Add lightweight shortcuts for events you log often.")
                    }
                }

                Section("Add Preset") {
                    HStack(spacing: 12) {
                        TextField("Preset name", text: $newPresetName)
                            .focused($isAddingPreset)
                            .submitLabel(.done)
                            .onSubmit(addPreset)

                        Button {
                            addPreset()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .disabled(!canAddPreset)
                        .accessibilityLabel("Add preset")
                    }
                }
            } else {
                ContentUnavailableView("Category Not Found", systemImage: "list.bullet.rectangle")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(category?.name ?? "Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .disabled(categoryPresets.isEmpty)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    isAddingPreset = false
                }
            }
        }
    }

    private func addPreset() {
        guard canAddPreset else { return }
        var updatedPresets = presets
        updatedPresets.append(EventPresetItem(categoryID: categoryID, name: trimmedNewPresetName))
        storedPresets = EventPresetStorage.encode(updatedPresets)
        newPresetName = ""
        isAddingPreset = false
    }

    private func deletePresets(at offsets: IndexSet) {
        let presetIDsToDelete = offsets.map { categoryPresets[$0].id }
        var updatedPresets = presets
        updatedPresets.removeAll { presetIDsToDelete.contains($0.id) }
        storedPresets = EventPresetStorage.encode(updatedPresets)
    }

    private func movePresets(from source: IndexSet, to destination: Int) {
        var reorderedCategoryPresets = categoryPresets
        reorderedCategoryPresets.move(fromOffsets: source, toOffset: destination)

        let otherPresets = presets.filter { $0.categoryID != categoryID }
        storedPresets = EventPresetStorage.encode(otherPresets + reorderedCategoryPresets)
    }
}

private struct SettingsActionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
