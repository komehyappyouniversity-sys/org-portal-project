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

    func testPublicCommunitySearchMatchesNameCodeAndDescription() {
        let community = Community(
            id: "community-1",
            code: "K100U",
            name: "米百俵大学",
            description: "学び合う公開コミュニティ",
            surfingVisible: true
        )

        XCTAssertTrue(community.matchesPublicSearch(""))
        XCTAssertTrue(community.matchesPublicSearch("米百俵"))
        XCTAssertTrue(community.matchesPublicSearch("k100u"))
        XCTAssertTrue(community.matchesPublicSearch("公開コミュニティ"))
        XCTAssertFalse(community.matchesPublicSearch("該当なし"))
        XCTAssertTrue(community.surfingVisible)
    }

    func testAnnouncementVisibilityMatchesPublishScope() {
        let publicAnnouncement = Announcement(
            id: "public",
            communityId: "k100u",
            title: "公開",
            body: "",
            publishScope: .public
        )
        let memberAnnouncement = Announcement(
            id: "member",
            communityId: "k100u",
            title: "会員",
            body: "",
            publishScope: .memberAll
        )
        let categoryAnnouncement = Announcement(
            id: "category",
            communityId: "k100u",
            title: "カテゴリ",
            body: "",
            publishScope: .category,
            targetCategoryIds: ["course-a"]
        )
        let individualAnnouncement = Announcement(
            id: "individual",
            communityId: "k100u",
            title: "個別",
            body: "",
            publishScope: .individual,
            targetUserIds: ["member-1"]
        )

        XCTAssertTrue(
            publicAnnouncement.isVisible(
                userId: nil,
                categoryIds: [],
                isApprovedMember: false
            )
        )
        XCTAssertFalse(
            memberAnnouncement.isVisible(
                userId: "member-1",
                categoryIds: [],
                isApprovedMember: false
            )
        )
        XCTAssertTrue(
            categoryAnnouncement.isVisible(
                userId: "member-1",
                categoryIds: ["course-a"],
                isApprovedMember: true
            )
        )
        XCTAssertFalse(
            categoryAnnouncement.isVisible(
                userId: "member-1",
                categoryIds: ["course-b"],
                isApprovedMember: true
            )
        )
        XCTAssertTrue(
            individualAnnouncement.isVisible(
                userId: "member-1",
                categoryIds: [],
                isApprovedMember: true
            )
        )
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

    func testCommunityAdminAccessRejectsManagerWithoutReviewPermission() {
        XCTAssertFalse(
            CommunityAdminAccess(
                communityId: "k100u",
                userId: "member",
                role: "manager",
                permissions: ["announcementRead"]
            ).canReviewMembers
        )
    }

    func testCommunityAdminPermissionsExposeSharedKeysAndJapaneseLabels() {
        XCTAssertEqual(
            CommunityAdminAccess.delegablePermissions.map { [$0.key, $0.label] },
            [
                ["memberReview", "メンバー閲覧・承認"],
                ["announcementPublish", "お知らせ作成・公開"],
                ["postCommentManagement", "投稿・コメントの管理"],
                ["videoManualManagement", "動画・マニュアル管理"],
                ["eventReservationManagement", "イベント・予約管理"],
                ["questionAnswer", "質問への回答"],
                ["reportResponse", "通報対応"],
                ["accountingRead", "会計の閲覧"],
                ["accountingEditApprove", "会計の編集・承認"],
                ["usageAnalyticsRead", "利用状況の閲覧"]
            ]
        )
    }

    func testCommunityAdminDisplaysKnownLabelsAndPreservesUnknownPermissionsForEditing() {
        let admin = CommunityAdmin(
            userId: "manager",
            permissions: [
                CommunityAdminAccess.legacyMemberReviewPermission,
                CommunityAdminAccess.accountingReadPermission,
                "futurePermission"
            ]
        )

        XCTAssertEqual(
            admin.permissionLabels,
            ["メンバー閲覧・承認", "会計の閲覧", "futurePermission"]
        )
        XCTAssertEqual(
            CommunityAdminAccess.editablePermissions(admin.permissions),
            [
                CommunityAdminAccess.memberReviewPermission,
                CommunityAdminAccess.accountingReadPermission,
                "futurePermission"
            ]
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
