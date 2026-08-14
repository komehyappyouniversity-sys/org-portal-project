import XCTest
@testable import Model

final class VideoRepeatSettingTests: XCTestCase {
    func testFullVideoRepeatKeepsReservedRangeFieldsUnused() throws {
        let setting = VideoRepeatSetting(
            userId: "guest-local",
            videoId: "video-1",
            isEnabled: true
        )

        XCTAssertEqual(setting.mode, .full)
        XCTAssertNil(setting.repeatStartSeconds)
        XCTAssertNil(setting.repeatEndSeconds)

        let decoded = try JSONDecoder().decode(
            VideoRepeatSetting.self,
            from: JSONEncoder().encode(setting)
        )
        XCTAssertEqual(decoded, setting)
        XCTAssertEqual(decoded.mode.rawValue, "full")
    }
}
