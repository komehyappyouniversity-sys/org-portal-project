package jp.komehyappyo.member.next.core.model

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

enum class ScheduleTimeOfDay {
    AllDay,
    Morning,
    Afternoon,
    Evening,
    Specified,
}

enum class RecurrenceFrequency {
    Daily,
    Weekly,
    Monthly,
    Yearly,
}

data class RecurrenceRule(
    val frequency: RecurrenceFrequency,
    val interval: Int = 1,
    val endDate: Instant? = null,
) {
    init {
        require(interval > 0) { "繰り返し間隔は1以上で指定してください。" }
    }
}

data class ReminderSetting(
    val notifyBeforeMinutes: Int,
    val isEnabled: Boolean = true,
) {
    init {
        require(notifyBeforeMinutes >= 0) { "通知時間は0分以上で指定してください。" }
    }
}

data class ScheduleCategory(
    val id: UUID = UUID.randomUUID(),
    val userId: String,
    val name: String,
    val colorHex: String = "#3F7D58",
)

data class Schedule(
    val id: UUID = UUID.randomUUID(),
    val userId: String,
    val title: String,
    val startDateTime: Instant,
    val endDateTime: Instant,
    val location: String = "",
    val timeOfDay: ScheduleTimeOfDay = ScheduleTimeOfDay.AllDay,
    val memo: String = "",
    val isCompleted: Boolean = false,
    val recurrenceRule: RecurrenceRule? = null,
    val reminderSetting: ReminderSetting? = null,
    val category: ScheduleCategory? = null,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validated(): Schedule {
        require(title.trim().isNotEmpty()) { "タイトルを入力してください。" }
        require(!endDateTime.isBefore(startDateTime)) { "終了日時は開始日時以降にしてください。" }
        return copy(title = title.trim())
    }

    fun occursOn(date: LocalDate, zoneId: ZoneId = ZoneId.systemDefault()): Boolean =
        startDateTime.atZone(zoneId).toLocalDate() == date
}
