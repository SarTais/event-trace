import SwiftUI

struct StatisticsView: View {
    @AppStorage(EventCategoryStorage.key) private var storedCategories = ""
    @AppStorage(LoggedEventStorage.key) private var storedEvents = ""

    private var categories: [EventCategory] {
        EventCategoryStorage.decode(storedCategories)
    }

    private var events: [LoggedEvent] {
        LoggedEventStorage.decode(storedEvents)
    }

    private var recentEvents: [LoggedEvent] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: Date())) else {
            return events
        }

        return events.filter { $0.loggedAt >= startDate }
    }

    private var summaryMetrics: [StatisticMetric] {
        [
            StatisticMetric(
                title: "Events",
                value: "\(recentEvents.count)",
                detail: "Last 30 days",
                color: .blue
            ),
            StatisticMetric(
                title: "Active Days",
                value: "\(activeDayCount)",
                detail: "Last 30 days",
                color: .green
            ),
            StatisticMetric(
                title: "Top Category",
                value: topCategoryName,
                detail: topCategoryDetail,
                color: .orange
            )
        ]
    }

    private var activeDayCount: Int {
        let calendar = Calendar.current

        return recentEvents.reduce(into: Set<Date>()) { days, event in
            days.insert(calendar.startOfDay(for: event.loggedAt))
        }
        .count
    }

    private var topCategoryName: String {
        guard let topCategory = topCategory else {
            return "-"
        }

        return topCategory.category.name
    }

    private var topCategoryDetail: String {
        guard let topCategory else {
            return "No events yet"
        }

        return topCategory.count == 1 ? "1 event" : "\(topCategory.count) events"
    }

    private var topCategory: (category: EventCategory, count: Int)? {
        let counts = Dictionary(grouping: recentEvents, by: \.categoryID)
            .mapValues(\.count)

        return categories
            .compactMap { category -> (category: EventCategory, count: Int)? in
                let count = counts[category.id, default: 0]
                return count > 0 ? (category, count) : nil
            }
            .max { $0.count < $1.count }
    }

    private var weeklyFrequency: [StatisticBar] {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        let mondayFirstIndexes = [2, 3, 4, 5, 6, 7, 1]
        let counts = Dictionary(grouping: recentEvents) {
            calendar.component(.weekday, from: $0.loggedAt)
        }
        .mapValues(\.count)

        return mondayFirstIndexes.map { weekday in
            StatisticBar(
                label: symbols[weekday - 1],
                value: counts[weekday, default: 0],
                color: .blue
            )
        }
    }

    private var categoryBreakdown: [StatisticBar] {
        let counts = Dictionary(grouping: recentEvents, by: \.categoryID)
            .mapValues(\.count)

        return categories.map { category in
            StatisticBar(
                label: category.name,
                value: counts[category.id, default: 0],
                color: category.tintColor
            )
        }
    }

    private var timeOfDayPatterns: [StatisticBar] {
        let periods = [
            TimePeriod(label: "Morning", range: 5..<12),
            TimePeriod(label: "Afternoon", range: 12..<17),
            TimePeriod(label: "Evening", range: 17..<22),
            TimePeriod(label: "Night", range: 0..<5)
        ]
        let calendar = Calendar.current

        return periods.map { period in
            let count = recentEvents.filter {
                let hour = calendar.component(.hour, from: $0.loggedAt)
                return period.range.contains(hour) || (period.label == "Night" && hour >= 22)
            }.count

            return StatisticBar(label: period.label, value: count, color: .teal)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    metricGrid
                    weeklyFrequencySection
                    categoryBreakdownSection
                    timeOfDaySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistics")
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(summaryMetrics) { metric in
                VStack(alignment: .leading, spacing: 8) {
                    Text(metric.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(metric.value)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(metric.detail)
                        .font(.caption)
                        .foregroundStyle(metric.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var weeklyFrequencySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatisticSectionHeader(title: "Weekday Frequency", subtitle: "Last 30 days")
            VerticalBarChart(bars: weeklyFrequency)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatisticSectionHeader(title: "Categories", subtitle: "Last 30 days")

            VStack(spacing: 12) {
                ForEach(categoryBreakdown) { bar in
                    HorizontalBarRow(bar: bar, maxValue: categoryBreakdown.map(\.value).max() ?? 1)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var timeOfDaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatisticSectionHeader(title: "Time of Day", subtitle: "Last 30 days")

            VStack(spacing: 12) {
                ForEach(timeOfDayPatterns) { bar in
                    HorizontalBarRow(bar: bar, maxValue: timeOfDayPatterns.map(\.value).max() ?? 1)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatisticMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let color: Color
}

private struct StatisticBar: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    let color: Color
}

private struct TimePeriod {
    let label: String
    let range: Range<Int>
}

private struct StatisticSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)

            Spacer()

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct VerticalBarChart: View {
    let bars: [StatisticBar]

    private var maxValue: Int {
        max(bars.map(\.value).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(bars) { bar in
                VStack(spacing: 8) {
                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(bar.color.opacity(0.8))
                                .frame(height: barHeight(for: bar.value, availableHeight: proxy.size.height))
                        }
                    }
                    .frame(height: 130)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Text(bar.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(bar.label), \(bar.value) events")
            }
        }
    }

    private func barHeight(for value: Int, availableHeight: CGFloat) -> CGFloat {
        let sanitizedHeight = availableHeight.isFinite ? max(availableHeight, 0) : 0
        guard value > 0, sanitizedHeight > 0 else {
            return 0
        }

        let scaledHeight = sanitizedHeight * CGFloat(value) / CGFloat(maxValue)
        return min(sanitizedHeight, max(10, scaledHeight))
    }
}

private struct HorizontalBarRow: View {
    let bar: StatisticBar
    let maxValue: Int

    private var resolvedMaxValue: Int {
        max(maxValue, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(bar.label)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(bar.value)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(bar.color.opacity(0.75))
                        .frame(width: barWidth(availableWidth: proxy.size.width))
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
    }

    private func barWidth(availableWidth: CGFloat) -> CGFloat {
        let sanitizedWidth = availableWidth.isFinite ? max(availableWidth, 0) : 0
        guard bar.value > 0, sanitizedWidth > 0 else {
            return 0
        }

        let scaledWidth = sanitizedWidth * CGFloat(bar.value) / CGFloat(resolvedMaxValue)
        return min(sanitizedWidth, max(scaledWidth, 0))
    }
}

#Preview {
    StatisticsView()
}
