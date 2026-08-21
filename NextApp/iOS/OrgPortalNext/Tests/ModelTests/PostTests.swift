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

    func testRadioPlaybackRecordPolicyPreservesAndUpdatesPosition() {
        let initialDate = Date(timeIntervalSince1970: 100)
        let existing = RadioPlaybackRecord(
            id: "record-1",
            userId: "member-1",
            programId: "radio-1",
            lastPositionSeconds: 42,
            playCount: 2,
            lastPlayedAt: initialDate
        )

        let started = RadioPlaybackRecordPolicy.started(
            existing: existing,
            userId: "member-1",
            programId: "radio-1",
            at: initialDate.addingTimeInterval(1)
        )
        let updated = RadioPlaybackRecordPolicy.updatingPosition(
            started,
            positionSeconds: 75.5,
            at: initialDate.addingTimeInterval(2)
        )

        XCTAssertEqual(started.playCount, 3)
        XCTAssertEqual(started.lastPositionSeconds, 42)
        XCTAssertEqual(updated.playCount, 3)
        XCTAssertEqual(updated.lastPositionSeconds, 75.5)
    }

    func testRadioInterruptionOnlyResumesWhenPreviouslyPlayingAndAllowed() {
        XCTAssertTrue(RadioPlaybackInterruptionPolicy.shouldResume(
            wasPlayingBeforeInterruption: true,
            systemAllowsResume: true
        ))
        XCTAssertFalse(RadioPlaybackInterruptionPolicy.shouldResume(
            wasPlayingBeforeInterruption: false,
            systemAllowsResume: true
        ))
        XCTAssertFalse(RadioPlaybackInterruptionPolicy.shouldResume(
            wasPlayingBeforeInterruption: true,
            systemAllowsResume: false
        ))
    }

    func testRadioPresentationUsesSharedActionsAndStatuses() {
        XCTAssertEqual(
            RadioPlaybackPresentation.primaryAction(
                isPlayable: false,
                isActive: false,
                isPlaying: false
            ),
            "配信前"
        )
        XCTAssertEqual(
            RadioPlaybackPresentation.primaryAction(
                isPlayable: true,
                isActive: false,
                isPlaying: false
            ),
            "再生"
        )
        XCTAssertEqual(
            RadioPlaybackPresentation.primaryAction(
                isPlayable: true,
                isActive: true,
                isPlaying: true
            ),
            "一時停止"
        )
        XCTAssertEqual(
            RadioPlaybackPresentation.primaryAction(
                isPlayable: true,
                isActive: true,
                isPlaying: false
            ),
            "再開"
        )
        XCTAssertEqual(RadioPlaybackPresentation.status(isPlaying: true), "再生中")
        XCTAssertEqual(RadioPlaybackPresentation.status(isPlaying: false), "一時停止中")
        XCTAssertEqual(RadioPlaybackPresentation.stopAction, "停止")
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
