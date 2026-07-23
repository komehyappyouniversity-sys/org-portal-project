import Foundation
import Model
import UserNotifications

@MainActor
public protocol ScheduleNotificationScheduling: AnyObject {
    func synchronizeReminder(for schedule: Schedule) async throws
    func removeReminder(scheduleId: UUID) async
}

@MainActor
public final class UserNotificationScheduler: ScheduleNotificationScheduling {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func synchronizeReminder(for schedule: Schedule) async throws {
        let identifier = Self.identifier(for: schedule.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let reminder = schedule.reminderSetting, reminder.isEnabled else {
            return
        }
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { return }
        let fireDate = schedule.startDateTime.addingTimeInterval(
            TimeInterval(-reminder.notifyBeforeMinutes * 60)
        )
        guard fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = schedule.title
        content.body = schedule.location
        content.sound = .default
        content.userInfo = ["scheduleId": schedule.id.uuidString]
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        try await center.add(
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
        )
    }

    public func removeReminder(scheduleId: UUID) async {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.identifier(for: scheduleId)]
        )
    }

    private static func identifier(for id: UUID) -> String {
        "schedule-reminder-\(id.uuidString)"
    }
}

public struct FcmToken: Identifiable, Equatable, Codable, Sendable {
    public enum OperatingSystem: String, Codable, Sendable {
        case iOS
        case android
    }

    public enum Environment: String, Codable, Sendable {
        case development
        case production
    }

    public var id: String
    public var userId: String
    public var token: String
    public var appVariant: String
    public var os: OperatingSystem
    public var environment: Environment
    public var updatedAt: Date

    public init(
        id: String,
        userId: String,
        token: String,
        appVariant: String = "next",
        os: OperatingSystem,
        environment: Environment,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.token = token
        self.appVariant = appVariant
        self.os = os
        self.environment = environment
        self.updatedAt = updatedAt
    }
}
