package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.model.Schedule
import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertContains

class ScheduleCsvExporterTest {
    @Test
    fun `quotes commas and double quotes`() {
        val csv = ScheduleCsvExporter.export(
            listOf(
                Schedule(
                    userId = "guest",
                    title = "会議, \"重要\"",
                    startDateTime = Instant.parse("2026-07-23T01:00:00Z"),
                    endDateTime = Instant.parse("2026-07-23T02:00:00Z"),
                ),
            ),
            ZoneId.of("Asia/Tokyo"),
        )
        assertContains(csv, "\"会議, \"\"重要\"\"\"")
        assertContains(csv, "\r\n")
    }
}
