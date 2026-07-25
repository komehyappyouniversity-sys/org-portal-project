import XCTest
@testable import Model

final class FavoriteBookmarkTests: XCTestCase {
    func testValidationTrimsValuesAndDefaultsCategory() throws {
        let favorite = try FavoriteBookmark(
            title: " 公式サイト ",
            url: " https://example.com ",
            note: " メモ ",
            category: " ",
            secondaryCategory: " 学習 ",
            tertiaryCategory: " Swift "
        ).validated()

        XCTAssertEqual(favorite.title, "公式サイト")
        XCTAssertEqual(favorite.url, "https://example.com")
        XCTAssertEqual(favorite.note, "メモ")
        XCTAssertEqual(favorite.category, "未分類")
        XCTAssertEqual(favorite.secondaryCategory, "学習")
        XCTAssertEqual(favorite.tertiaryCategory, "Swift")
        XCTAssertEqual(favorite.categoryPath, "未分類 / 学習 / Swift")
    }

    func testTertiaryCategoryIsClearedWithoutSecondaryCategory() throws {
        let favorite = try FavoriteBookmark(
            title: "公式サイト",
            url: "https://example.com",
            category: "仕事",
            tertiaryCategory: "資料"
        ).validated()

        XCTAssertEqual(favorite.categoryPath, "仕事")
        XCTAssertTrue(favorite.tertiaryCategory.isEmpty)
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
