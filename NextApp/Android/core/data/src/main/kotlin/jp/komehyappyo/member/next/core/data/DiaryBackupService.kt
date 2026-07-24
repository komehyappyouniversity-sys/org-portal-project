package jp.komehyappyo.member.next.core.data

import android.util.Base64
import jp.komehyappyo.member.next.core.model.Diary
import jp.komehyappyo.member.next.core.model.DiaryMood
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID

class DiaryBackupService(
    private val repository: DiaryRepository,
    private val photoStore: DiaryPhotoStore,
) {
    suspend fun exportData(now: Instant = Instant.now()): ByteArray {
        val diaries = repository.observeAll().first()
        val diaryArray = JSONArray()
        diaries.forEach { diary ->
            val photos = JSONArray()
            diary.photoUrls.forEach { reference ->
                val data = photoStore.load(reference)
                photos.put(
                    JSONObject()
                        .put("dataBase64", Base64.encodeToString(data, Base64.NO_WRAP))
                        .put("sha256", sha256(data)),
                )
            }
            diaryArray.put(
                JSONObject()
                    .put("id", diary.id.toString())
                    .put("userId", diary.userId)
                    .put("title", diary.title)
                    .put("body", diary.body)
                    .put("mood", diary.mood.toBackupValue())
                    .put("createdAtEpochMillis", diary.createdAt.toEpochMilli())
                    .put("updatedAtEpochMillis", diary.updatedAt.toEpochMilli())
                    .put("photos", photos),
            )
        }
        return JSONObject()
            .put("format", FORMAT_IDENTIFIER)
            .put("version", CURRENT_VERSION)
            .put("exportedAtEpochMillis", now.toEpochMilli())
            .put("diaries", diaryArray)
            .toString(2)
            .toByteArray(Charsets.UTF_8)
    }

    suspend fun importData(data: ByteArray): Int {
        val root = runCatching { JSONObject(data.toString(Charsets.UTF_8)) }
            .getOrElse { throw DiaryBackupException.InvalidFormat }
        if (root.optString("format") != FORMAT_IDENTIFIER) {
            throw DiaryBackupException.InvalidFormat
        }
        if (root.optInt("version") != CURRENT_VERSION) {
            throw DiaryBackupException.UnsupportedVersion
        }
        val entries = root.optJSONArray("diaries") ?: throw DiaryBackupException.InvalidFormat
        val existing = repository.observeAll().first().associateBy(Diary::id)
        var restoredCount = 0
        for (entryIndex in 0 until entries.length()) {
            val entry = entries.optJSONObject(entryIndex)
                ?: throw DiaryBackupException.InvalidFormat
            val id = runCatching { UUID.fromString(entry.getString("id")) }
                .getOrElse { throw DiaryBackupException.InvalidFormat }
            val mood = diaryMoodFromBackupValue(entry.optString("mood"))
                ?: throw DiaryBackupException.InvalidFormat
            val photos = entry.optJSONArray("photos") ?: JSONArray()
            if (photos.length() > Diary.MAXIMUM_PHOTO_COUNT) {
                throw DiaryBackupException.InvalidFormat
            }

            val decodedPhotos = (0 until photos.length()).map { photoIndex ->
                val photo = photos.optJSONObject(photoIndex)
                    ?: throw DiaryBackupException.InvalidPhoto
                val bytes = runCatching {
                    Base64.decode(photo.getString("dataBase64"), Base64.DEFAULT)
                }.getOrElse { throw DiaryBackupException.InvalidPhoto }
                if (
                    bytes.isEmpty() ||
                    bytes.size > LocalDiaryPhotoStore.MAXIMUM_PHOTO_BYTES ||
                    sha256(bytes) != photo.optString("sha256")
                ) {
                    throw DiaryBackupException.InvalidPhoto
                }
                bytes
            }

            val newReferences = mutableListOf<String>()
            try {
                decodedPhotos.forEach {
                    newReferences += photoStore.saveJpeg(it, id)
                }
                val diary = Diary(
                    id = id,
                    userId = entry.optString("userId", "guest"),
                    title = entry.getString("title"),
                    body = entry.optString("body"),
                    mood = mood,
                    photoUrls = newReferences,
                    createdAt = Instant.ofEpochMilli(entry.getLong("createdAtEpochMillis")),
                    updatedAt = Instant.ofEpochMilli(entry.getLong("updatedAtEpochMillis")),
                )
                repository.save(diary)
                existing[id]?.photoUrls?.forEach { oldReference ->
                    runCatching { photoStore.delete(oldReference) }
                }
                restoredCount += 1
            } catch (error: Throwable) {
                newReferences.forEach { runCatching { photoStore.delete(it) } }
                throw error
            }
        }
        return restoredCount
    }

    private fun sha256(data: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(data)
            .joinToString("") { "%02x".format(it) }

    private fun DiaryMood.toBackupValue(): String = when (this) {
        DiaryMood.VeryGood -> "veryGood"
        DiaryMood.Good -> "good"
        DiaryMood.Neutral -> "neutral"
        DiaryMood.SlightlyBad -> "slightlyBad"
        DiaryMood.Bad -> "bad"
    }

    private fun diaryMoodFromBackupValue(value: String): DiaryMood? = when (value) {
        "veryGood" -> DiaryMood.VeryGood
        "good" -> DiaryMood.Good
        "neutral" -> DiaryMood.Neutral
        "slightlyBad" -> DiaryMood.SlightlyBad
        "bad" -> DiaryMood.Bad
        else -> null
    }

    companion object {
        const val FORMAT_IDENTIFIER = "org-portal-diary-backup"
        const val CURRENT_VERSION = 1
    }
}

sealed class DiaryBackupException : Exception() {
    data object InvalidFormat : DiaryBackupException()
    data object UnsupportedVersion : DiaryBackupException()
    data object InvalidPhoto : DiaryBackupException()
}
