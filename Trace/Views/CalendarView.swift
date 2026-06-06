import SwiftUI

struct CalendarView: View {
    @State private var selectedCategory = "All"

    private let categories = ["All", "Mood", "Health", "Workout", "Learning"]
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let days = CalendarDay.mockMonth
    private let selectedDay = CalendarDay.mockMonth[17]

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
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedCategory == category ? .white : .primary)
                    .background(selectedCategory == category ? Color.blue : Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                    .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var monthOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("June 2026")
                        .font(.title3.weight(.semibold))

                    Text("22 events across 12 active days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label("Mock", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
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
                ForEach(days) { day in
                    CalendarDayCell(day: day)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("June \(selectedDay.number)", systemImage: "calendar.badge.clock")
                .font(.headline)

            VStack(spacing: 0) {
                CalendarEventRow(title: "Headache", category: "Health", time: "14:32", color: .red)
                Divider().padding(.leading, 12)
                CalendarEventRow(title: "Focused", category: "Mood", time: "11:10", color: .yellow)
                Divider().padding(.leading, 12)
                CalendarEventRow(title: "Walk", category: "Workout", time: "08:45", color: .green)
            }

            Text("Daily details will use logged events once persistence is connected.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let number: Int
    let intensity: Int
    let isSelected: Bool

    static let mockMonth: [CalendarDay] = [
        CalendarDay(number: 1, intensity: 0, isSelected: false),
        CalendarDay(number: 2, intensity: 1, isSelected: false),
        CalendarDay(number: 3, intensity: 2, isSelected: false),
        CalendarDay(number: 4, intensity: 0, isSelected: false),
        CalendarDay(number: 5, intensity: 3, isSelected: false),
        CalendarDay(number: 6, intensity: 1, isSelected: false),
        CalendarDay(number: 7, intensity: 2, isSelected: false),
        CalendarDay(number: 8, intensity: 4, isSelected: false),
        CalendarDay(number: 9, intensity: 1, isSelected: false),
        CalendarDay(number: 10, intensity: 0, isSelected: false),
        CalendarDay(number: 11, intensity: 2, isSelected: false),
        CalendarDay(number: 12, intensity: 3, isSelected: false),
        CalendarDay(number: 13, intensity: 1, isSelected: false),
        CalendarDay(number: 14, intensity: 2, isSelected: false),
        CalendarDay(number: 15, intensity: 0, isSelected: false),
        CalendarDay(number: 16, intensity: 1, isSelected: false),
        CalendarDay(number: 17, intensity: 3, isSelected: false),
        CalendarDay(number: 18, intensity: 4, isSelected: true),
        CalendarDay(number: 19, intensity: 2, isSelected: false),
        CalendarDay(number: 20, intensity: 0, isSelected: false),
        CalendarDay(number: 21, intensity: 1, isSelected: false),
        CalendarDay(number: 22, intensity: 0, isSelected: false),
        CalendarDay(number: 23, intensity: 2, isSelected: false),
        CalendarDay(number: 24, intensity: 1, isSelected: false),
        CalendarDay(number: 25, intensity: 0, isSelected: false),
        CalendarDay(number: 26, intensity: 3, isSelected: false),
        CalendarDay(number: 27, intensity: 2, isSelected: false),
        CalendarDay(number: 28, intensity: 0, isSelected: false),
        CalendarDay(number: 29, intensity: 1, isSelected: false),
        CalendarDay(number: 30, intensity: 0, isSelected: false)
    ]
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
        .accessibilityLabel("June \(day.number), activity level \(day.intensity)")
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
        }
        .frame(minHeight: 50)
    }
}

#Preview {
    CalendarView()
}
