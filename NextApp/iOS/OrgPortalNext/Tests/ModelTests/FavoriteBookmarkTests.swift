import XCTest
@testable import Model

final class FavoriteBookmarkTests: XCTestCase {
    func testValidationTrimsValuesAndDefaultsCategory() throws {
        let favorite = try FavoriteBookmark(
            title: " 公式サイト ",
            url: " https://example.com ",
            note: " メモ ",
            category: " "
        ).validated()

        XCTAssertEqual(favorite.title, "公式サイト")
        XCTAssertEqual(favorite.url, "https://example.com")
        XCTAssertEqual(favorite.note, "メモ")
        XCTAssertEqual(favorite.category, "未分類")
    }

    func testValidationRejectsMissingTitleAndUnsafeURL() {
        XCTAssertThrowsError(
            try FavoriteBookmark(title: " ", url: "https://example.com").validated()
        )
        XCTAssertThrowsError(
            try FavoriteBookmark(title: "危険", url: "javascript:alert(1)").validated()
        )
    }
}
