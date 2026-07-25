package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AnnouncementTest {
    @Test
    fun publicAnnouncementIsVisibleToGuest() {
        assertTrue(announcement(AnnouncementPublishScope.Public).isVisibleTo(null, emptySet(), false))
    }

    @Test
    fun categoryAnnouncementRequiresMatchingApprovedMembership() {
        val item = announcement(
            AnnouncementPublishScope.Category,
            targetCategoryIds = setOf("health"),
        )
        assertTrue(item.isVisibleTo("user", setOf("health"), true))
        assertFalse(item.isVisibleTo("user", setOf("health"), false))
        assertFalse(item.isVisibleTo("user", setOf("business"), true))
    }

    private fun announcement(
        scope: AnnouncementPublishScope,
        targetCategoryIds: Set<String> = emptySet(),
    ) = Announcement(
        id = "id",
        communityId = "community",
        title = "title",
        body = "body",
        publishScope = scope,
        targetCategoryIds = targetCategoryIds,
    )
}
