package jp.komehyappyo.member.next.core.data

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import jp.komehyappyo.member.next.core.model.RecurrenceFrequency
import jp.komehyappyo.member.next.core.model.RecurrenceRule
import jp.komehyappyo.member.next.core.model.ReminderSetting
import jp.komehyappyo.member.next.core.model.Schedule
import jp.komehyappyo.member.next.core.model.ScheduleCategory
import jp.komehyappyo.member.next.core.model.ScheduleTimeOfDay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

@Entity(tableName = "schedules")
data class ScheduleEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val title: String,
    val startEpochMillis: Long,
    val endEpochMillis: Long,
    val location: String,
    val timeOfDay: String,
    val memo: String,
    val isCompleted: Boolean,
    val recurrenceFrequency: String?,
    val recurrenceInterval: Int?,
    val recurrenceEndEpochMillis: Long?,
    val reminderMinutes: Int?,
    val reminderEnabled: Boolean,
    val categoryId: String?,
    val categoryName: String?,
    val categoryColorHex: String?,
    val createdAtEpochMillis: Long,
    val updatedAtEpochMillis: Long,
)

@Dao
interface ScheduleDao {
    @Query("SELECT * FROM schedules ORDER BY startEpochMillis, title")
    fun observeAll(): Flow<List<ScheduleEntity>>

    @Query(
        "SELECT * FROM schedules WHERE startEpochMillis >= :startMillis " +
            "AND startEpochMillis < :endMillis ORDER BY startEpochMillis",
    )
    fun observeBetween(startMillis: Long, endMillis: Long): Flow<List<ScheduleEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(schedule: ScheduleEntity)

    @Query("DELETE FROM schedules WHERE id = :id")
    suspend fun delete(id: String)
}

@Database(entities = [ScheduleEntity::class], version = 1, exportSchema = true)
abstract class OrgPortalDatabase : RoomDatabase() {
    abstract fun scheduleDao(): ScheduleDao

    companion object {
        fun create(context: Context): OrgPortalDatabase =
            Room.databaseBuilder(
                context.applicationContext,
                OrgPortalDatabase::class.java,
                "org-portal-next.db",
            ).build()
    }
}

object ScheduleRepositories {
    fun createLocal(context: Context): ScheduleRepository {
        val database = OrgPortalDatabase.create(context)
        return RoomScheduleRepository(database.scheduleDao())
    }
}

class RoomScheduleRepository(
    private val dao: ScheduleDao,
    private val zoneId: ZoneId = ZoneId.systemDefault(),
) : ScheduleRepository {
    override fun observeAll(): Flow<List<Schedule>> =
        dao.observeAll().map { schedules -> schedules.map(ScheduleEntity::toDomain) }

    override fun observe(date: LocalDate): Flow<List<Schedule>> {
        val start = date.atStartOfDay(zoneId).toInstant().toEpochMilli()
        val end = date.plusDays(1).atStartOfDay(zoneId).toInstant().toEpochMilli()
        return dao.observeBetween(start, end).map { schedules ->
            schedules.map(ScheduleEntity::toDomain)
        }
    }

    override suspend fun save(schedule: Schedule) {
        dao.upsert(schedule.validated().toEntity())
    }

    override suspend fun delete(id: UUID) {
        dao.delete(id.toString())
    }
}

private fun Schedule.toEntity() = ScheduleEntity(
    id = id.toString(),
    userId = userId,
    title = title,
    startEpochMillis = startDateTime.toEpochMilli(),
    endEpochMillis = endDateTime.toEpochMilli(),
    location = location,
    timeOfDay = timeOfDay.name,
    memo = memo,
    isCompleted = isCompleted,
    recurrenceFrequency = recurrenceRule?.frequency?.name,
    recurrenceInterval = recurrenceRule?.interval,
    recurrenceEndEpochMillis = recurrenceRule?.endDate?.toEpochMilli(),
    reminderMinutes = reminderSetting?.notifyBeforeMinutes,
    reminderEnabled = reminderSetting?.isEnabled ?: false,
    categoryId = category?.id?.toString(),
    categoryName = category?.name,
    categoryColorHex = category?.colorHex,
    createdAtEpochMillis = createdAt.toEpochMilli(),
    updatedAtEpochMillis = updatedAt.toEpochMilli(),
)

private fun ScheduleEntity.toDomain() = Schedule(
    id = UUID.fromString(id),
    userId = userId,
    title = title,
    startDateTime = Instant.ofEpochMilli(startEpochMillis),
    endDateTime = Instant.ofEpochMilli(endEpochMillis),
    location = location,
    timeOfDay = ScheduleTimeOfDay.valueOf(timeOfDay),
    memo = memo,
    isCompleted = isCompleted,
    recurrenceRule = recurrenceFrequency?.let {
        RecurrenceRule(
            frequency = RecurrenceFrequency.valueOf(it),
            interval = recurrenceInterval ?: 1,
            endDate = recurrenceEndEpochMillis?.let(Instant::ofEpochMilli),
        )
    },
    reminderSetting = reminderMinutes?.let { ReminderSetting(it, reminderEnabled) },
    category = if (categoryId != null && categoryName != null) {
        ScheduleCategory(
            id = UUID.fromString(categoryId),
            userId = userId,
            name = categoryName,
            colorHex = categoryColorHex ?: "#3F7D58",
        )
    } else {
        null
    },
    createdAt = Instant.ofEpochMilli(createdAtEpochMillis),
    updatedAt = Instant.ofEpochMilli(updatedAtEpochMillis),
)
