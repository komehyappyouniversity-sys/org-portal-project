package jp.komehyappyo.member.next.core.model

enum class AccountAccessState {
    Guest,
    Registered,
    PendingApproval,
    Rejected,
    Member,
}

enum class CommunityMembershipStatus {
    Pending,
    Approved,
    Rejected,
}

data class Community(
    val id: String,
    val code: String,
    val name: String,
    val description: String = "",
    val logoUrl: String? = null,
    val homepageUrl: String? = null,
    val isActive: Boolean = true,
    val joinEnabled: Boolean = false,
    val surfingVisible: Boolean = false,
) {
    fun matchesPublicSearch(query: String): Boolean {
        val normalized = query.trim()
        if (normalized.isEmpty()) return true
        return listOf(name, code, description).any {
            it.contains(normalized, ignoreCase = true)
        }
    }
}

data class DistributedVideo(
    val id: String,
    val communityId: String,
    val videoTitle: String,
    val description: String = "",
    val embedHtml: String = "",
    val videoUrl: String = "",
    val vimeoUrl: String = "",
    val providerVideoId: String = "",
    val videoType: String = "distributed_vimeo",
    val thumbnailUrl: String = "",
    val sortOrder: Int = 0,
    val primaryCategoryId: String = "",
    val secondaryCategoryId: String = "",
    val isPublished: Boolean = false,
    val isMembersOnly: Boolean = false,
    val isPremium: Boolean = false,
    val createdAt: String? = null,
    val updatedAt: String? = null,
) {
    val title: String
        get() = videoTitle

    val vimeoVideoId: String
        get() = providerVideoId
}

data class BookingEvent(
    val id: String,
    val communityId: String,
    val title: String,
    val description: String = "",
    val eventDate: String? = null,
    val feeAmount: Int = 0,
    val paymentRequired: Boolean = false,
    val zoomUrl: String? = null,
    val isPublished: Boolean = false,
)

data class BookingSlot(
    val id: String,
    val eventId: String,
    val startAt: String? = null,
    val endAt: String? = null,
    val capacity: Int = 0,
    val reservedCount: Int = 0,
    val paidCount: Int = 0,
    val isOpen: Boolean = true,
) {
    val remainingCount: Int
        get() = (capacity - reservedCount).coerceAtLeast(0)
    val isFull: Boolean
        get() = capacity <= 0 || reservedCount >= capacity
}

data class BookingReservation(
    val eventId: String = "",
    val slotId: String,
    val userId: String,
    val status: String,
    val purchaseStatus: String = "not-required",
)

data class CommunityAuditLog(
    val id: String,
    val action: String,
    val actorUserId: String? = null,
    val targetUserId: String? = null,
    val communityId: String,
    val createdAt: String? = null,
)

data class VideoQuestion(
    val id: String,
    val communityId: String,
    val memberUid: String,
    val videoId: String,
    val videoTitle: String,
    val playbackSeconds: Double = 0.0,
    val memoText: String = "",
    val questionText: String,
    val answerText: String = "",
    val createdAt: String? = null,
    val answeredAt: String? = null,
    val syncStatus: VideoQuestionSyncStatus = VideoQuestionSyncStatus.Synced,
    val clientRequestId: String = "",
) {
    val isAnswered: Boolean
        get() = answerText.isNotBlank()
}

enum class VideoQuestionSyncStatus {
    Draft,
    Sending,
    Synced,
    Failed,
    ;

    val requiresSync: Boolean
        get() = this != Synced

    fun rawValue(): String = name.lowercase()

    companion object {
        fun fromValue(value: String?): VideoQuestionSyncStatus = when (value) {
            "draft" -> Draft
            "sending" -> Sending
            "failed" -> Failed
            else -> Synced
        }
    }
}

enum class VimeoVideoMemoSyncStatus {
    Synced,
    PendingSync,
    ;

    fun rawValue(): String = when (this) {
        Synced -> "synced"
        PendingSync -> "pendingSync"
    }

    companion object {
        fun fromValue(value: String?): VimeoVideoMemoSyncStatus = when (value) {
            "pendingSync" -> PendingSync
            else -> Synced
        }
    }
}

data class VimeoVideoMemo(
    val id: String,
    val text: String,
    val playbackSeconds: Double,
    val createdAtMillis: Long,
    val updatedAtMillis: Long,
    val syncStatus: VimeoVideoMemoSyncStatus = VimeoVideoMemoSyncStatus.Synced,
)

