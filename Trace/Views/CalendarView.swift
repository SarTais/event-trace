import SwiftUI

struct CalendarView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @AppStorage(EventPresetStorage.key) private var storedPresets = ""
    @AppStorage(LoggedEventStorage.key) private var storedEvents = ""
    @AppStorage(TraceSettingsStorage.confirmBeforeDeleteKey) private var requireConfirmationBeforeDelete = true
    @State private var selectedCategoryID: UUID?
    @State private var selectedPresetID: UUID?
    @State private var selectedDate = Date()

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    private var presets: [EventPresetItem] {
        EventPresetStorage.decode(storedPresets, categoriesData: storedCategories)
    }

    private var selectedCategoryPresets: [EventPresetItem] {
        guard let selectedCategoryID else {
            return []
        }

        return presets.filter { $0.categoryID == selectedCategoryID }
    }

    private var effectiveSelectedPresetID: UUID? {
        guard let selectedPresetID,
              selectedCategoryPresets.contains(where: { $0.id == selectedPresetID }) else {
            return nil
        }

        return selectedPresetID
    }

    private var events: [LoggedEvent] {
        LoggedEventStorage.decode(storedEvents)
    }

    private var filteredEvents: [LoggedEvent] {
        guard let selectedCategoryID else {
            return events
        }

        let categoryEvents = events.filter { $0.categoryID == selectedCategoryID }

        guard let effectiveSelectedPresetID else {
            return categoryEvents
        }

        return categoryEvents.filter { $0.presetID == effectiveSelectedPresetID }
    }

    private var displayedMonth: DateInterval? {
        Calendar.current.dateInterval(of: .month, for: selectedDate)
    }

    private var monthDays: [CalendarDay] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let groupedEvents = Dictionary(grouping: filteredEvents) {
            calendar.startOfDay(for: $0.loggedAt)
        }

        guard let month = displayedMonth,
              let dayRange = calendar.range(of: .day, in: .month, for: month.start) else {
            return []
        }

        return dayRange.compactMap { dayNumber in
            guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: month.start) else {
                return nil
            }

            let dayStart = calendar.startOfDay(for: date)
            let count = groupedEvents[dayStart, default: []].count

            return CalendarDay(
                id: dayStart,
                date: dayStart,
                number: dayNumber,
                count: count,
                intensity: min(count, 4),
                isSelected: dayStart == selectedDay
            )
        }
    }

    private var selectedDayEvents: [LoggedEvent] {
        let calendar = Calendar.current

        return filteredEvents.filter {
            calendar.isDate($0.loggedAt, inSameDayAs: selectedDate)
        }
    }

    private var monthEventCount: Int {
        guard let month = displayedMonth else {
            return 0
        }

        return filteredEvents.filter { month.contains($0.loggedAt) }.count
    }

    private var activeDaysThisMonth: Int {
        let calendar = Calendar.current
        guard let month = displayedMonth else {
            return 0
        }

        return filteredEvents.reduce(into: Set<Date>()) { days, event in
            guard month.contains(event.loggedAt) else {
                return
            }

            days.insert(calendar.startOfDay(for: event.loggedAt))
        }
        .count
    }

    private var canMoveToNextMonth: Bool {
        let calendar = Calendar.current
        guard let displayedMonthStart = displayedMonth?.start,
              let currentMonth = calendar.dateInterval(of: .month, for: Date()) else {
            return false
        }

        return displayedMonthStart < currentMonth.start
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    categoryFilters
                    monthOverview
                    detailSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
        }
    }

    private var categoryFilters: some View {
        VStack(alignment: .leading, spacing: 8) {
            categoryFilter

            if selectedCategoryID != nil, !selectedCategoryPresets.isEmpty {
                presetFilter
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryFilterButton(title: "All", categoryID: nil)

                ForEach(categories) { category in
                    categoryFilterButton(title: category.name, categoryID: category.id)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var presetFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                presetFilterButton(title: "All presets", presetID: nil)

                ForEach(selectedCategoryPresets) { preset in
                    presetFilterButton(title: preset.name, presetID: preset.id)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var monthOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous month")

                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.monthFormatter.string(from: selectedDate))
                        .font(.title3.weight(.semibold))

                    Text(monthSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveToNextMonth ? .primary : .secondary)
                .disabled(!canMoveToNextMonth)
                .accessibilityLabel("Next month")
            }

            HStack(spacing: 8) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(monthDays) { day in
                    Button {
                        selectedDate = day.date
                    } label: {
                        CalendarDayCell(day: day)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(Self.selectedDayFormatter.string(from: selectedDate), systemImage: "calendar.badge.clock")
                .font(.headline)

            if selectedDayEvents.isEmpty {
                Text("No events logged for this day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(selectedDayEvents.enumerated()), id: \.element.id) { index, event in
                        CalendarEventRow(
                            title: event.title,
                            category: categoryName(for: event),
                            time: Self.timeFormatter.string(from: event.loggedAt),
                            loggedAt: event.loggedAt,
                            note: event.note,
                            color: categoryColor(for: event),
                            requiresDeleteConfirmation: requireConfirmationBeforeDelete,
                            onUpdateNote: { note in
                                updateNote(note, for: event)
                            },
                            onUpdateLoggedAt: { loggedAt in
                                updateLoggedAt(loggedAt, for: event)
                            },
                            onDelete: {
                                removeEvent(event)
                            }
                        )

                        if index < selectedDayEvents.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var monthSummary: String {
        let eventLabel = monthEventCount == 1 ? "event" : "events"
        let dayLabel = activeDaysThisMonth == 1 ? "active day" : "active days"
        return "\(monthEventCount) \(eventLabel) across \(activeDaysThisMonth) \(dayLabel)"
    }

    private func categoryFilterButton(title: String, categoryID: UUID?) -> some View {
        Button {
            selectedCategoryID = categoryID
            selectedPresetID = nil
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedCategoryID == categoryID ? .white : .primary)
        .background(selectedCategoryID == categoryID ? Color.blue : Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .accessibilityAddTraits(selectedCategoryID == categoryID ? .isSelected : [])
    }

    private func presetFilterButton(title: String, presetID: UUID?) -> some View {
        Button {
            selectedPresetID = presetID
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(effectiveSelectedPresetID == presetID ? .white : .primary)
        .background(effectiveSelectedPresetID == presetID ? Color.blue.opacity(0.85) : Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .accessibilityAddTraits(effectiveSelectedPresetID == presetID ? .isSelected : [])
    }

    private func moveMonth(by value: Int) {
        guard let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) else {
            return
        }

        selectedDate = newDate
    }

    private func removeEvent(_ event: LoggedEvent) {
        storedEvents = LoggedEventStorage.removing(eventID: event.id, from: storedEvents)
    }

    private func updateNote(_ note: String?, for event: LoggedEvent) {
        storedEvents = LoggedEventStorage.updatingNote(note, eventID: event.id, in: storedEvents)
    }

    private func updateLoggedAt(_ loggedAt: Date, for event: LoggedEvent) {
        storedEvents = LoggedEventStorage.updatingLoggedAt(loggedAt, eventID: event.id, in: storedEvents)
        selectedDate = loggedAt
    }

    private func category(for event: LoggedEvent) -> EventCategory? {
        categories.first { $0.id == event.categoryID }
    }

    private func categoryName(for event: LoggedEvent) -> String {
        category(for: event)?.name ?? "Deleted category"
    }

    private func categoryColor(for event: LoggedEvent) -> Color {
        category(for: event)?.tintColor ?? .gray
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let selectedDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct CalendarDay: Identifiable {
    let id: Date
    let date: Date
    let number: Int
    let count: Int
    let intensity: Int
    let isSelected: Bool
}

private struct CalendarDayCell: View {
    let day: CalendarDay

    var body: some View {
        VStack(spacing: 6) {
            Text("\(day.number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(day.isSelected ? .blue : .secondary)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(activityColor)
                .frame(height: 34)
                .overlay {
                    if day.isSelected {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day \(day.number), \(day.count) events")
    }

    private var activityColor: Color {
        switch day.intensity {
        case 0:
            return Color(.tertiarySystemFill)
        case 1:
            return .green.opacity(0.35)
        case 2:
            return .green.opacity(0.55)
        case 3:
            return .green.opacity(0.75)
        default:
            return .green
        }
    }
}

private struct CalendarEventRow: View {
    let title: String
    let category: String
    let time: String
    let loggedAt: Date
    let note: String?
    let color: Color
    let requiresDeleteConfirmation: Bool
    let onUpdateNote: (String?) -> Void
    let onUpdateLoggedAt: (Date) -> Void
    let onDelete: () -> Void
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingNote = false
    @State private var isShowingNoteEditor = false
    @State private var isShowingDateTimeEditor = false
    @State private var draftNote = ""
    @State private var draftLoggedAt = Date()

    private var hasNote: Bool {
        note?.isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))

                    Text(category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if hasNote {
                    Image(systemName: "note.text")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                        .accessibilityLabel("Has note")
                }

                Text(time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    delete()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove \(title)")
                .confirmationDialog(
                    "Remove logged event?",
                    isPresented: $isShowingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Remove Event", role: .destructive, action: onDelete)
                } message: {
                    Text("This removes \"\(title)\" from your logged events.")
                }
            }
            .frame(minHeight: 50)

            if isShowingNote, let note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 22)
                    .padding(.trailing, 48)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard hasNote else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                isShowingNote.toggle()
            }
        }
        .accessibilityHint(hasNote ? "Double tap to show or hide note" : "")
        .contextMenu {
            Button {
                draftNote = note ?? ""
                isShowingNoteEditor = true
            } label: {
                Label(hasNote ? "Edit Note" : "Add Note", systemImage: "note.text")
            }

            Button {
                draftLoggedAt = loggedAt
                isShowingDateTimeEditor = true
            } label: {
                Label("Edit Date & Time", systemImage: "calendar.badge.clock")
            }

            if hasNote {
                Button(role: .destructive) {
                    onUpdateNote(nil)
                    isShowingNote = false
                } label: {
                    Label("Remove Note", systemImage: "minus.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingNoteEditor) {
            EventNoteEditor(eventTitle: title, noteText: $draftNote) {
                isShowingNoteEditor = false
            } onSave: {
                let normalizedNote = LoggedEvent.normalizedNote(draftNote)
                onUpdateNote(normalizedNote)
                isShowingNote = normalizedNote != nil
                isShowingNoteEditor = false
            }
        }
        .sheet(isPresented: $isShowingDateTimeEditor) {
            EventDateTimeEditor(eventTitle: title, loggedAt: $draftLoggedAt) {
                isShowingDateTimeEditor = false
            } onSave: {
                onUpdateLoggedAt(draftLoggedAt)
                isShowingDateTimeEditor = false
            }
        }
    }

    private func delete() {
        if requiresDeleteConfirmation {
            isShowingDeleteConfirmation = true
        } else {
            onDelete()
        }
    }
}

#Preview {
    CalendarView()
}
