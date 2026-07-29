import XCTest
@testable import Model

final class PostTests: XCTestCase {
    func testUnreadReplyRequiresReplyAndUnreadFlag() {
        let post = makePost(reply: "回答です", hasRead: false)
        XCTAssertTrue(post.hasUnreadReply)
        XCTAssertFalse(makePost(reply: "回答です", hasRead: true).hasUnreadReply)
        XCTAssertFalse(makePost(reply: "", hasRead: false).hasUnreadReply)
    }

    func testOnlyAuthorCanEditMemberPost() {
        let post = makePost()
        XCTAssertTrue(post.canEdit(userId: "member-1"))
        XCTAssertFalse(post.canEdit(userId: "member-2"))
    }

    private func makePost(
        reply: String? = nil,
        hasRead: Bool = true
    ) -> MemberPost {
        MemberPost(
            id: "post-1",
            communityId: "community-1",
            authorUserId: "member-1",
            authorName: "会員",
            title: "タイトル",
            body: "本文",
            legacyAdminReply: reply,
            memberHasReadReply: hasRead
        )
    }
}
