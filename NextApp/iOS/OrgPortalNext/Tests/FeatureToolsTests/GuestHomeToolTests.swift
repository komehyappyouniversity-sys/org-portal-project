import XCTest
@testable import FeatureTools

final class GuestHomeToolTests: XCTestCase {
    func testToolsHaveTheSharedDisplayOrder() {
        XCTAssertEqual(
            GuestHomeTool.ordered,
            [.schedule, .diary, .denomination, .meetingMinutes]
        )
    }

    func testOnlyImplementedToolIsAvailable() {
        XCTAssertTrue(GuestHomeTool.schedule.isAvailable)
        GuestHomeTool.ordered.dropFirst().forEach { tool in
            XCTAssertFalse(tool.isAvailable)
        }
    }
}
