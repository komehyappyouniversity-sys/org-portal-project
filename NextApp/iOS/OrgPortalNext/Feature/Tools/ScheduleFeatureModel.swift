import Foundation
import DataLayer
import Model
import Notifications

@MainActor
public final class ScheduleFeatureModel: ObservableObject {
    @Published public private(set) var schedules: [Schedule] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let repository: ScheduleRepository
    private let notificationScheduler: ScheduleNotificationScheduling

    public init(
        repository: ScheduleRepository,
        notificationScheduler: ScheduleNotificationScheduling
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
    }

    public var todaysSchedules: [Schedule] {
        schedules.filter {
            Calendar.current.isDate($0.startDateTime, inSameDayAs: .now)
        }
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            schedules = try await repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func save(_ schedule: Schedule) async throws {
        let validated = try schedule.validated()
        try await repository.save(validated)
        try await notificationScheduler.synchronizeReminder(for: validated)
        await load()
    }

    public func delete(_ schedule: Schedule) async {
        do {
            try await repository.delete(id: schedule.id)
            await notificationScheduler.removeReminder(scheduleId: schedule.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
