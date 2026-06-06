import SwiftUI

struct StatisticsView: View {
    private let summaryMetrics = [
        StatisticMetric(title: "Events", value: "48", detail: "+12% vs last week", color: .blue),
        StatisticMetric(title: "Active Days", value: "18", detail: "Last 30 days", color: .green),
        StatisticMetric(title: "Avg Intensity", value: "2.4", detail: "Moderate", color: .orange)
    ]

    private let weeklyFrequency = [
        StatisticBar(label: "Mon", value: 6, color: .blue),
        StatisticBar(label: "Tue", value: 4, color: .blue),
        StatisticBar(label: "Wed", value: 8, color: .blue),
        StatisticBar(label: "Thu", value: 3, color: .blue),
        StatisticBar(label: "Fri", value: 7, color: .blue),
        StatisticBar(label: "Sat", value: 5, color: .blue),
        StatisticBar(label: "Sun", value: 2, color: .blue)
    ]

    private let categoryBreakdown = [
        StatisticBar(label: "Mood", value: 14, color: .yellow),
        StatisticBar(label: "Health", value: 12, color: .red),
        StatisticBar(label: "Workout", value: 9, color: .green),
        StatisticBar(label: "Learning", value: 13, color: .indigo)
    ]

    private let timeOfDayPatterns = [
        StatisticBar(label: "Morning", value: 16, color: .teal),
        StatisticBar(label: "Afternoon", value: 21, color: .teal),
        StatisticBar(label: "Evening", value: 11, color: .teal)
    ]

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
            StatisticSectionHeader(title: "Weekday Frequency", subtitle: "Events by day")
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
            StatisticSectionHeader(title: "Time of Day", subtitle: "When events usually happen")

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
        bars.map(\.value).max() ?? 1
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
                                .frame(height: max(10, proxy.size.height * CGFloat(bar.value) / CGFloat(maxValue)))
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
}

private struct HorizontalBarRow: View {
    let bar: StatisticBar
    let maxValue: Int

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
                        .frame(width: proxy.size.width * CGFloat(bar.value) / CGFloat(maxValue))
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    StatisticsView()
}
