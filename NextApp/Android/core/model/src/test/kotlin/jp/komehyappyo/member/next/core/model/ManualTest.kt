package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

class ManualTest {
    @Test
    fun listIdentitySeparatesSharedAndCommunityDocumentsWithSameId() {
        val shared = manual(null)
        val community = manual("org-1")

        assertEquals("shared:guide", shared.listIdentity)
        assertEquals("org-1:guide", community.listIdentity)
        assertNotEquals(shared.listIdentity, community.listIdentity)
    }

    private fun manual(communityId: String?) = Manual(
        id = "guide",
        communityId = communityId,
        title = "タイトル",
        body = "本文",
        sortOrder = 1,
        isPublished = true,
    )
}
