import SwiftUI

struct HomeView: View {
    private let todayEventCount = 7
    private let activeDaysThisWeek = 4

    private let lastEvent = HomeEvent(
        title: "Headache",
        category: "Health",
        time: "14:32",
        icon: "heart.text.square",
        color: .red
    )

    private let categoryShortcuts = [
        HomeCategoryShortcut(name: "Mood", icon: "face.smiling", color: .yellow, count: 3),
        HomeCategoryShortcut(name: "Health", icon: "heart.text.square", color: .red, count: 2),
        HomeCategoryShortcut(name: "Workout", icon: "figure.run", color: .green, count: 1),
        HomeCategoryShortcut(name: "Learning", icon: "book", color: .indigo, count: 1)
    ]

    private let activityLevels = [0, 1, 2, 0, 3, 1, 2, 4, 1, 0, 2, 3, 1, 2]

    private let recentEvents = [
        HomeEvent(title: "Headache", category: "Health", time: "14:32", icon: "heart.text.square", color: .red),
        HomeEvent(title: "Focused", category: "Mood", time: "11:10", icon: "face.smiling", color: .yellow),
        HomeEvent(title: "Walk", category: "Workout", time: "08:45", icon: "figure.walk", color: .green),
        HomeEvent(title: "SwiftUI", category: "Learning", time: "Yesterday", icon: "book", color: .indigo)
    ]

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
                Text("\(todayEventCount)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text("events logged")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("\(activeDaysThisWeek) active days this week")
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
            EventRow(event: lastEvent, showsDivider: false)
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

            VStack(spacing: 0) {
                ForEach(Array(recentEvents.enumerated()), id: \.element.id) { index, event in
                    EventRow(event: event, showsDivider: index < recentEvents.count - 1)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
}

private struct HomeEvent: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let time: String
    let icon: String
    let color: Color
}

private struct HomeCategoryShortcut: Identifiable {
    let id = UUID()
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

                Text("\(shortcut.count) today")
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
