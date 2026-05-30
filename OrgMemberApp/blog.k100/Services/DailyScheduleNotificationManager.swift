import Foundation
import UserNotifications

final class DailyScheduleNotificationManager {

    static let shared = DailyScheduleNotificationManager()

    private init() {}

    func requestPermissionAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            guard granted else { return }
            self.scheduleDailyMorningNotification()
        }
    }

    private func scheduleDailyMorningNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["daily_schedule_6am"])

        let content = UNMutableNotificationContent()
        content.title = "今日の予定"
        content.body = "本日のスケジュールを確認してください。"
        content.sound = .default

        var date = DateComponents()
        date.hour = 6
        date.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: date,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "daily_schedule_6am",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
