package jp.komehyappyo.member.next.core.model

import java.net.URI
import java.time.Instant
import java.util.UUID

data class FavoriteBookmark(
    val id: UUID = UUID.randomUUID(),
    val userId: String = "guest-local",
    val title: String,
    val url: String,
    val note: String = "",
    val category: String = UNCATEGORIZED,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validated(now: Instant? = null): FavoriteBookmark {
        val trimmedTitle = title.trim()
        val trimmedUrl = url.trim()
        val trimmedCategory = category.trim().ifEmpty { UNCATEGORIZED }
        require(trimmedTitle.isNotEmpty()) { "タイトルを入力してください。" }
        val uri = runCatching { URI(trimmedUrl) }.getOrNull()
        require(
            uri != null &&
                uri.scheme?.lowercase() in setOf("http", "https") &&
                !uri.host.isNullOrBlank(),
        ) {
            "https:// または http:// で始まる正しいURLを入力してください。"
        }
        return copy(
            title = trimmedTitle,
            url = trimmedUrl,
            note = note.trim(),
            category = trimmedCategory,
            updatedAt = now ?: updatedAt,
        )
    }

    companion object {
        const val UNCATEGORIZED = "未分類"
    }
}
