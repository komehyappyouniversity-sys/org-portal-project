package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class VideoRepeatSettingTest {
    @Test
    fun fullVideoRepeatKeepsReservedRangeFieldsUnused() {
        val setting = VideoRepeatSetting(
            userId = "guest-local",
            videoId = "video-1",
            isEnabled = true,
        )

        assertEquals(VideoRepeatMode.Full, setting.mode)
        assertEquals("full", setting.mode.rawValue)
        assertNull(setting.repeatStartSeconds)
        assertNull(setting.repeatEndSeconds)
        assertEquals(VideoRepeatMode.Full, VideoRepeatMode.fromValue("full"))
    }
}
