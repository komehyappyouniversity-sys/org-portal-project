import SwiftData
import XCTest
@testable import DataLayer
import Model

@MainActor
final class SwiftDataScheduleRepositoryTests: XCTestCase {
    func testSaveFetchAndDelete() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ScheduleRecord.self,
            configurations: configuration
        )
        let repository = SwiftDataScheduleRepository(modelContainer: container)
        let start = Date.now
        let schedule = Schedule(
            userId: "guest",
            title: "保存テスト",
            startDateTime: start,
            endDateTime: start.addingTimeInterval(3600),
            timeOfDay: .specified
        )

        try await repository.save(schedule)
        let savedSchedules = try await repository.fetchAll()
        XCTAssertEqual(savedSchedules.map(\.title), ["保存テスト"])

        try await repository.delete(id: schedule.id)
        let remainingSchedules = try await repository.fetchAll()
        XCTAssertTrue(remainingSchedules.isEmpty)
    }
}
