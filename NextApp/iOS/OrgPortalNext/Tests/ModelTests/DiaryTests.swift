import XCTest
@testable import Model

final class DiaryTests: XCTestCase {
    func testTitleIsRequired() {
        let diary = Diary(userId: "guest", title: "  ")

        XCTAssertThrowsError(try diary.validated()) { error in
            XCTAssertEqual(error as? DiaryValidationError, .titleRequired)
        }
    }

    func testMaximumPhotoCountIsFive() throws {
        let fivePhotos = (0..<Diary.maximumPhotoCount).map { "photo-\($0).jpg" }
        XCTAssertNoThrow(
            try Diary(
                userId: "guest",
                title: "写真日記",
                photoUrls: fivePhotos
            ).validated()
        )

        XCTAssertThrowsError(
            try Diary(
                userId: "guest",
                title: "写真日記",
                photoUrls: fivePhotos + ["extra.jpg"]
            ).validated()
        ) { error in
            XCTAssertEqual(error as? DiaryValidationError, .tooManyPhotos)
        }
    }

    func testMoodHasFiveSharedCases() {
        XCTAssertEqual(
            DiaryMood.allCases,
            [.veryGood, .good, .neutral, .slightlyBad, .bad]
        )
    }
}
