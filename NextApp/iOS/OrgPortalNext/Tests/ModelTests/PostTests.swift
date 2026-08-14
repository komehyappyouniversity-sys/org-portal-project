import XCTest
@testable import Model

final class PostTests: XCTestCase {
    func testRadioProgramIsPlayableFromBroadcastStartAndAfterBroadcastEnd() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let program = RadioProgram(
            id: "radio-1",
            communityId: "org-1",
            title: "番組",
            description: "",
            imageUrl: "",
            audioUrl: URL(string: "https://example.com/radio.mp3")!,
            broadcastStartAt: start,
            broadcastEndAt: start.addingTimeInterval(3_600)
        )

        XCTAssertFalse(RadioPlaybackPolicy.isPlayable(program, at: start.addingTimeInterval(-0.001)))
        XCTAssertTrue(RadioPlaybackPolicy.isPlayable(program, at: start))
        XCTAssertTrue(RadioPlaybackPolicy.isPlayable(program, at: start.addingTimeInterval(7_200)))
    }

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
