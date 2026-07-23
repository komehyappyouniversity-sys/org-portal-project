package jp.komehyappyo.member.next.core.testing

import jp.komehyappyo.member.next.core.model.Schedule
import java.time.Instant

object SampleData {
    val schedule = Schedule(
        userId = "guest",
        title = "サンプル予定",
        startDateTime = Instant.parse("2026-07-23T01:00:00Z"),
        endDateTime = Instant.parse("2026-07-23T02:00:00Z"),
    )
}
