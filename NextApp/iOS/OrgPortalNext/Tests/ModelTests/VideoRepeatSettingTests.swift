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

final class VideoQuestionTests: XCTestCase {
    func testAnsweredAtRoundTripsAndAnswerClassificationTrimsWhitespace() throws {
        let answeredAt = Date(timeIntervalSince1970: 1_786_680_000)
        let answered = VideoQuestion(
            id: "answered",
            communityId: "org-1",
            memberUid: "member-1",
            videoId: "video-1",
            videoTitle: "動画",
            questionText: "質問",
            answerText: "  回答  ",
            answeredAt: answeredAt
        )
        let unanswered = VideoQuestion(
            id: "unanswered",
            communityId: "org-1",
            memberUid: "member-1",
            videoId: "video-1",
            videoTitle: "動画",
            questionText: "質問",
            answerText: " \n "
        )

        XCTAssertTrue(answered.isAnswered)
        XCTAssertFalse(unanswered.isAnswered)

        let decoded = try JSONDecoder().decode(
            VideoQuestion.self,
            from: JSONEncoder().encode(answered)
        )
        XCTAssertEqual(decoded.answeredAt, answeredAt)
        XCTAssertTrue(decoded.isAnswered)
    }
}
