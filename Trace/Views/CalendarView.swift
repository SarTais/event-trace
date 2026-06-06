import SwiftUI

struct CalendarView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @AppStorage(LoggedEventStorage.key) private var storedEvents = ""
    @AppStorage(TraceSettingsStorage.confirmBeforeDeleteKey) private var requireConfirmationBeforeDelete = true
    @State private var selectedCategoryID: UUID?
    @State private var selectedDate = Date()

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    private var events: [LoggedEvent] {
        LoggedEventStorage.decode(storedEvents)
    }

    private var filteredEvents: [LoggedEvent] {
        guard let selectedCategoryID else {
            return events
        }

        return events.filter { $0.categoryID == selectedCategoryID }
    }

    private var monthDays: [CalendarDay] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let groupedEvents = Dictionary(grouping: filteredEvents) {
            calendar.startOfDay(for: $0.loggedAt)
        }

        guard let month = calendar.dateInterval(of: .month, for: Date()),
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
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: Date()) else {
            return 0
        }

        return filteredEvents.filter { month.contains($0.loggedAt) }.count
    }

    private var activeDaysThisMonth: Int {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: Date()) else {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    categoryFilter
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

    private var monthOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.monthFormatter.string(from: Date()))
                    .font(.title3.weight(.semibold))

                Text(monthSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                            color: categoryColor(for: event),
                            requiresDeleteConfirmation: requireConfirmationBeforeDelete
                        ) {
                            removeEvent(event)
                        }

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

    private func removeEvent(_ event: LoggedEvent) {
        storedEvents = LoggedEventStorage.removing(eventID: event.id, from: storedEvents)
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
        formatter.dateFormat = "MMMM d"
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
    let color: Color
    let requiresDeleteConfirmation: Bool
    let onDelete: () -> Void
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
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
