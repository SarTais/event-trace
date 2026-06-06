import SwiftUI

struct HomeView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @AppStorage(LoggedEventStorage.key) private var storedEvents = ""

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    private var events: [LoggedEvent] {
        LoggedEventStorage.decode(storedEvents)
    }

    private var todayEvents: [LoggedEvent] {
        events.filter { Calendar.current.isDateInToday($0.loggedAt) }
    }

    private var activeDaysThisWeek: Int {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return 0
        }

        let activeDays = events.reduce(into: Set<Date>()) { days, event in
            guard week.contains(event.loggedAt) else {
                return
            }

            days.insert(calendar.startOfDay(for: event.loggedAt))
        }

        return activeDays.count
    }

    private var lastEvent: HomeEvent? {
        events.first.flatMap(homeEvent)
    }

    private var categoryShortcuts: [HomeCategoryShortcut] {
        let todayCounts = Dictionary(grouping: todayEvents, by: \.categoryID)
            .mapValues(\.count)

        return categories.enumerated()
            .sorted { first, second in
                let firstCount = todayCounts[first.element.id, default: 0]
                let secondCount = todayCounts[second.element.id, default: 0]

                if firstCount == secondCount {
                    return first.offset < second.offset
                }

                return firstCount > secondCount
            }
            .prefix(4)
            .map { _, category in
                HomeCategoryShortcut(
                    id: category.id,
                    name: category.name,
                    icon: category.icon,
                    color: category.tintColor,
                    count: todayCounts[category.id, default: 0]
                )
            }
    }

    private var activityLevels: [Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<14).reversed().map { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return 0
            }

            let count = events.filter { event in
                event.loggedAt >= day && event.loggedAt < nextDay
            }.count

            return min(count, 4)
        }
    }

    private var recentEvents: [HomeEvent] {
        events.prefix(5).compactMap(homeEvent)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    todayOverview
                    lastEventSection
                    categoryShortcutsSection
                    activityPreviewSection
                    recentEventsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
        }
    }

    private var todayOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(todayEvents.count)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text(todayEvents.count == 1 ? "event logged" : "events logged")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(activeDaysThisWeek == 1 ? "1 active day this week" : "\(activeDaysThisWeek) active days this week")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var lastEventSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Last Event", systemImage: "clock")

            if let lastEvent {
                EventRow(event: lastEvent, showsDivider: false)
            } else {
                EmptyHomeState(message: "No events logged yet")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var categoryShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Categories", systemImage: "square.grid.2x2")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(categoryShortcuts) { shortcut in
                    CategoryShortcutTile(shortcut: shortcut)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var activityPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Activity", systemImage: "calendar")

            HStack(spacing: 6) {
                ForEach(Array(activityLevels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(activityColor(for: level))
                        .frame(height: 32)
                        .accessibilityLabel(activityAccessibilityLabel(for: level))
                }
            }

            Text("Last 14 days")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent", systemImage: "list.bullet")

            if recentEvents.isEmpty {
                EmptyHomeState(message: "Logged events will appear here")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentEvents.enumerated()), id: \.element.id) { index, event in
                        EventRow(event: event, showsDivider: index < recentEvents.count - 1)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func homeEvent(from event: LoggedEvent) -> HomeEvent? {
        let category = categories.first { $0.id == event.categoryID }

        return HomeEvent(
            id: event.id,
            title: event.title,
            category: category?.name ?? "Deleted category",
            time: relativeTime(for: event.loggedAt),
            icon: category?.icon ?? EventCategory.fallbackIcon,
            color: category?.tintColor ?? .gray
        )
    }

    private func relativeTime(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        return Self.shortDateFormatter.string(from: date)
    }

    private func activityColor(for level: Int) -> Color {
        switch level {
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

    private func activityAccessibilityLabel(for level: Int) -> String {
        level == 0 ? "No events" : "Activity level \(level)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct HomeEvent: Identifiable {
    let id: UUID
    let title: String
    let category: String
    let time: String
    let icon: String
    let color: Color
}

private struct HomeCategoryShortcut: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let color: Color
    let count: Int
}

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

private struct EmptyHomeState: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }
}

private struct EventRow: View {
    let event: HomeEvent
    let showsDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: event.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(event.color)
                    .frame(width: 38, height: 38)
                    .background(event.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.body.weight(.semibold))

                    Text(event.category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(event.time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 52)

            if showsDivider {
                Divider()
                    .padding(.leading, 50)
            }
        }
    }
}

private struct CategoryShortcutTile: View {
    let shortcut: HomeCategoryShortcut

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: shortcut.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(shortcut.color)
                .frame(width: 34, height: 34)
                .background(shortcut.color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(shortcut.count == 1 ? "1 today" : "\(shortcut.count) today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minHeight: 62)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView()
}
