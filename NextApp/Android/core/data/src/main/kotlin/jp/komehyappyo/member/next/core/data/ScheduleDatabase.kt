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
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import jp.komehyappyo.member.next.core.model.Diary
import jp.komehyappyo.member.next.core.model.DiaryMood
import jp.komehyappyo.member.next.core.model.CashDistribution
import jp.komehyappyo.member.next.core.model.MeetingMinutes
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

@Entity(tableName = "diaries")
data class DiaryEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val title: String,
    val body: String,
    val mood: String,
    val photoUrlsJson: String,
    val createdAtEpochMillis: Long,
    val updatedAtEpochMillis: Long,
)

@Entity(tableName = "cash_distributions")
data class CashDistributionEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val distributionDateEpochMillis: Long,
    val title: String,
    val entriesJson: String,
    val createdAtEpochMillis: Long,
    val updatedAtEpochMillis: Long,
)

@Entity(tableName = "meeting_minutes")
data class MeetingMinutesEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val title: String,
    val recordingStartAtEpochMillis: Long,
    val recordingEndAtEpochMillis: Long,
    val recordingDurationSeconds: Int,
    val audioFileLocalPath: String,
    val transcriptText: String,
    val pdfFileLocalPath: String?,
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

@Dao
interface DiaryDao {
    @Query("SELECT * FROM diaries ORDER BY createdAtEpochMillis DESC, title")
    fun observeAll(): Flow<List<DiaryEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(diary: DiaryEntity)

    @Query("DELETE FROM diaries WHERE id = :id")
    suspend fun delete(id: String)
}

@Dao
interface CashDistributionDao {
    @Query(
        "SELECT * FROM cash_distributions " +
            "ORDER BY distributionDateEpochMillis DESC, updatedAtEpochMillis DESC",
    )
    fun observeAll(): Flow<List<CashDistributionEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(distribution: CashDistributionEntity)

    @Query("DELETE FROM cash_distributions WHERE id = :id")
    suspend fun delete(id: String)
}

@Dao
interface MeetingMinutesDao {
    @Query("SELECT * FROM meeting_minutes ORDER BY recordingStartAtEpochMillis DESC")
    fun observeAll(): Flow<List<MeetingMinutesEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(minutes: MeetingMinutesEntity)

    @Query("SELECT * FROM meeting_minutes WHERE id = :id LIMIT 1")
    suspend fun find(id: String): MeetingMinutesEntity?

    @Query("DELETE FROM meeting_minutes WHERE id = :id")
    suspend fun delete(id: String)
}

@Database(
    entities = [
        ScheduleEntity::class,
        DiaryEntity::class,
        CashDistributionEntity::class,
        MeetingMinutesEntity::class,
    ],
    version = 4,
    exportSchema = true,
)
abstract class OrgPortalDatabase : RoomDatabase() {
    abstract fun scheduleDao(): ScheduleDao
    abstract fun diaryDao(): DiaryDao
    abstract fun cashDistributionDao(): CashDistributionDao
    abstract fun meetingMinutesDao(): MeetingMinutesDao

