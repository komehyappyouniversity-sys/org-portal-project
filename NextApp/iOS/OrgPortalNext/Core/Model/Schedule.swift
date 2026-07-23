import Foundation

public enum ScheduleTimeOfDay: String, CaseIterable, Codable, Sendable {
    case allDay
    case morning
    case afternoon
    case evening
    case specified

    public var localizationKey: String {
        switch self {
        case .allDay: "time_of_day.all_day"
        case .morning: "time_of_day.morning"
        case .afternoon: "time_of_day.afternoon"
        case .evening: "time_of_day.evening"
        case .specified: "time_of_day.specified"
        }
    }
}

public enum RecurrenceFrequency: String, CaseIterable, Codable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly
}

public struct RecurrenceRule: Equatable, Codable, Sendable {
    public var frequency: RecurrenceFrequency
    public var interval: Int
    public var endDate: Date?

    public init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        endDate: Date? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
    }
}

public struct ReminderSetting: Equatable, Codable, Sendable {
    public var notifyBeforeMinutes: Int
    public var isEnabled: Bool

    public init(notifyBeforeMinutes: Int = 10, isEnabled: Bool = false) {
        self.notifyBeforeMinutes = notifyBeforeMinutes
        self.isEnabled = isEnabled
    }
}

public struct ScheduleCategory: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var userId: String
    public var name: String
    public var colorHex: String

    public init(
        id: UUID = UUID(),
        userId: String,
        name: String,
        colorHex: String = "#3F7D58"
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.colorHex = colorHex
    }
}

public struct Schedule: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var userId: String
    public var title: String
    public var startDateTime: Date
    public var endDateTime: Date
    public var location: String
    public var timeOfDay: ScheduleTimeOfDay
    public var memo: String
    public var isCompleted: Bool
    public var recurrenceRule: RecurrenceRule?
    public var reminderSetting: ReminderSetting?
    public var category: ScheduleCategory?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: String,
        title: String,
        startDateTime: Date,
        endDateTime: Date,
        location: String = "",
        timeOfDay: ScheduleTimeOfDay = .allDay,
        memo: String = "",
        isCompleted: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        reminderSetting: ReminderSetting? = nil,
        category: ScheduleCategory? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.location = location
        self.timeOfDay = timeOfDay
        self.memo = memo
        self.isCompleted = isCompleted
        self.recurrenceRule = recurrenceRule
        self.reminderSetting = reminderSetting
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validated() throws -> Schedule {
        var result = self
        result.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        result.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        result.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        result.updatedAt = .now

        guard !result.title.isEmpty else {
            throw ScheduleValidationError.titleRequired
        }
        guard result.endDateTime >= result.startDateTime else {
            throw ScheduleValidationError.endBeforeStart
        }
        if let recurrenceRule {
            guard recurrenceRule.interval > 0 else {
                throw ScheduleValidationError.invalidRecurrenceInterval
            }
            if let endDate = recurrenceRule.endDate, endDate < result.startDateTime {
                throw ScheduleValidationError.recurrenceEndsBeforeStart
            }
        }
        if let reminderSetting, reminderSetting.isEnabled {
            guard reminderSetting.notifyBeforeMinutes >= 0 else {
                throw ScheduleValidationError.invalidReminder
            }
        }
        return result
    }
}

public enum ScheduleValidationError: Error, Equatable, Sendable {
    case titleRequired
    case endBeforeStart
    case invalidRecurrenceInterval
    case recurrenceEndsBeforeStart
    case invalidReminder

    public var localizationKey: String {
        switch self {
        case .titleRequired: "error.schedule.title_required"
        case .endBeforeStart, .recurrenceEndsBeforeStart:
            "error.schedule.date_order"
        case .invalidRecurrenceInterval, .invalidReminder:
            "error.schedule.reminder"
        }
    }
}
