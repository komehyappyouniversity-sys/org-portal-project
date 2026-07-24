import XCTest
@testable import FeatureTools

final class GuestHomeToolTests: XCTestCase {
    func testToolsHaveTheSharedDisplayOrder() {
        XCTAssertEqual(
            GuestHomeTool.ordered,
            [.schedule, .diary, .denomination, .meetingMinutes]
        )
    }

    func testImplementedToolsAreAvailable() {
        XCTAssertTrue(GuestHomeTool.schedule.isAvailable)
        XCTAssertTrue(GuestHomeTool.diary.isAvailable)
        XCTAssertFalse(GuestHomeTool.denomination.isAvailable)
        XCTAssertFalse(GuestHomeTool.meetingMinutes.isAvailable)
    }
}
