import SwiftUI

struct EventCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var tintName: String
    var presetItems: [String]

    init(id: UUID = UUID(), name: String, icon: String, tintName: String, presetItems: [String]) {
        self.id = id
        self.name = name
        self.icon = icon
        self.tintName = tintName
        self.presetItems = presetItems
    }

    var tintColor: Color {
        EventCategoryTint.color(named: tintName)
    }

    static let defaults = [
        EventCategory(name: "Mood", icon: "face.smiling", tintName: "Yellow", presetItems: ["Calm", "Focused", "Tired"]),
        EventCategory(name: "Health", icon: "heart.text.square", tintName: "Red", presetItems: ["Headache", "Sleep", "Medication"]),
        EventCategory(name: "Workout", icon: "figure.run", tintName: "Green", presetItems: ["Run", "Walk", "Stretch"]),
        EventCategory(name: "Learning", icon: "book", tintName: "Indigo", presetItems: ["SwiftUI", "Reading", "Course"])
    ]
}

enum EventCategoryStorage {
    static let key = "eventCategories"

    static func decode(_ data: String) -> [EventCategory] {
        guard let jsonData = data.data(using: .utf8),
              let categories = try? JSONDecoder().decode([EventCategory].self, from: jsonData),
              !categories.isEmpty else {
            return EventCategory.defaults
        }

        return categories
    }

    static func encode(_ categories: [EventCategory]) -> String {
        guard let jsonData = try? JSONEncoder().encode(categories),
              let data = String(data: jsonData, encoding: .utf8) else {
            return ""
        }

        return data
    }
}

enum EventCategoryTint {
    static let names = ["Blue", "Red", "Green", "Yellow", "Indigo", "Orange", "Teal", "Purple", "Pink"]

    static func color(named name: String) -> Color {
        switch name {
        case "Red":
            return .red
        case "Green":
            return .green
        case "Yellow":
            return .yellow
        case "Indigo":
            return .indigo
        case "Orange":
            return .orange
        case "Teal":
            return .teal
        case "Purple":
            return .purple
        case "Pink":
            return .pink
        default:
            return .blue
        }
    }
}