data class CommunityMembership(
    val id: String,
    val communityId: String,
    val userId: String,
    val status: CommunityMembershipStatus,
    val role: String = "member",
    val joinedAt: String? = null,
    val applicantName: String? = null,
    val applicantFurigana: String? = null,
    val applicantEmail: String? = null,
    val createdAt: String? = null,
    val categoryIds: Set<String> = emptySet(),
)

enum class AnnouncementPublishScope {
    Public,
    MemberAll,
    Category,
    Individual,
}

data class AnnouncementAttachment(
    val type: String,
    val name: String,
    val url: String,
)

data class Announcement(
    val id: String,
    val communityId: String,
    val title: String,
    val body: String,
    val publishScope: AnnouncementPublishScope,
    val targetCategoryIds: Set<String> = emptySet(),
    val targetUserIds: Set<String> = emptySet(),
    val attachments: List<AnnouncementAttachment> = emptyList(),
    val zoomUrl: String? = null,
    val videoUrl: String? = null,
    val createdAt: String? = null,
) {
    fun isVisibleTo(
        userId: String?,
        categoryIds: Set<String>,
        isApprovedMember: Boolean,
    ): Boolean = when (publishScope) {
        AnnouncementPublishScope.Public -> true
        AnnouncementPublishScope.MemberAll -> isApprovedMember
        AnnouncementPublishScope.Category ->
            isApprovedMember && targetCategoryIds.any(categoryIds::contains)
        AnnouncementPublishScope.Individual ->
            isApprovedMember && userId != null && userId in targetUserIds
    }
}

data class AnnouncementReadState(
    val userId: String,
    val announcementId: String,
    val readAt: String,
)

data class CommunityAdminAccess(
    val communityId: String,
    val userId: String,
    val role: String,
    val permissions: Set<String>,
    val isLegacyFullAccess: Boolean = false,
) {
    val canReviewMembers: Boolean
        get() = role == "owner" ||
            isLegacyFullAccess ||
            MEMBER_REVIEW_PERMISSION in permissions ||
            LEGACY_MEMBER_REVIEW_PERMISSION in permissions

    companion object {
        const val MEMBER_REVIEW_PERMISSION = "memberReview"
        const val LEGACY_MEMBER_REVIEW_PERMISSION = "メンバー閲覧・承認"
    }
}

data class CommunityAdmin(
    val userId: String,
    val role: String = "admin",
    val permissions: Set<String> = emptySet(),
    val isActive: Boolean = true,
)

object CommunityCodeParser {
    fun parse(value: String): String? {
        val trimmed = value.trim()
        if (trimmed.isEmpty()) return null
        val fromUri = runCatching {
            val uri = java.net.URI(trimmed)
            if (uri.scheme == null) return@runCatching null
            val queryCode = uri.rawQuery
                ?.split("&")
                ?.mapNotNull { part ->
                    val pair = part.split("=", limit = 2)
                    if (pair.size == 2 && pair[0] in setOf("communityCode", "organizationCode", "code")) {
                        java.net.URLDecoder.decode(pair[1], Charsets.UTF_8.name())
                    } else {
                        null
                    }
                }
                ?.firstOrNull()
            queryCode ?: uri.path?.trimEnd('/')?.substringAfterLast('/')
        }.getOrNull()
        return normalize(fromUri ?: trimmed)
    }

    private fun normalize(value: String): String? =
        value.trim().takeIf { it.isNotEmpty() && it.length <= 100 }?.lowercase()
}

data class AccountCredentials(
    val email: String,
    val password: String,
    val passwordConfirmation: String? = null,
    val name: String? = null,
    val furigana: String? = null,
) {
    fun validationError(): String? {
        if (passwordConfirmation != null && name.orEmpty().trim().isEmpty()) {
            return "名前を入力してください。"
        }
        if (passwordConfirmation != null && furigana.orEmpty().trim().isEmpty()) {
            return "ふりがなを入力してください。"
        }
        val normalizedEmail = email.trim()
        if (!EMAIL_PATTERN.matches(normalizedEmail)) {
            return "メールアドレスの形式を確認してください。"
        }
        if (password.length < MINIMUM_PASSWORD_LENGTH) {
            return "パスワードは8文字以上で入力してください。"
        }
        if (passwordConfirmation != null && password != passwordConfirmation) {
            return "確認用パスワードが一致しません。"
        }
        return null
    }

    companion object {
        const val MINIMUM_PASSWORD_LENGTH = 8
        private val EMAIL_PATTERN = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
    }
}