    companion object {
        val migration1To2 = object : Migration(1, 2) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `diaries` (
                        `id` TEXT NOT NULL,
                        `userId` TEXT NOT NULL,
                        `title` TEXT NOT NULL,
                        `body` TEXT NOT NULL,
                        `mood` TEXT NOT NULL,
                        `photoUrlsJson` TEXT NOT NULL,
                        `createdAtEpochMillis` INTEGER NOT NULL,
                        `updatedAtEpochMillis` INTEGER NOT NULL,
                        PRIMARY KEY(`id`)
                    )
                    """.trimIndent(),
                )
            }
        }

        val migration2To3 = object : Migration(2, 3) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `cash_distributions` (
                        `id` TEXT NOT NULL,
                        `userId` TEXT NOT NULL,
                        `distributionDateEpochMillis` INTEGER NOT NULL,
                        `title` TEXT NOT NULL,
                        `entriesJson` TEXT NOT NULL,
                        `createdAtEpochMillis` INTEGER NOT NULL,
                        `updatedAtEpochMillis` INTEGER NOT NULL,
                        PRIMARY KEY(`id`)
                    )
                    """.trimIndent(),
                )
            }
        }

        val migration3To4 = object : Migration(3, 4) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `meeting_minutes` (
                        `id` TEXT NOT NULL,
                        `userId` TEXT NOT NULL,
                        `title` TEXT NOT NULL,
                        `recordingStartAtEpochMillis` INTEGER NOT NULL,
                        `recordingEndAtEpochMillis` INTEGER NOT NULL,
                        `recordingDurationSeconds` INTEGER NOT NULL,
                        `audioFileLocalPath` TEXT NOT NULL,
                        `transcriptText` TEXT NOT NULL,
                        `pdfFileLocalPath` TEXT,
                        `createdAtEpochMillis` INTEGER NOT NULL,
                        `updatedAtEpochMillis` INTEGER NOT NULL,
                        PRIMARY KEY(`id`)
                    )
                    """.trimIndent(),
                )
            }
        }

        fun create(context: Context): OrgPortalDatabase =
            Room.databaseBuilder(
                context.applicationContext,
                OrgPortalDatabase::class.java,
                "org-portal-next.db",
            ).addMigrations(migration1To2, migration2To3, migration3To4).build()
    }
}

object ScheduleRepositories {
    fun createLocal(context: Context): ScheduleRepository {
        val database = OrgPortalDatabase.create(context)
        return RoomScheduleRepository(database.scheduleDao())
    }
}

object DiaryRepositories {
    fun createLocal(context: Context): DiaryRepository {
        val database = OrgPortalDatabase.create(context)
        return RoomDiaryRepository(database.diaryDao())
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

class RoomDiaryRepository(
    private val dao: DiaryDao,
) : DiaryRepository {
    override fun observeAll(): Flow<List<Diary>> =
        dao.observeAll().map { diaries -> diaries.map(DiaryEntity::toDomain) }

    override suspend fun save(diary: Diary) {
        dao.upsert(diary.validated(now = diary.updatedAt).toEntity())
    }

    override suspend fun delete(id: UUID) {
        dao.delete(id.toString())
    }
}

private fun Diary.toEntity() = DiaryEntity(
    id = id.toString(),
    userId = userId,
    title = title,
    body = body,
    mood = mood.name,
    photoUrlsJson = photoUrls.joinToString(separator = "\n"),
    createdAtEpochMillis = createdAt.toEpochMilli(),
    updatedAtEpochMillis = updatedAt.toEpochMilli(),
)

class RoomCashDistributionRepository(
    private val dao: CashDistributionDao,
) : CashDistributionRepository {
    override fun observeAll(): Flow<List<CashDistribution>> =
        dao.observeAll().map { values -> values.map(CashDistributionEntity::toDomain) }

    override suspend fun save(distribution: CashDistribution) {
        dao.upsert(distribution.validated(now = distribution.updatedAt).toEntity())
    }

    override suspend fun delete(id: UUID) {
        dao.delete(id.toString())
    }
}

private fun CashDistribution.toEntity() = CashDistributionEntity(
    id = id.toString(),
    userId = userId,
    distributionDateEpochMillis = distributionDate.toEpochMilli(),
    title = title,
    entriesJson = toJson().getJSONArray("entries").toString(),
    createdAtEpochMillis = createdAt.toEpochMilli(),
    updatedAtEpochMillis = updatedAt.toEpochMilli(),
)

private fun CashDistributionEntity.toDomain(): CashDistribution =
    org.json.JSONObject()
        .put("id", id)
        .put("userId", userId)
        .put("distributionDateEpochMillis", distributionDateEpochMillis)
        .put("title", title)
        .put("entries", org.json.JSONArray(entriesJson))
        .put("createdAtEpochMillis", createdAtEpochMillis)
        .put("updatedAtEpochMillis", updatedAtEpochMillis)
        .toCashDistribution()

private fun DiaryEntity.toDomain() = Diary(
    id = UUID.fromString(id),
    userId = userId,
    title = title,
    body = body,
    mood = runCatching { DiaryMood.valueOf(mood) }.getOrDefault(DiaryMood.Neutral),
    photoUrls = photoUrlsJson.lines().filter(String::isNotBlank),
    createdAt = Instant.ofEpochMilli(createdAtEpochMillis),
    updatedAt = Instant.ofEpochMilli(updatedAtEpochMillis),
)

class RoomMeetingMinutesRepository(
    private val dao: MeetingMinutesDao,
) : MeetingMinutesRepository {
    override fun observeAll(): Flow<List<MeetingMinutes>> =
        dao.observeAll().map { values -> values.map(MeetingMinutesEntity::toDomain) }

    override suspend fun save(minutes: MeetingMinutes) {
        dao.upsert(minutes.validated(now = minutes.updatedAt).toEntity())
    }

    override suspend fun delete(id: UUID) {
        val existing = dao.find(id.toString())
        existing?.audioFileLocalPath?.let {
            runCatching { java.io.File(it).delete() }
        }
        existing?.pdfFileLocalPath?.let {
            runCatching { java.io.File(it).delete() }
        }
        dao.delete(id.toString())
    }
}

private fun MeetingMinutes.toEntity() = MeetingMinutesEntity(
    id = id.toString(),
    userId = userId,
    title = title,
    recordingStartAtEpochMillis = recordingStartAt.toEpochMilli(),
    recordingEndAtEpochMillis = recordingEndAt.toEpochMilli(),
    recordingDurationSeconds = recordingDurationSeconds,
    audioFileLocalPath = audioFileLocalPath,
    transcriptText = transcriptText,
    pdfFileLocalPath = pdfFileLocalPath,
    createdAtEpochMillis = createdAt.toEpochMilli(),
    updatedAtEpochMillis = updatedAt.toEpochMilli(),
)

private fun MeetingMinutesEntity.toDomain() = MeetingMinutes(
    id = UUID.fromString(id),
    userId = userId,
    title = title,
    recordingStartAt = Instant.ofEpochMilli(recordingStartAtEpochMillis),
    recordingEndAt = Instant.ofEpochMilli(recordingEndAtEpochMillis),
    recordingDurationSeconds = recordingDurationSeconds,
    audioFileLocalPath = audioFileLocalPath,
    transcriptText = transcriptText,
    pdfFileLocalPath = pdfFileLocalPath,
    createdAt = Instant.ofEpochMilli(createdAtEpochMillis),
    updatedAt = Instant.ofEpochMilli(updatedAtEpochMillis),
)
