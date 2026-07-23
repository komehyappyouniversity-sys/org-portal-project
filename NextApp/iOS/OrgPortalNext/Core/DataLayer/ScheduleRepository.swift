import Foundation
import Model

@MainActor
public protocol ScheduleRepository: AnyObject {
    func fetchAll() async throws -> [Schedule]
    func fetch(on date: Date, calendar: Calendar) async throws -> [Schedule]
    func save(_ schedule: Schedule) async throws
    func delete(id: UUID) async throws
}
