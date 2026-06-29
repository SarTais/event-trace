import SwiftUI

struct EventCategory: Identifiable, Codable, Equatable {
    static let fallbackIcon = "square.grid.2x2"

    let id: UUID
    var name: String
    var icon: String
    var tintName: String

    init(id: UUID = UUID(), name: String, icon: String, tintName: String) {
        self.id = id
        self.name = name
        self.icon = Self.normalizedIcon(icon)
        self.tintName = tintName
    }

    var tintColor: Color {
        EventCategoryTint.color(named: tintName)
    }

    static let defaults = [
        EventCategory(id: EventCategoryID.mood, name: "Mood", icon: "face.smiling", tintName: "Yellow"),
        EventCategory(id: EventCategoryID.health, name: "Health", icon: "heart.text.square", tintName: "Red"),
        EventCategory(id: EventCategoryID.workout, name: "Workout", icon: "figure.run", tintName: "Green"),
        EventCategory(id: EventCategoryID.learning, name: "Learning", icon: "book", tintName: "Indigo")
    ]

    private static func normalizedIcon(_ icon: String) -> String {
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedIcon.isEmpty ? fallbackIcon : trimmedIcon
    }
}

struct EventPresetItem: Identifiable, Codable, Equatable {
    let id: UUID
    var categoryID: UUID
    var name: String

    init(id: UUID = UUID(), categoryID: UUID, name: String) {
        self.id = id
        self.categoryID = categoryID
        self.name = name
    }

    static let defaults = [
        EventPresetItem(categoryID: EventCategoryID.mood, name: "Calm"),
        EventPresetItem(categoryID: EventCategoryID.mood, name: "Focused"),
        EventPresetItem(categoryID: EventCategoryID.mood, name: "Tired"),
        EventPresetItem(categoryID: EventCategoryID.health, name: "Headache"),
        EventPresetItem(categoryID: EventCategoryID.health, name: "Sleep"),
        EventPresetItem(categoryID: EventCategoryID.health, name: "Medication"),
        EventPresetItem(categoryID: EventCategoryID.workout, name: "Run"),
        EventPresetItem(categoryID: EventCategoryID.workout, name: "Walk"),
        EventPresetItem(categoryID: EventCategoryID.workout, name: "Stretch"),
        EventPresetItem(categoryID: EventCategoryID.learning, name: "SwiftUI"),
        EventPresetItem(categoryID: EventCategoryID.learning, name: "Reading"),
        EventPresetItem(categoryID: EventCategoryID.learning, name: "Course")
    ]
}

struct LoggedEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var categoryID: UUID
    var presetID: UUID?
    var title: String
    var loggedAt: Date
    var note: String?

    init(
        id: UUID = UUID(),
        categoryID: UUID,
        presetID: UUID? = nil,
        title: String,
        loggedAt: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.categoryID = categoryID
        self.presetID = presetID
        self.title = title
        self.loggedAt = loggedAt
        self.note = Self.normalizedNote(note)
    }

    var hasNote: Bool {
        note?.isEmpty == false
    }

    static func normalizedNote(_ note: String?) -> String? {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedNote.isEmpty ? nil : trimmedNote
    }
}

private enum EventCategoryID {
    static let mood = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    static let health = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
    static let workout = UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID()
    static let learning = UUID(uuidString: "00000000-0000-0000-0000-000000000004") ?? UUID()
}

enum LoggedEventStorage {
    static let key = "loggedEvents"

    static func decode(_ data: String) -> [LoggedEvent] {
        guard let jsonData = data.data(using: .utf8),
              let events = try? JSONDecoder().decode([LoggedEvent].self, from: jsonData) else {
            return []
        }

        return events.sorted { $0.loggedAt > $1.loggedAt }
    }

    static func encode(_ events: [LoggedEvent]) -> String {
        guard let jsonData = try? JSONEncoder().encode(events),
              let data = String(data: jsonData, encoding: .utf8) else {
            return ""
        }

        return data
    }

    static func removing(eventID: UUID, from data: String) -> String {
        let events = decode(data).filter { $0.id != eventID }
        return encode(events)
    }

    static func updatingNote(_ note: String?, eventID: UUID, in data: String) -> String {
        var events = decode(data)
        guard let index = events.firstIndex(where: { $0.id == eventID }) else {
            return data
        }

        events[index].note = LoggedEvent.normalizedNote(note)
        return encode(events)
    }
}

enum TraceSettingsStorage {
    static let hapticsEnabledKey = "settings.hapticsEnabled"
    static let confirmBeforeDeleteKey = "settings.confirmBeforeDelete"
}

enum EventCategoryStorage {
    static let key = "eventCategories"

    static func decode(_ data: String) -> [EventCategory] {
        guard let jsonData = data.data(using: .utf8),
              let categories = try? JSONDecoder().decode([EventCategory].self, from: jsonData),
              !categories.isEmpty else {
            return EventCategory.defaults
        }

        return categories.map {
            EventCategory(id: $0.id, name: $0.name, icon: $0.icon, tintName: $0.tintName)
        }
    }

    static func encode(_ categories: [EventCategory]) -> String {
        guard let jsonData = try? JSONEncoder().encode(categories),
              let data = String(data: jsonData, encoding: .utf8) else {
            return ""
        }

        return data
    }
}

enum EventPresetStorage {
    static let key = "eventPresetItems"

    static func decode(_ data: String, categoriesData: String = "") -> [EventPresetItem] {
        if let jsonData = data.data(using: .utf8),
           let presets = try? JSONDecoder().decode([EventPresetItem].self, from: jsonData) {
            return presets
        }

        if let migratedPresets = migrateLegacyPresets(from: categoriesData) {
            return migratedPresets
        }

        return EventPresetItem.defaults
    }

    static func encode(_ presets: [EventPresetItem]) -> String {
        guard let jsonData = try? JSONEncoder().encode(presets),
              let data = String(data: jsonData, encoding: .utf8) else {
            return ""
        }

        return data
    }

    private static func migrateLegacyPresets(from categoriesData: String) -> [EventPresetItem]? {
        guard let jsonData = categoriesData.data(using: .utf8),
              let legacyCategories = try? JSONDecoder().decode([LegacyEventCategory].self, from: jsonData) else {
            return nil
        }

        let presets = legacyCategories.flatMap { category in
            category.presetItems.map {
                EventPresetItem(categoryID: category.id, name: $0)
            }
        }

        return presets.isEmpty ? nil : presets
    }
}

private struct LegacyEventCategory: Decodable {
    let id: UUID
    let presetItems: [String]
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
