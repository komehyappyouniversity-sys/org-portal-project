package jp.komehyappyo.member.next.core.data

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import jp.komehyappyo.member.next.core.model.VideoRepeatMode
import jp.komehyappyo.member.next.core.model.VideoRepeatSetting

@Entity(tableName = "video_repeat_settings")
data class VideoRepeatSettingEntity(
    @PrimaryKey val videoId: String,
    val userId: String,
    val isEnabled: Boolean,
    val mode: String,
    val repeatStartSeconds: Double?,
    val repeatEndSeconds: Double?,
)

@Dao
interface VideoRepeatSettingDao {
    @Query("SELECT * FROM video_repeat_settings WHERE videoId = :videoId LIMIT 1")
    suspend fun find(videoId: String): VideoRepeatSettingEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(setting: VideoRepeatSettingEntity)
}

class RoomVideoRepeatSettingRepository(
    private val dao: VideoRepeatSettingDao,
) : VideoRepeatSettingRepository {
    override suspend fun setting(videoId: String): VideoRepeatSetting? =
        dao.find(videoId)?.toDomain()

    override suspend fun save(setting: VideoRepeatSetting) {
        dao.upsert(setting.toEntity())
    }
}

private fun VideoRepeatSetting.toEntity() = VideoRepeatSettingEntity(
    videoId = videoId,
    userId = userId,
    isEnabled = isEnabled,
    mode = mode.rawValue,
    repeatStartSeconds = repeatStartSeconds,
    repeatEndSeconds = repeatEndSeconds,
)

private fun VideoRepeatSettingEntity.toDomain() = VideoRepeatSetting(
    userId = userId,
    videoId = videoId,
    isEnabled = isEnabled,
    mode = VideoRepeatMode.fromValue(mode),
    repeatStartSeconds = repeatStartSeconds,
    repeatEndSeconds = repeatEndSeconds,
)
