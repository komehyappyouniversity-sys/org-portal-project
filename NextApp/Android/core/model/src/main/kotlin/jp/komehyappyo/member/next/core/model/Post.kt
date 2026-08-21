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

object RadioPlaybackPolicy {
    fun isPlayable(program: RadioProgram, at: java.time.Instant): Boolean =
        !at.isBefore(program.broadcastStartAt)
}

data class RadioPlaybackRecord(
    val userId: String,
    val programId: String,
    val lastPositionSeconds: Long = 0,
    val playCount: Int = 0,
    val lastPlayedAt: java.time.Instant? = null,
)

object RadioPlaybackRecordPolicy {
    fun started(
        existing: RadioPlaybackRecord?,
        userId: String,
        programId: String,
        at: java.time.Instant,
    ): RadioPlaybackRecord = RadioPlaybackRecord(
        userId = userId,
        programId = programId,
        lastPositionSeconds = maxOf(0, existing?.lastPositionSeconds ?: 0),
        playCount = (existing?.playCount ?: 0) + 1,
        lastPlayedAt = at,
    )

    fun updatingPosition(
        existing: RadioPlaybackRecord,
        positionSeconds: Long,
        at: java.time.Instant,
    ): RadioPlaybackRecord = existing.copy(
        lastPositionSeconds = maxOf(0, positionSeconds),
        lastPlayedAt = at,
    )
}

object RadioPlaybackInterruptionPolicy {
    fun shouldPause(focusChange: Int): Boolean = focusChange < 0

    fun shouldResume(wasPlayingBeforeTransientLoss: Boolean, focusChange: Int): Boolean =
        wasPlayingBeforeTransientLoss && focusChange > 0
}

object RadioPlaybackPresentation {
    const val PLAY_ACTION = "再生"
    const val PAUSE_ACTION = "一時停止"
    const val RESUME_ACTION = "再開"
    const val STOP_ACTION = "停止"
    const val PLAYING_STATUS = "再生中"
    const val PAUSED_STATUS = "一時停止中"

    fun primaryAction(isPlayable: Boolean, isActive: Boolean, isPlaying: Boolean): String = when {
        !isPlayable -> "配信前"
        isActive && isPlaying -> PAUSE_ACTION
        isActive -> RESUME_ACTION
        else -> PLAY_ACTION
    }

    fun status(isPlaying: Boolean): String = if (isPlaying) PLAYING_STATUS else PAUSED_STATUS
}
