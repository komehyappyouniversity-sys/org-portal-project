package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertFalse
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
