import SwiftUI

struct TodayScheduleView: View {

    @StateObject private var store = CalendarEventStore()

    var body: some View {
        List {
            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .foregroundColor(.red)
            }

            if store.events.isEmpty {
                Text("今日の予定はありません。")
                    .foregroundColor(.secondary)
            }

            ForEach(store.events) { event in
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.headline)

                    Text(timeText(event))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(event.calendarTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("今日の予定")
        .onAppear {
            store.requestAccessAndLoadToday()
            DailyScheduleNotificationManager.shared.requestPermissionAndSchedule()
        }
    }

    private func timeText(_ event: DailyCalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}
