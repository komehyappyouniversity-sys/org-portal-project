package jp.komehyappyo.member.next.core.notifications

import android.content.Intent
import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class SupportNotificationRouteTest {
    @Test
    fun resolvesSupportMessageFromExtraAndDeepLink() {
        assertEquals(
            "message-1",
            SupportNotificationRoute.messageId(
                Intent()
                    .putExtra(SupportNotificationRoute.MESSAGE_ID_EXTRA, "message-1"),
            ),
        )
        assertEquals(
            "message-2",
            SupportNotificationRoute.messageId(
                Intent(Intent.ACTION_VIEW, SupportNotificationRoute.uri("message-2")),
            ),
        )
    }

    @Test
    fun ignoresUnrelatedDeepLink() {
        assertNull(
            SupportNotificationRoute.messageId(
                Intent(Intent.ACTION_VIEW, Uri.parse("orgportalnext://announcements/1")),
            ),
        )
    }
}
