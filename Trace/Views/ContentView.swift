import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @AppStorage(EventPresetStorage.key) private var storedPresets = ""
    @AppStorage(LoggedEventStorage.key) private var storedEvents = ""
    @AppStorage(TraceSettingsStorage.hapticsEnabledKey) private var hapticsEnabled = true
    @AppStorage(TraceSettingsStorage.defaultCategoryIDKey) private var defaultCategoryID = EventCategory.defaults.first?.id.uuidString ?? ""
    @State private var isShowingQuickLog = false

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    private var presets: [EventPresetItem] {
        EventPresetStorage.decode(storedPresets, categoriesData: storedCategories)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                CalendarView()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }

                Color.clear
                    .tabItem {
                        Label("", systemImage: "")
                    }

                StatisticsView()
                    .tabItem {
                        Label("Statistics", systemImage: "chart.bar")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }

            Button {
                triggerHapticFeedback()
                isShowingQuickLog = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 6)
            }
            .accessibilityLabel("Log event")
            .offset(y: -10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $isShowingQuickLog) {
            QuickLogCategorySheet(
                categories: categories,
                presets: presets,
                storedEvents: $storedEvents,
                defaultCategoryID: defaultCategoryID,
                hapticsEnabled: hapticsEnabled
            )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func triggerHapticFeedback() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct QuickLogCategorySheet: View {
    let categories: [EventCategory]
    let presets: [EventPresetItem]
    @Binding var storedEvents: String
    let hapticsEnabled: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategoryIndex = 0
    @State private var isShowingCategoryManagement = false

    init(
        categories: [EventCategory],
        presets: [EventPresetItem],
        storedEvents: Binding<String>,
        defaultCategoryID: String,
        hapticsEnabled: Bool
    ) {
        self.categories = categories
        self.presets = presets
        self._storedEvents = storedEvents
        self.hapticsEnabled = hapticsEnabled
        self._selectedCategoryIndex = State(initialValue: Self.initialCategoryIndex(
            categories: categories,
            defaultCategoryID: defaultCategoryID
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TabView(selection: $selectedCategoryIndex) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        categoryPage(category)
                            .tag(index)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: .infinity)

                Button {
                    isShowingCategoryManagement = true
                } label: {
                    Label("Manage Categories", systemImage: "slider.horizontal.3")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            .navigationTitle("Log Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingCategoryManagement) {
                CategoriesView()
            }
        }
    }

    private func categoryPage(_ category: EventCategory) -> some View {
        let categoryPresets = presets.filter { $0.categoryID == category.id }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(category.tintColor)
                    .frame(width: 44, height: 44)
                    .background(category.tintColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(category.name)
                    .font(.title2.weight(.semibold))

                Spacer()
            }

            if categoryPresets.isEmpty {
                Text("No presets yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                        ForEach(categoryPresets) { preset in
                            Button {
                                triggerHapticFeedback()
                                log(preset, in: category)
                                dismiss()
                            } label: {
                                Text(preset.name)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(category.tintColor)
                            .accessibilityLabel("Log \(preset.name)")
                        }
                    }
                    .padding(.bottom, 8)
                }
            }

        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func log(_ preset: EventPresetItem, in category: EventCategory) {
        var events = LoggedEventStorage.decode(storedEvents)
        let event = LoggedEvent(
            categoryID: category.id,
            presetID: preset.id,
            title: preset.name
        )

        events.insert(event, at: 0)
        storedEvents = LoggedEventStorage.encode(events)
    }

    private func triggerHapticFeedback() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private static func initialCategoryIndex(categories: [EventCategory], defaultCategoryID: String) -> Int {
        guard let defaultID = UUID(uuidString: defaultCategoryID),
              let index = categories.firstIndex(where: { $0.id == defaultID }) else {
            return 0
        }

        return index
    }
}

#Preview {
    ContentView()
}
