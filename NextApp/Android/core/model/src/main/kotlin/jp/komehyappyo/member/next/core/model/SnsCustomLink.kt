package jp.komehyappyo.member.next.core.model

import java.net.URI
import java.util.UUID

data class SnsCustomLink(
    val id: UUID = UUID.randomUUID(),
    val userId: String = "guest-local",
    val title: String,
    val url: String,
    val sortOrder: Int = 0,
) {
    fun validated(): SnsCustomLink {
        val trimmedTitle = title.trim()
        val trimmedUrl = url.trim()
        require(trimmedTitle.isNotEmpty()) { "リンク名を入力してください。" }
        val uri = runCatching { URI(trimmedUrl) }.getOrNull()
        require(
            uri != null &&
                uri.scheme?.lowercase() in setOf("http", "https") &&
                !uri.host.isNullOrBlank(),
        ) {
            "https:// または http:// で始まる正しいURLを入力してください。"
        }
        require(sortOrder >= 0) { "表示順を正しく設定してください。" }
        return copy(title = trimmedTitle, url = trimmedUrl)
    }

    companion object {
        const val MAXIMUM_CUSTOM_LINKS = 2
    }
}
