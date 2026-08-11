package jp.komehyappyo.member.next.core.model

data class PostAttachment(
    val type: String,
    val name: String,
    val url: String,
)

data class AdminReply(
    val id: String,
    val postId: String,
    val adminUserId: String,
    val adminName: String,
    val body: String,
    val createdAt: String?,
)

data class MemberPost(
    val id: String,
    val communityId: String,
    val authorUserId: String,
    val authorName: String,
    val title: String,
    val body: String,
    val attachments: List<PostAttachment> = emptyList(),
    val status: String = "submitted",
    val adminReply: String = "",
    val memberHasReadReply: Boolean = true,
    val createdAt: String? = null,
    val updatedAt: String? = null,
) {
    val hasUnreadReply: Boolean
        get() = adminReply.isNotBlank() && !memberHasReadReply

    fun canEdit(userId: String): Boolean = authorUserId == userId
}

data class PublicPost(
    val id: String,
    val authorUserId: String,
    val authorName: String,
    val title: String,
    val body: String,
    val categoryId: String?,
    val attachments: List<PostAttachment> = emptyList(),
    val createdAt: String? = null,
)

data class RadioProgram(
    val id: String,
    val communityId: String,
    val title: String,
    val description: String,
    val imageUrl: String,
    val audioUrl: String,
    val broadcastStartAt: java.time.Instant,
    val broadcastEndAt: java.time.Instant,
)

data class RadioPlaybackRecord(
    val userId: String,
    val programId: String,
    val lastPositionSeconds: Long = 0,
    val playCount: Int = 0,
    val lastPlayedAt: java.time.Instant? = null,
)
