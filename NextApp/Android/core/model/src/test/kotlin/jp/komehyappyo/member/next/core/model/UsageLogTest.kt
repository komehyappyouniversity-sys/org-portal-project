package jp.komehyappyo.member.next.core.model

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class UsageLogTest {
    @Test
    fun validUsageLogUsesExpectedEventValues() {
        val log = UsageLog(
            id = "log-1",
            userId = "member-1",
            eventType = UsageLogEventType.VideoPosition,
            targetId = "video-1",
            positionSeconds = 60.0,
            occurredAt = Instant.parse("2026-08-15T00:00:00Z"),
        )

        log.validate()
        assertEquals("video_position", log.eventType.rawValue)
        assertEquals(UsageLogEventType.VideoPosition, UsageLogEventType.fromValue("video_position"))
        assertEquals(5, UsageLogEventType.entries.size)
    }

    @Test
    fun usageLogRejectsBlankIdentifiersAndInvalidPosition() {
        assertFailsWith<IllegalArgumentException> {
            UsageLog(
                id = " ",
                userId = "member-1",
                eventType = UsageLogEventType.RadioPlayed,
                targetId = "radio-1",
                occurredAt = Instant.EPOCH,
            ).validate()
        }
        assertFailsWith<IllegalArgumentException> {
            UsageLog(
                id = "log-1",
                userId = "member-1",
                eventType = UsageLogEventType.VideoPosition,
                targetId = "video-1",
                positionSeconds = Double.NaN,
                occurredAt = Instant.EPOCH,
            ).validate()
        }
    }
}
