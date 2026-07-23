import Foundation
import Model
import SwiftData

@Model
public final class ScheduleRecord {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var title: String
    public var startDateTime: Date
    public var endDateTime: Date
    public var location: String
    public var timeOfDayRaw: String
    public var memo: String
    public var isCompleted: Bool
    public var recurrenceFrequencyRaw: String?
    public var recurrenceInterval: Int?
    public var recurrenceEndDate: Date?
    public var reminderMinutes: Int?
    public var reminderEnabled: Bool
    public var categoryId: UUID?
    public var categoryName: String?
    public var categoryColorHex: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(schedule: Schedule) {
        id = schedule.id
        userId = schedule.userId
        title = schedule.title
        startDateTime = schedule.startDateTime
        endDateTime = schedule.endDateTime
        location = schedule.location
        timeOfDayRaw = schedule.timeOfDay.rawValue
        memo = schedule.memo
        isCompleted = schedule.isCompleted
        recurrenceFrequencyRaw = schedule.recurrenceRule?.frequency.rawValue
        recurrenceInterval = schedule.recurrenceRule?.interval
        recurrenceEndDate = schedule.recurrenceRule?.endDate
        reminderMinutes = schedule.reminderSetting?.notifyBeforeMinutes
        reminderEnabled = schedule.reminderSetting?.isEnabled ?? false
        categoryId = schedule.category?.id
        categoryName = schedule.category?.name
        categoryColorHex = schedule.category?.colorHex
        createdAt = schedule.createdAt
        updatedAt = schedule.updatedAt
    }

    public func update(from schedule: Schedule) {
        userId = schedule.userId
        title = schedule.title
        startDateTime = schedule.startDateTime
        endDateTime = schedule.endDateTime
        location = schedule.location
        timeOfDayRaw = schedule.timeOfDay.rawValue
        memo = schedule.memo
        isCompleted = schedule.isCompleted
        recurrenceFrequencyRaw = schedule.recurrenceRule?.frequency.rawValue
        recurrenceInterval = schedule.recurrenceRule?.interval
        recurrenceEndDate = schedule.recurrenceRule?.endDate
        reminderMinutes = schedule.reminderSetting?.notifyBeforeMinutes
        reminderEnabled = schedule.reminderSetting?.isEnabled ?? false
        categoryId = schedule.category?.id
        categoryName = schedule.category?.name
        categoryColorHex = schedule.category?.colorHex
        updatedAt = schedule.updatedAt
    }

    public func domainModel() -> Schedule {
        let recurrenceRule: RecurrenceRule?
        if let frequencyRaw = recurrenceFrequencyRaw,
           let frequency = RecurrenceFrequency(rawValue: frequencyRaw) {
            recurrenceRule = RecurrenceRule(
                frequency: frequency,
                interval: recurrenceInterval ?? 1,
                endDate: recurrenceEndDate
            )
        } else {
            recurrenceRule = nil
        }

        let reminderSetting = reminderMinutes.map {
            ReminderSetting(notifyBeforeMinutes: $0, isEnabled: reminderEnabled)
        }
        let category: ScheduleCategory?
        if let categoryId, let categoryName {
            category = ScheduleCategory(
                id: categoryId,
                userId: userId,
                name: categoryName,
                colorHex: categoryColorHex ?? "#3F7D58"
            )
        } else {
            category = nil
        }

        return Schedule(
            id: id,
            userId: userId,
            title: title,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            location: location,
            timeOfDay: ScheduleTimeOfDay(rawValue: timeOfDayRaw) ?? .allDay,
            memo: memo,
            isCompleted: isCompleted,
            recurrenceRule: recurrenceRule,
            reminderSetting: reminderSetting,
            category: category,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@MainActor
public final class SwiftDataScheduleRepository: ScheduleRepository {
    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        context = modelContainer.mainContext
    }

    public func fetchAll() async throws -> [Schedule] {
        let descriptor = FetchDescriptor<ScheduleRecord>(
            sortBy: [
                SortDescriptor(\.startDateTime),
                SortDescriptor(\.title)
            ]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func fetch(on date: Date, calendar: Calendar = .current) async throws -> [Schedule] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return []
        }
        let descriptor = FetchDescriptor<ScheduleRecord>(
            predicate: #Predicate { record in
                record.startDateTime >= start && record.startDateTime < end
            },
            sortBy: [SortDescriptor(\.startDateTime)]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func save(_ schedule: Schedule) async throws {
        let validated = try schedule.validated()
        let id = validated.id
        let descriptor = FetchDescriptor<ScheduleRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(ScheduleRecord(schedule: validated))
        }
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<ScheduleRecord>(
            predicate: #Predicate { $0.id == id }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }
}
