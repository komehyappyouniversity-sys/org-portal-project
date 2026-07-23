package jp.komehyappyo.member.next.core.model

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class ScheduleTest {
    @Test
    fun `all five time-of-day values are stable`() {
        assertEquals(
            listOf("AllDay", "Morning", "Afternoon", "Evening", "Specified"),
            ScheduleTimeOfDay.entries.map { it.name },
        )
    }

    @Test
    fun `blank title is rejected`() {
        assertFailsWith<IllegalArgumentException> {
            Schedule(
                userId = "guest",
                title = " ",
                startDateTime = Instant.parse("2026-07-23T00:00:00Z"),
                endDateTime = Instant.parse("2026-07-23T01:00:00Z"),
            ).validated()
        }
    }
}
