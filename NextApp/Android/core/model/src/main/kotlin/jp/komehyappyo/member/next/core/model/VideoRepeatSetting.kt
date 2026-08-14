package jp.komehyappyo.member.next.core.model

enum class VideoRepeatMode(val rawValue: String) {
    Full("full"),
    ;

    companion object {
        fun fromValue(value: String?): VideoRepeatMode = when (value) {
            Full.rawValue -> Full
            else -> Full
        }
    }
}

data class VideoRepeatSetting(
    val userId: String,
    val videoId: String,
    val isEnabled: Boolean,
    val mode: VideoRepeatMode = VideoRepeatMode.Full,
    val repeatStartSeconds: Double? = null,
    val repeatEndSeconds: Double? = null,
)
