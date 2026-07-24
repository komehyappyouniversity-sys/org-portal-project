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
    fun onlyImplementedToolIsAvailable() {
        assertTrue(GuestHomeTool.Schedule.isAvailable)
        GuestHomeTool.ordered.drop(1).forEach { tool ->
            assertFalse(tool.isAvailable)
        }
    }
}
