import XCTest
@testable import Model

final class MeetingMinutesTests: XCTestCase {
    func testValidationTrimsEditableText() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let value = try MeetingMinutes(
            title: "  定例会議  ",
            recordingStartAt: start,
            recordingEndAt: start.addingTimeInterval(60),
            recordingDurationSeconds: 60,
            audioFileLocalPath: "/tmp/meeting.caf",
            transcriptText: "  議事録本文  "
        ).validated(now: start.addingTimeInterval(60))

        XCTAssertEqual(value.title, "定例会議")
        XCTAssertEqual(value.transcriptText, "議事録本文")
    }

    func testRequiredTitleAndAudioAreValidated() {
        XCTAssertThrowsError(
            try MeetingMinutes(
                title: " ",
                audioFileLocalPath: "/tmp/meeting.caf"
            ).validated()
        ) { error in
            XCTAssertEqual(error as? MeetingMinutesValidationError, .titleRequired)
        }
        XCTAssertThrowsError(
            try MeetingMinutes(title: "会議", audioFileLocalPath: "").validated()
        ) { error in
            XCTAssertEqual(error as? MeetingMinutesValidationError, .audioFileRequired)
        }
    }

    func testEndBeforeStartIsRejected() {
        let start = Date(timeIntervalSince1970: 2_000)
        XCTAssertThrowsError(
            try MeetingMinutes(
                title: "会議",
                recordingStartAt: start,
                recordingEndAt: start.addingTimeInterval(-1),
                audioFileLocalPath: "/tmp/meeting.caf"
            ).validated()
        ) { error in
            XCTAssertEqual(error as? MeetingMinutesValidationError, .invalidDateRange)
        }
    }
}
