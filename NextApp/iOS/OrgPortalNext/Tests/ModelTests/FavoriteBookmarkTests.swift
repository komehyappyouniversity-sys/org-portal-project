import XCTest
@testable import Model

final class FavoriteBookmarkTests: XCTestCase {
    func testAccountCredentialsValidation() {
        XCTAssertNil(
            AccountCredentials(
                email: "member@example.com",
                password: "password",
                passwordConfirmation: "password",
                name: "根津 孝誠",
                furigana: "ねづ こうせい"
            ).validationMessage()
        )
        XCTAssertNotNil(
            AccountCredentials(email: "invalid", password: "password").validationMessage()
        )
        XCTAssertNotNil(
            AccountCredentials(
                email: "member@example.com",
                password: "password",
                passwordConfirmation: "different",
                name: "根津 孝誠",
                furigana: "ねづ こうせい"
            ).validationMessage()
        )
        XCTAssertNotNil(
            AccountCredentials(
                email: "member@example.com",
                password: "password",
                passwordConfirmation: "password"
            ).validationMessage()
        )
    }

    func testCommunityCodeParserSupportsCodeAndInvitationURL() {
        XCTAssertEqual(CommunityCodeParser.parse("  K100U  "), "k100u")
        XCTAssertEqual(
            CommunityCodeParser.parse(
                "https://example.com/community/join?communityCode=K100U"
            ),
            "k100u"
        )
        XCTAssertEqual(
            CommunityCodeParser.parse("https://example.com/community/K100U"),
            "k100u"
        )
    }

    func testCommunityCodeParserRejectsEmptyOrExcessivelyLongValues() {
        XCTAssertNil(CommunityCodeParser.parse("   "))
        XCTAssertNil(CommunityCodeParser.parse(String(repeating: "a", count: 101)))
    }

    func testCommunityAdminAccessSupportsOwnerExplicitAndLegacyPermissions() {
        XCTAssertTrue(
            CommunityAdminAccess(
                communityId: "k100u",
                userId: "owner",
                role: "owner",
                permissions: []
            ).canReviewMembers
        )
        XCTAssertTrue(
            CommunityAdminAccess(
                communityId: "k100u",
                userId: "manager",
                role: "manager",
                permissions: [CommunityAdminAccess.memberReviewPermission]
            ).canReviewMembers
        )
        XCTAssertTrue(
            CommunityAdminAccess(
                communityId: "k100u",
                userId: "legacy",
                role: "admin",
                permissions: [],
                isLegacyFullAccess: true
            ).canReviewMembers
        )
        XCTAssertFalse(
            CommunityAdminAccess(
                communityId: "k100u",
                userId: "accountant",
                role: "manager",
                permissions: ["accountingRead"]
            ).canReviewMembers
        )
    }

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
