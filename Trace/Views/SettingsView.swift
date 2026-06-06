import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @AppStorage(EventPresetStorage.key) private var storedPresets = ""
    @AppStorage(LoggedEventStorage.key) private var storedEvents = ""
    @AppStorage(TraceSettingsStorage.hapticsEnabledKey) private var hapticsEnabled = true
    @AppStorage(TraceSettingsStorage.confirmBeforeDeleteKey) private var requireConfirmationBeforeDelete = true
    @AppStorage(TraceSettingsStorage.defaultCategoryIDKey) private var defaultCategoryID = EventCategory.defaults.first?.id.uuidString ?? ""
    @State private var exportItem: TraceExportItem?
    @State private var exportErrorMessage = ""
    @State private var isShowingExportError = false

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    private var presets: [EventPresetItem] {
        EventPresetStorage.decode(storedPresets, categoriesData: storedCategories)
    }

    private var events: [LoggedEvent] {
        LoggedEventStorage.decode(storedEvents)
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
            Picker("Default Category", selection: $defaultCategoryID) {
                ForEach(categories) { category in
                    Label(category.name, systemImage: category.icon)
                        .tag(category.id.uuidString)
                }
            }

            Toggle("Subtle Haptics", isOn: $hapticsEnabled)
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

            NavigationLink {
                EventExportView()
            } label: {
                SettingsRowContent(
                    title: "Export Event Report",
                    detail: "\(events.count) logged",
                    systemImage: "square.and.arrow.up",
                    color: .blue
                )
            }

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
        guard !categories.contains(where: { $0.id.uuidString == defaultCategoryID }) else { return }
        defaultCategoryID = categories.first?.id.uuidString ?? ""
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

private struct EventExportView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @AppStorage(EventPresetStorage.key) private var storedPresets = ""
    @AppStorage(LoggedEventStorage.key) private var storedEvents = ""
    @State private var selectedCategoryID: UUID?
    @State private var range = EventExportRange.last30Days
    @State private var includeAllPresets = true
    @State private var selectedPresetIDs = Set<UUID>()
    @State private var exportItem: TraceExportItem?
    @State private var exportErrorMessage = ""
    @State private var isShowingExportError = false

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    private var presets: [EventPresetItem] {
        EventPresetStorage.decode(storedPresets, categoriesData: storedCategories)
    }

    private var events: [LoggedEvent] {
        LoggedEventStorage.decode(storedEvents)
    }

    private var selectedCategory: EventCategory? {
        guard let selectedCategoryID else { return categories.first }
        return categories.first { $0.id == selectedCategoryID }
    }

    private var categoryPresets: [EventPresetItem] {
        guard let selectedCategory else { return [] }
        return presets.filter { $0.categoryID == selectedCategory.id }
    }

    private var includedPresets: [EventPresetItem] {
        includeAllPresets ? categoryPresets : categoryPresets.filter { selectedPresetIDs.contains($0.id) }
    }

    private var filteredEvents: [LoggedEvent] {
        guard let selectedCategory else { return [] }

        return events.filter { event in
            guard event.categoryID == selectedCategory.id else { return false }
            guard range.includes(event.loggedAt) else { return false }

            if includeAllPresets {
                return true
            }

            guard let presetID = event.presetID else { return false }
            return selectedPresetIDs.contains(presetID)
        }
    }

    var body: some View {
        List {
            Section("Category") {
                Picker("Category", selection: selectedCategoryIDBinding) {
                    ForEach(categories) { category in
                        Label(category.name, systemImage: category.icon)
                            .tag(category.id)
                    }
                }
            }

            Section("Date Range") {
                Picker("Range", selection: $range) {
                    ForEach(EventExportRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("All Presets in Category", isOn: $includeAllPresets)
                    .onChange(of: includeAllPresets) { _, newValue in
                        if newValue {
                            selectedPresetIDs.removeAll()
                        }
                    }

                if !includeAllPresets {
                    if categoryPresets.isEmpty {
                        Text("This category has no presets yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(categoryPresets) { preset in
                            Toggle(preset.name, isOn: presetBinding(for: preset))
                        }
                    }
                }
            } header: {
                Text("Presets")
            } footer: {
                Text("Use this to export stomach pain without including headaches from the same Health category.")
            }

            Section {
                SettingsInfoRow(
                    title: "Matching Events",
                    detail: "\(filteredEvents.count)",
                    systemImage: "number",
                    color: .secondary
                )

                SettingsActionRow(
                    title: "Export CSV",
                    detail: "Excel compatible",
                    systemImage: "tablecells",
                    color: .green,
                    action: exportExcel
                )
                .disabled(!canExport)

                SettingsActionRow(
                    title: "Export PDF",
                    detail: "Visual summary",
                    systemImage: "doc.richtext",
                    color: .red,
                    action: exportPDF
                )
                .disabled(!canExport)
            } footer: {
                Text("The report includes only logged events for the selected category, range, and presets.")
            }
        }
        .navigationTitle("Event Report")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: selectInitialCategoryIfNeeded)
        .onChange(of: storedCategories) { _, _ in
            selectInitialCategoryIfNeeded()
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

    private var canExport: Bool {
        selectedCategory != nil && (includeAllPresets || !selectedPresetIDs.isEmpty)
    }

    private var selectedCategoryIDBinding: Binding<UUID> {
        Binding(
            get: {
                selectedCategory?.id ?? categories.first?.id ?? UUID()
            },
            set: { newValue in
                selectedCategoryID = newValue
                includeAllPresets = true
                selectedPresetIDs.removeAll()
            }
        )
    }

    private func presetBinding(for preset: EventPresetItem) -> Binding<Bool> {
        Binding(
            get: {
                selectedPresetIDs.contains(preset.id)
            },
            set: { isSelected in
                if isSelected {
                    selectedPresetIDs.insert(preset.id)
                } else {
                    selectedPresetIDs.remove(preset.id)
                }
            }
        )
    }

    private func selectInitialCategoryIfNeeded() {
        if selectedCategoryID == nil || selectedCategory == nil {
            selectedCategoryID = categories.first?.id
            includeAllPresets = true
            selectedPresetIDs.removeAll()
        }
    }

    private func exportExcel() {
        exportFile { generator, category in
            try generator.makeEventExcelFile(
                category: category,
                presets: includeAllPresets ? [] : includedPresets,
                events: filteredEvents,
                scopeTitle: range.title
            )
        }
    }

    private func exportPDF() {
        exportFile { generator, category in
            try generator.makeEventPDFFile(
                category: category,
                presets: includeAllPresets ? [] : includedPresets,
                events: filteredEvents,
                scopeTitle: range.title
            )
        }
    }

    private func exportFile(_ makeURL: (TraceExportGenerator, EventCategory) throws -> URL) {
        guard let selectedCategory else { return }

        do {
            let url = try makeURL(TraceExportGenerator(), selectedCategory)
            exportItem = TraceExportItem(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
            isShowingExportError = true
        }
    }
}

private enum EventExportRange: String, CaseIterable, Identifiable {
    case last7Days
    case last30Days
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7Days:
            return "7 Days"
        case .last30Days:
            return "30 Days"
        case .allTime:
            return "All"
        }
    }

    func includes(_ date: Date) -> Bool {
        switch self {
        case .last7Days:
            return date >= startDate(daysBack: 6)
        case .last30Days:
            return date >= startDate(daysBack: 29)
        case .allTime:
            return true
        }
    }

    private func startDate(daysBack: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
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
