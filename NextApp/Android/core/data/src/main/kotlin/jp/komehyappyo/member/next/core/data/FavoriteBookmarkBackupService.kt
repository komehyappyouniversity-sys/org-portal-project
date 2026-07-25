package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.FavoriteBookmark
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

class FavoriteBookmarkBackupService(
    private val repository: FavoriteBookmarkRepository,
) {
    suspend fun exportData(now: Instant = Instant.now()): ByteArray {
        val entries = JSONArray()
        repository.observeAll().first().forEach { favorite ->
            entries.put(
                JSONObject()
                    .put("id", favorite.id.toString())
                    .put("userId", favorite.userId)
                    .put("title", favorite.title)
                    .put("url", favorite.url)
                    .put("note", favorite.note)
                    .put("category", favorite.category)
                    .put("categoryPrimary", favorite.category)
                    .put("categorySecondary", favorite.secondaryCategory)
                    .put("categoryTertiary", favorite.tertiaryCategory)
                    .put("createdAtEpochMillis", favorite.createdAt.toEpochMilli())
                    .put("updatedAtEpochMillis", favorite.updatedAt.toEpochMilli()),
            )
        }
        return JSONObject()
            .put("format", FORMAT_IDENTIFIER)
            .put("version", CURRENT_VERSION)
            .put("exportedAtEpochMillis", now.toEpochMilli())
            .put("favorites", entries)
            .toString(2)
            .toByteArray(Charsets.UTF_8)
    }

    suspend fun importData(data: ByteArray): Int {
        val root = runCatching { JSONObject(data.toString(Charsets.UTF_8)) }
            .getOrElse { throw FavoriteBookmarkBackupException.InvalidFormat }
        if (root.optString("format") != FORMAT_IDENTIFIER) {
            throw FavoriteBookmarkBackupException.InvalidFormat
        }
        if (root.optInt("version") !in 1..CURRENT_VERSION) {
            throw FavoriteBookmarkBackupException.UnsupportedVersion
        }
        val entries = root.optJSONArray("favorites")
            ?: throw FavoriteBookmarkBackupException.InvalidFormat
        var restoredCount = 0
        for (index in 0 until entries.length()) {
            val entry = entries.optJSONObject(index)
                ?: throw FavoriteBookmarkBackupException.InvalidFormat
            val favorite = runCatching {
                FavoriteBookmark(
                    id = UUID.fromString(entry.getString("id")),
                    userId = entry.optString("userId", "guest-local"),
                    title = entry.getString("title"),
                    url = entry.getString("url"),
                    note = entry.optString("note"),
                    category = entry.optString(
                        "categoryPrimary",
                        entry.optString("category", FavoriteBookmark.UNCATEGORIZED),
                    ),
                    secondaryCategory = entry.optString("categorySecondary"),
                    tertiaryCategory = entry.optString("categoryTertiary"),
                    createdAt = Instant.ofEpochMilli(
                        entry.getLong("createdAtEpochMillis"),
                    ),
                    updatedAt = Instant.ofEpochMilli(
                        entry.getLong("updatedAtEpochMillis"),
                    ),
                ).validated()
            }.getOrElse {
                throw FavoriteBookmarkBackupException.InvalidFormat
            }
            repository.save(favorite)
            restoredCount += 1
        }
        return restoredCount
    }

    companion object {
        const val FORMAT_IDENTIFIER = "org-portal-favorites-backup"
        const val CURRENT_VERSION = 2
    }
}

sealed class FavoriteBookmarkBackupException : Exception() {
    data object InvalidFormat : FavoriteBookmarkBackupException()
    data object UnsupportedVersion : FavoriteBookmarkBackupException()
}
