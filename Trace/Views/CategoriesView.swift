import SwiftUI

struct CategoriesView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @State private var categories = EventCategory.defaults
    @State private var draftCategory = CategoryDraft()
    @State private var editingCategory: EventCategory?
    @State private var isShowingEditor = false

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    Button {
                        editingCategory = category
                        draftCategory = CategoryDraft(category: category)
                        isShowingEditor = true
                    } label: {
                        CategoryManagementRow(category: category)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit category")
                }
                .onDelete(perform: deleteCategories)
                .onMove(perform: moveCategories)
            } header: {
                Text("Active Categories")
            } footer: {
                Text("These categories appear in quick logging and settings. Presets are shown as fast logging shortcuts.")
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCategory = nil
                    draftCategory = CategoryDraft()
                    isShowingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add category")
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                CategoryEditorView(
                    title: editingCategory == nil ? "New Category" : "Edit Category",
                    draft: $draftCategory,
                    onSave: saveDraft
                )
            }
        }
        .onAppear(perform: loadCategories)
    }

    private func loadCategories() {
        categories = EventCategoryStorage.decode(storedCategories)
    }

    private func persistCategories() {
        storedCategories = EventCategoryStorage.encode(categories)
    }

    private func saveDraft() {
        let category = draftCategory.category(existingID: editingCategory?.id)

        if let editingCategory,
           let index = categories.firstIndex(where: { $0.id == editingCategory.id }) {
            categories[index] = category
        } else {
            categories.append(category)
        }

        persistCategories()
        isShowingEditor = false
    }

    private func deleteCategories(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
        if categories.isEmpty {
            categories = EventCategory.defaults
        }
        persistCategories()
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        persistCategories()
    }
}

private struct CategoryManagementRow: View {
    let category: EventCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(category.tintColor)
                .frame(width: 38, height: 38)
                .background(category.tintColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.body.weight(.semibold))

                Text(category.presetItems.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct CategoryEditorView: View {
    let title: String
    @Binding var draft: CategoryDraft
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let iconChoices = [
        "square.grid.2x2",
        "face.smiling",
        "heart.text.square",
        "figure.run",
        "figure.walk",
        "book",
        "pills",
        "moon",
        "brain.head.profile",
        "flame"
    ]

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $draft.name)

                Picker("Color", selection: $draft.tintName) {
                    ForEach(EventCategoryTint.names, id: \.self) { name in
                        Label(name, systemImage: "circle.fill")
                            .foregroundStyle(EventCategoryTint.color(named: name))
                    }
                }
            }

            Section("Icon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 12)], spacing: 12) {
                    ForEach(iconChoices, id: \.self) { icon in
                        Button {
                            draft.icon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(draft.icon == icon ? .white : draft.tintColor)
                                .frame(width: 48, height: 48)
                                .background(draft.icon == icon ? draft.tintColor : draft.tintColor.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(icon)
                        .accessibilityAddTraits(draft.icon == icon ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Preset Items") {
                TextField("Headache, Sleep, Medication", text: $draft.presetText, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave()
                }
                .disabled(!canSave)
            }
        }
    }
}

private struct CategoryDraft {
    var name = ""
    var icon = "square.grid.2x2"
    var tintName = "Blue"
    var presetText = ""

    init() {}

    init(category: EventCategory) {
        name = category.name
        icon = category.icon
        tintName = category.tintName
        presetText = category.presetItems.joined(separator: ", ")
    }

    var tintColor: Color {
        EventCategoryTint.color(named: tintName)
    }

    func category(existingID: UUID?) -> EventCategory {
        EventCategory(
            id: existingID ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            tintName: tintName,
            presetItems: presetText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
}
