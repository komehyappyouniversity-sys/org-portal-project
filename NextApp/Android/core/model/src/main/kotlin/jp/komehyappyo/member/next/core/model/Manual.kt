package jp.komehyappyo.member.next.core.model

data class Manual(
    val id: String,
    val communityId: String?,
    val title: String,
    val body: String,
    val sortOrder: Int,
    val imageUrls: List<String> = emptyList(),
    val pdfUrl: String? = null,
    val externalUrl: String? = null,
    val isPublished: Boolean,
) {
    val listIdentity: String
        get() = "${communityId ?: "shared"}:$id"
}
