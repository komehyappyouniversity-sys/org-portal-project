package jp.komehyappyo.member.next.core.notifications

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import jp.komehyappyo.member.next.core.model.Schedule

data class FcmToken(
    val token: String,
    val platform: String = "android",
    val appVersion: String,
    val updatedAtEpochMillis: Long,
)

class NotificationService(private val context: Context) {
    fun hasPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED

    fun scheduleReminder(schedule: Schedule) {
        val reminder = schedule.reminderSetting?.takeIf { it.isEnabled } ?: return
        val triggerAt = schedule.startDateTime
            .minusSeconds(reminder.notifyBeforeMinutes * 60L)
            .toEpochMilli()
        if (triggerAt <= System.currentTimeMillis()) return

        val intent = Intent(context, ScheduleReminderReceiver::class.java)
            .putExtra("title", schedule.title)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            schedule.id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
    }
}
