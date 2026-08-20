package jp.komehyappyo.member.next.core.model

import java.time.Instant

enum class UsageLogEventType(val rawValue: String) {
    VideoDetailOpened("video_detail_opened"),
    VideoPlaybackStarted("video_playback_started"),
    VideoPosition("video_position"),
    VideoCompleted("video_completed"),
    RadioPlayed("radio_played"),
    ;

    companion object {
        fun fromValue(value: String): UsageLogEventType? = entries.firstOrNull {
            it.rawValue == value
        }
    }
}

data class UsageLog(
    val id: String,
    val userId: String,
    val eventType: UsageLogEventType,
    val targetId: String,
    val positionSeconds: Double = 0.0,
    val occurredAt: Instant,
) {
    fun validate() {
        require(id.isNotBlank()) { "id is required" }
        require(userId.isNotBlank()) { "userId is required" }
        require(targetId.isNotBlank()) { "targetId is required" }
        require(positionSeconds.isFinite() && positionSeconds >= 0.0) {
            "positionSeconds must be finite and non-negative"
        }
    }
}
