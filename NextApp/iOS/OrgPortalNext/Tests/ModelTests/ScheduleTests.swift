import XCTest
@testable import Model

final class ScheduleTests: XCTestCase {
    func testTitleIsRequired() {
        let value = Schedule(
            userId: "guest",
            title: "  ",
            startDateTime: .now,
            endDateTime: .now.addingTimeInterval(60)
        )
        XCTAssertThrowsError(try value.validated()) { error in
            XCTAssertEqual(error as? ScheduleValidationError, .titleRequired)
        }
    }

    func testEndMustNotPrecedeStart() {
        let start = Date.now
        let value = Schedule(
            userId: "guest",
            title: "予定",
            startDateTime: start,
            endDateTime: start.addingTimeInterval(-1),
            timeOfDay: .specified
        )
        XCTAssertThrowsError(try value.validated()) { error in
            XCTAssertEqual(error as? ScheduleValidationError, .endBeforeStart)
        }
    }

    func testTimeOfDayHasFiveSharedCases() {
        XCTAssertEqual(
            ScheduleTimeOfDay.allCases,
            [.allDay, .morning, .afternoon, .evening, .specified]
        )
    }
}
