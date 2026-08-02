package jp.komehyappyo.member.next.feature.tools

import kotlin.test.Test
import kotlin.test.assertEquals
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
                GuestHomeTool.Favorites,
                GuestHomeTool.YouTubeSearch,
                GuestHomeTool.PersonalVideos,
                GuestHomeTool.Manual,
            ),
            GuestHomeTool.ordered,
        )
    }

    @Test
    fun implementedToolsAreAvailable() {
        assertTrue(GuestHomeTool.Schedule.isAvailable)
        assertTrue(GuestHomeTool.Diary.isAvailable)
        assertTrue(GuestHomeTool.Denomination.isAvailable)
        assertTrue(GuestHomeTool.MeetingMinutes.isAvailable)
        assertTrue(GuestHomeTool.Favorites.isAvailable)
        assertTrue(GuestHomeTool.YouTubeSearch.isAvailable)
        assertTrue(GuestHomeTool.PersonalVideos.isAvailable)
        assertTrue(GuestHomeTool.Manual.isAvailable)
    }
}
