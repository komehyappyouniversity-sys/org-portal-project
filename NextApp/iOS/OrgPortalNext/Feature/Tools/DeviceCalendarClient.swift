import EventKit
import Foundation
import Model

@MainActor
public final class DeviceCalendarClient {
    private let eventStore = EKEventStore()

    public init() {}

    public func add(_ schedule: Schedule) async throws {
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else {
            throw DeviceCalendarError.permissionDenied
        }
        let event = EKEvent(eventStore: eventStore)
        event.title = schedule.title
        event.startDate = schedule.startDateTime
        event.endDate = schedule.endDateTime
        event.isAllDay = schedule.timeOfDay == .allDay
        event.location = schedule.location
        event.notes = schedule.memo
        event.calendar = eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent)
    }
}

public enum DeviceCalendarError: Error {
    case permissionDenied
}
