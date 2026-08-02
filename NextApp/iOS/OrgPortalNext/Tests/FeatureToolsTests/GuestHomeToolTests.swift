import XCTest
@testable import FeatureTools

final class GuestHomeToolTests: XCTestCase {
    func testToolsHaveTheSharedDisplayOrder() {
        XCTAssertEqual(
            GuestHomeTool.ordered,
            [.schedule, .diary, .denomination, .meetingMinutes, .favorites, .youTubeSearch, .personalVideos, .manual]
        )
    }

    func testImplementedToolsAreAvailable() {
        XCTAssertTrue(GuestHomeTool.schedule.isAvailable)
        XCTAssertTrue(GuestHomeTool.diary.isAvailable)
        XCTAssertTrue(GuestHomeTool.denomination.isAvailable)
        XCTAssertTrue(GuestHomeTool.meetingMinutes.isAvailable)
        XCTAssertTrue(GuestHomeTool.favorites.isAvailable)
        XCTAssertTrue(GuestHomeTool.youTubeSearch.isAvailable)
        XCTAssertTrue(GuestHomeTool.personalVideos.isAvailable)
        XCTAssertTrue(GuestHomeTool.manual.isAvailable)
    }
}
