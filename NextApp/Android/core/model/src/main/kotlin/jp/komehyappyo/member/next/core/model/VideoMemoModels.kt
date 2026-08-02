package jp.komehyappyo.member.next.core.model

import java.time.Instant
import java.util.UUID

// Existing structures for personal video and memo are still shared between YouTube/ VOD features.

data class PersonalVideo(
    val id: UUID = UUID.randomUUID(),
    val userId: String = "guest-local",
    val providerVideoId: String,
    val title: String,
    val originalUrl: String,
    val note: String = "",
    val savedPositionSeconds: Int = 0,
    val category: String = FavoriteBookmark.UNCATEGORIZED,
    val secondaryCategory: String = "",
    val tertiaryCategory: String = "",
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validated(now: Instant? = null): PersonalVideo {
        var value = this
        value = value.copy(
            title = title.trim(),
            originalUrl = originalUrl.trim(),
            note = note.trim(),
            providerVideoId = providerVideoId.trim(),
            savedPositionSeconds = savedPositionSeconds.coerceAtLeast(0),
            category = category.trim().ifEmpty { FavoriteBookmark.UNCATEGORIZED },
            secondaryCategory = secondaryCategory.trim(),
            tertiaryCategory = if (secondaryCategory.trim().isEmpty()) {
                ""
            } else {
                tertiaryCategory.trim()
            },
            updatedAt = now ?: updatedAt,
        )
        require(value.title.isNotEmpty()) { "タイトルを入力してください。" }
        require(value.providerVideoId.isNotEmpty()) {
            "YouTubeのURLまたは動画IDを確認してください。"
        }
        return value
    }

    val categoryPath: String
        get() = listOf(category, secondaryCategory, tertiaryCategory)
            .filter(String::isNotEmpty)
            .joinToString(" / ")

    val canonicalUrl: String
        get() = "https://www.youtube.com/watch?v=${providerVideoId}"

    val timestampedUrl: String
        get() = if (savedPositionSeconds > 0) {
            "${canonicalUrl}&t=${savedPositionSeconds}s"
        } else {
            canonicalUrl
        }
}

data class VideoMemo(
    val id: UUID = UUID.randomUUID(),
    val userId: String = "guest-local",
    val videoId: UUID,
    val positionSeconds: Int = 0,
    val memoText: String,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validated(now: Instant? = null): VideoMemo {
        var value = this
        value = value.copy(
            memoText = memoText.trim(),
            positionSeconds = positionSeconds.coerceAtLeast(0),
            updatedAt = now ?: updatedAt,
        )
        require(value.memoText.isNotEmpty()) { "メモを入力してください。" }
        return value
    }
}

enum class VideoQuestionStatus(val raw: String) {
    Unanswered("unanswered"),
    Answered("answered");

    companion object {
        fun parse(raw: String?): VideoQuestionStatus = when (raw) {
            Answered.raw -> Answered
            "open" -> Unanswered
            else -> Unanswered
        }
    }
}

enum class VideoQuestionSyncStatus {
    Draft,
    Sending,
    Sent,
    Failed,
}

data class VideoQuestion(
    val id: String = UUID.randomUUID().toString(),
    val clientRequestId: String = UUID.randomUUID().toString(),
    val communityId: String,
    val sourceCommunityId: String? = null,
    val videoId: String,
    val videoType: String = "personal_youtube",
    val videoTitle: String,
    val memberUid: String,
    val memberName: String,
    val memberEmail: String,
    val noteText: String = "",
    val memoText: String = "",
    val questionText: String,
    val seconds: Int = 0,
    val answerText: String = "",
    val answeredByUserId: String? = null,
    val status: VideoQuestionStatus = VideoQuestionStatus.Unanswered,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
    val answeredAt: Instant? = null,
    val syncStatus: VideoQuestionSyncStatus = VideoQuestionSyncStatus.Sent,
) {
    fun validated(now: Instant? = null): VideoQuestion {
        var value = this
        value = value.copy(
            videoId = videoId.trim(),
            videoType = videoType.trim().ifEmpty { "personal_youtube" },
            videoTitle = videoTitle.trim(),
            memberUid = memberUid.trim(),
            memberName = memberName.trim().ifEmpty { "会員" },
            memberEmail = memberEmail.trim(),
            noteText = noteText.trim(),
            memoText = memoText.trim(),
            questionText = questionText.trim(),
            seconds = seconds.coerceAtLeast(0),
            answerText = answerText.trim(),
            updatedAt = now ?: updatedAt,
        )
        require(value.videoId.isNotEmpty()) { "動画IDを入力してください。" }
        require(value.communityId.isNotEmpty()) { "コミュニティを選択してください。" }
        require(value.questionText.isNotEmpty()) { "質問本文を入力してください。" }
        require(value.memberUid.isNotEmpty()) { "利用者情報が不正です。" }
        return value
    }

    val hasAnswer: Boolean get() = status == VideoQuestionStatus.Answered
    val resolvedMemoText: String get() = memoText.ifEmpty { noteText }
}
