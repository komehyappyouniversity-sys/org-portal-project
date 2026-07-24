package jp.komehyappyo.member.next.feature.tools

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class GuestHomeToolTest {
    @Test
    fun toolsHaveTheSharedDisplayOrder() {
        assertEquals(
            listOf(
                GuestHomeTool.Schedule,
                GuestHomeTool.Diary,
                GuestHomeTool.Denomination,
                GuestHomeTool.MeetingMinutes,
            ),
            GuestHomeTool.ordered,
        )
    }

    @Test
    fun implementedToolsAreAvailable() {
        assertTrue(GuestHomeTool.Schedule.isAvailable)
        assertTrue(GuestHomeTool.Diary.isAvailable)
        assertTrue(GuestHomeTool.Denomination.isAvailable)
        assertFalse(GuestHomeTool.MeetingMinutes.isAvailable)
    }
}
