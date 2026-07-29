package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PostTest {
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
