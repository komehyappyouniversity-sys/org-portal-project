package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.model.Schedule
import java.time.ZoneId
import java.time.format.DateTimeFormatter

object ScheduleCsvExporter {
    private val formatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME

    fun export(schedules: List<Schedule>, zoneId: ZoneId = ZoneId.systemDefault()): String {
        val header = listOf(
            "id",
            "title",
            "startDateTime",
            "endDateTime",
            "timeOfDay",
            "location",
            "memo",
            "category",
        )
        val rows = schedules.map { schedule ->
            listOf(
                schedule.id.toString(),
                schedule.title,
                formatter.format(schedule.startDateTime.atZone(zoneId)),
                formatter.format(schedule.endDateTime.atZone(zoneId)),
                schedule.timeOfDay.name,
                schedule.location,
                schedule.memo,
                schedule.category?.name.orEmpty(),
            )
        }
        return (listOf(header) + rows).joinToString("\r\n") { row ->
            row.joinToString(",") { value -> "\"${value.replace("\"", "\"\"")}\"" }
        } + "\r\n"
    }
}
