package jp.komehyappyo.member.next.core.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NotificationNavigationDecisionTest {
    @Test
    fun switchesCommunityOnlyWhenDestinationDiffers() {
        val route = NotificationRoute(NotificationType.Event, "event-1", "community-b")
        assertEquals(
            "community-b",
            NotificationNavigationDecision.resolve(route, "community-a").communityIdToSelect,
        )
        assertNull(
            NotificationNavigationDecision.resolve(route, "community-b").communityIdToSelect,
        )
    }
}
