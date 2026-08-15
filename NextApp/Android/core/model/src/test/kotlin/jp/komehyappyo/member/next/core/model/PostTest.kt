package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import java.time.Instant

class PostTest {
    @Test
    fun radioProgramIsPlayableFromBroadcastStartAndAfterBroadcastEnd() {
        val start = Instant.parse("2026-08-14T10:00:00Z")
        val program = RadioProgram(
            id = "radio-1",
            communityId = "org-1",
            title = "番組",
            description = "",
            imageUrl = "",
            audioUrl = "https://example.com/radio.mp3",
            broadcastStartAt = start,
            broadcastEndAt = start.plusSeconds(3_600),
        )

        assertFalse(RadioPlaybackPolicy.isPlayable(program, start.minusMillis(1)))
        assertTrue(RadioPlaybackPolicy.isPlayable(program, start))
        assertTrue(RadioPlaybackPolicy.isPlayable(program, start.plusSeconds(7_200)))
    }

    @Test
    fun radioPlaybackRecordPolicyPreservesAndUpdatesPosition() {
        val now = Instant.parse("2026-08-15T00:00:00Z")
        val existing = RadioPlaybackRecord(
            userId = "member-1",
            programId = "radio-1",
            lastPositionSeconds = 42,
            playCount = 2,
            lastPlayedAt = now.minusSeconds(10),
        )

        val started = RadioPlaybackRecordPolicy.started(
            existing = existing,
            userId = "member-1",
            programId = "radio-1",
            at = now,
        )
        val updated = RadioPlaybackRecordPolicy.updatingPosition(started, 75, now.plusSeconds(1))

        assertEquals(3, started.playCount)
        assertEquals(42, started.lastPositionSeconds)
        assertEquals(3, updated.playCount)
        assertEquals(75, updated.lastPositionSeconds)
    }

    @Test
    fun radioInterruptionPolicyPausesOnLossAndResumesOnlyAfterTransientLoss() {
        assertTrue(RadioPlaybackInterruptionPolicy.shouldPause(-1))
        assertFalse(RadioPlaybackInterruptionPolicy.shouldPause(1))
        assertTrue(RadioPlaybackInterruptionPolicy.shouldResume(true, 1))
        assertFalse(RadioPlaybackInterruptionPolicy.shouldResume(false, 1))
    }

    @Test
    fun radioPresentationUsesSharedActionsAndStatuses() {
        assertEquals("配信前", RadioPlaybackPresentation.primaryAction(false, false, false))
        assertEquals("再生", RadioPlaybackPresentation.primaryAction(true, false, false))
        assertEquals("一時停止", RadioPlaybackPresentation.primaryAction(true, true, true))
        assertEquals("再開", RadioPlaybackPresentation.primaryAction(true, true, false))
        assertEquals("再生中", RadioPlaybackPresentation.status(true))
        assertEquals("一時停止中", RadioPlaybackPresentation.status(false))
        assertEquals("停止", RadioPlaybackPresentation.STOP_ACTION)
    }

    @Test
    fun unreadReplyRequiresReplyAndUnreadFlag() {
        val post = samplePost(adminReply = "回答です", memberHasReadReply = false)
        assertTrue(post.hasUnreadReply)
        assertFalse(post.copy(memberHasReadReply = true).hasUnreadReply)
        assertFalse(post.copy(adminReply = "").hasUnreadReply)
    }

    @Test
    fun onlyAuthorCanEditMemberPost() {
        val post = samplePost()
        assertTrue(post.canEdit("member-1"))
        assertFalse(post.canEdit("member-2"))
    }

    private fun samplePost(
        adminReply: String = "",
        memberHasReadReply: Boolean = true,
    ) = MemberPost(
        id = "post-1",
        communityId = "community-1",
        authorUserId = "member-1",
        authorName = "会員",
        title = "タイトル",
        body = "本文",
        adminReply = adminReply,
        memberHasReadReply = memberHasReadReply,
    )
}
