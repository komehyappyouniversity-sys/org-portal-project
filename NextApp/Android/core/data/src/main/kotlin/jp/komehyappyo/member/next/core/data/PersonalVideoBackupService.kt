package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.PersonalVideo
import jp.komehyappyo.member.next.core.model.VideoMemo
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

class PersonalVideoBackupService(
    private val repository: PersonalVideoRepository,
) {
    suspend fun exportData(now: Instant = Instant.now()): ByteArray {
        val videos = JSONArray()
        val memos = JSONArray()
        val personalVideos = repository.observeVideos().first()
        personalVideos.forEach { video ->
            videos.put(
                JSONObject()
                    .put("id", video.id.toString())
                    .put("userId", video.userId)
                    .put("providerVideoId", video.providerVideoId)
                    .put("title", video.title)
                    .put("originalUrl", video.originalUrl)
                    .put("note", video.note)
                    .put("savedPositionSeconds", video.savedPositionSeconds)
                    .put("category", video.category)
                    .put("secondaryCategory", video.secondaryCategory)
                    .put("tertiaryCategory", video.tertiaryCategory)
                    .put("createdAtEpochMillis", video.createdAt.toEpochMilli())
                    .put("updatedAtEpochMillis", video.updatedAt.toEpochMilli()),
            )

            repository.observeMemos(video.id).first().forEach { memo ->
                memos.put(
                    JSONObject()
                        .put("id", memo.id.toString())
                        .put("userId", memo.userId)
                        .put("videoId", memo.videoId.toString())
                        .put("positionSeconds", memo.positionSeconds)
                        .put("memoText", memo.memoText)
                        .put("createdAtEpochMillis", memo.createdAt.toEpochMilli())
                        .put("updatedAtEpochMillis", memo.updatedAt.toEpochMilli()),
                )
            }
        }

        val data = JSONObject()
            .put("format", FORMAT_IDENTIFIER)
            .put("version", CURRENT_VERSION)
            .put("exportedAtEpochMillis", now.toEpochMilli())
            .put("videos", videos)
            .put("memos", memos)
            .toString(2)
            .toByteArray(Charsets.UTF_8)
        return data
    }

    suspend fun importData(data: ByteArray): PersonalVideoBackupImportSummary {
        val root = runCatching { JSONObject(data.toString(Charsets.UTF_8)) }
            .getOrElse { throw PersonalVideoBackupException.InvalidFormat }
        if (root.optString("format") != FORMAT_IDENTIFIER) {
            throw PersonalVideoBackupException.InvalidFormat
        }
        if (root.optInt("version") !in 1..CURRENT_VERSION) {
            throw PersonalVideoBackupException.UnsupportedVersion
        }
        val videos = root.optJSONArray("videos")
            ?: throw PersonalVideoBackupException.InvalidFormat
        val memos = root.optJSONArray("memos") ?: JSONArray()

        var videoCount = 0
        var memoCount = 0

        for (index in 0 until videos.length()) {
            val entry = videos.optJSONObject(index) ?: throw PersonalVideoBackupException.InvalidFormat
            val video = runCatching {
                PersonalVideo(
                    id = UUID.fromString(entry.getString("id")),
                    userId = entry.optString("userId", "guest-local"),
                    providerVideoId = entry.getString("providerVideoId"),
                    title = entry.getString("title"),
                    originalUrl = entry.getString("originalUrl"),
                    note = entry.optString("note"),
                    savedPositionSeconds = entry.optInt("savedPositionSeconds"),
                    category = entry.optString("category"),
                    secondaryCategory = entry.optString("secondaryCategory"),
                    tertiaryCategory = entry.optString("tertiaryCategory"),
                    createdAt = Instant.ofEpochMilli(entry.getLong("createdAtEpochMillis")),
                    updatedAt = Instant.ofEpochMilli(entry.getLong("updatedAtEpochMillis")),
                ).validated()
            }.getOrElse { throw PersonalVideoBackupException.InvalidFormat }
            repository.saveVideo(video)
            videoCount += 1
        }

        for (index in 0 until memos.length()) {
            val entry = memos.optJSONObject(index) ?: throw PersonalVideoBackupException.InvalidFormat
            val memo = runCatching {
                VideoMemo(
                    id = UUID.fromString(entry.getString("id")),
                    userId = entry.optString("userId", "guest-local"),
                    videoId = UUID.fromString(entry.getString("videoId")),
                    positionSeconds = entry.optInt("positionSeconds"),
                    memoText = entry.getString("memoText"),
                    createdAt = Instant.ofEpochMilli(entry.getLong("createdAtEpochMillis")),
                    updatedAt = Instant.ofEpochMilli(entry.getLong("updatedAtEpochMillis")),
                ).validated()
            }.getOrElse { throw PersonalVideoBackupException.InvalidFormat }
            repository.saveMemo(memo)
            memoCount += 1
        }

        return PersonalVideoBackupImportSummary(
            videos = videoCount,
            memos = memoCount,
        )
    }

    companion object {
        const val FORMAT_IDENTIFIER = "org-portal-personal-videos-backup"
        const val CURRENT_VERSION = 1
    }
}

data class PersonalVideoBackupImportSummary(
    val videos: Int,
    val memos: Int,
)

sealed class PersonalVideoBackupException : Exception() {
    data object InvalidFormat : PersonalVideoBackupException()
    data object UnsupportedVersion : PersonalVideoBackupException()
}
