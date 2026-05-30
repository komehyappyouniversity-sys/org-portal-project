import Foundation
import EventKit
import Combine

struct DailyCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
}

final class CalendarEventStore: ObservableObject {

    @Published var events: [DailyCalendarEvent] = []
    @Published var errorMessage = ""

    private let eventStore = EKEventStore()

    func requestAccessAndLoadToday() {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard granted else {
                    self.errorMessage = "カレンダーのアクセスが許可されていません。"
                    return
                }

                self.loadTodayEvents()
            }
        }
    }

    func loadTodayEvents() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()

        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )

        let ekEvents = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        DispatchQueue.main.async {
            self.events = ekEvents.map {
                DailyCalendarEvent(
                    id: $0.eventIdentifier,
                    title: $0.title ?? "予定",
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    calendarTitle: $0.calendar.title
                )
            }
        }
    }
}
