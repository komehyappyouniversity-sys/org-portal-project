package jp.komehyappyo.member.next.core.notifications

import android.content.Intent
import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class NotificationRouteParserTest {
    @Test
    fun parsesAllNotificationDeepLinks() {
        val cases = listOf(
            "orgportalnext://announcements/announcement-1?communityId=community-a" to
                NotificationRoute(NotificationType.Announcement, "announcement-1", "community-a"),
            "orgportalnext://posts/post-1?communityId=community-b" to
                NotificationRoute(NotificationType.AdminReply, "post-1", "community-b"),
            "orgportalnext://video-questions/question-1?communityId=community-c" to
                NotificationRoute(NotificationType.VideoQuestionAnswer, "question-1", "community-c"),
            "orgportalnext://events/event-1?communityId=community-d" to
                NotificationRoute(NotificationType.Event, "event-1", "community-d"),
        )

        cases.forEach { (value, expected) ->
            assertEquals(expected, NotificationRouteParser.route(Uri.parse(value)))
        }
    }

    @Test
    fun parsesPayloadExtrasAndDeepLinkExtra() {
        assertEquals(
            NotificationRoute(NotificationType.AdminReply, "post-2", "community-a"),
            NotificationRouteParser.route(
                Intent()
                    .putExtra(NotificationRouteParser.TYPE_EXTRA, "admin_reply")
                    .putExtra("postId", "post-2")
                    .putExtra(NotificationRouteParser.COMMUNITY_ID_EXTRA, "community-a"),
            ),
        )
        assertEquals(
            NotificationRoute(NotificationType.Event, "event-2", "community-b"),
            NotificationRouteParser.route(
                Intent().putExtra(
                    NotificationRouteParser.DEEP_LINK_EXTRA,
                    "orgportalnext://events/event-2?communityId=community-b",
                ),
            ),
        )
        assertNull(NotificationRouteParser.route(Uri.parse("https://example.com/events/1")))
    }

    @Test
    fun preservesSupportMessageRoute() {
        assertEquals("message-1", SupportNotificationRoute.messageId(
            Intent().putExtra(SupportNotificationRoute.MESSAGE_ID_EXTRA, "message-1")
        ))
        assertEquals("message-2", SupportNotificationRoute.messageId(
            Intent(Intent.ACTION_VIEW, SupportNotificationRoute.uri("message-2")),
        ))
    }
}
