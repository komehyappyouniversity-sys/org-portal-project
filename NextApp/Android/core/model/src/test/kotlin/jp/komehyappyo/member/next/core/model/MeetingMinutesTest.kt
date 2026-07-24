package jp.komehyappyo.member.next.core.model

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class MeetingMinutesTest {
    @Test
    fun `validation trims editable text`() {
        val start = Instant.ofEpochSecond(1_000)
        val value = MeetingMinutes(
            title = "  定例会議  ",
            recordingStartAt = start,
            recordingEndAt = start.plusSeconds(60),
            recordingDurationSeconds = 60,
            audioFileLocalPath = "/tmp/meeting.m4a",
            transcriptText = "  議事録本文  ",
        ).validated(now = start.plusSeconds(60))

        assertEquals("定例会議", value.title)
        assertEquals("議事録本文", value.transcriptText)
    }

    @Test
    fun `title audio and date range are validated`() {
        assertFailsWith<IllegalArgumentException> {
            MeetingMinutes(title = " ", audioFileLocalPath = "/tmp/meeting.m4a").validated()
        }
        assertFailsWith<IllegalArgumentException> {
            MeetingMinutes(title = "会議", audioFileLocalPath = "").validated()
        }
        val start = Instant.ofEpochSecond(2_000)
        assertFailsWith<IllegalArgumentException> {
            MeetingMinutes(
                title = "会議",
                recordingStartAt = start,
                recordingEndAt = start.minusSeconds(1),
                audioFileLocalPath = "/tmp/meeting.m4a",
            ).validated()
        }
    }
}
