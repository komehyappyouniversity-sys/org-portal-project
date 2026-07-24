package jp.komehyappyo.member.next.core.model

import java.time.Instant
import java.util.UUID

data class MeetingMinutes(
    val id: UUID = UUID.randomUUID(),
    val userId: String = "guest",
    val title: String = "",
    val recordingStartAt: Instant = Instant.now(),
    val recordingEndAt: Instant = Instant.now(),
    val recordingDurationSeconds: Int = 0,
    val audioFileLocalPath: String = "",
    val transcriptText: String = "",
    val pdfFileLocalPath: String? = null,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validated(now: Instant = Instant.now()): MeetingMinutes {
        val cleaned = copy(
            title = title.trim(),
            transcriptText = transcriptText.trim(),
            updatedAt = now,
        )
        require(cleaned.title.isNotEmpty()) { "titleRequired" }
        require(cleaned.audioFileLocalPath.isNotEmpty()) { "audioFileRequired" }
        require(cleaned.recordingDurationSeconds >= 0) { "invalidDuration" }
        require(!cleaned.recordingEndAt.isBefore(cleaned.recordingStartAt)) {
            "invalidDateRange"
        }
        return cleaned
    }
}

data class MeetingRecordingDraft(
    val id: UUID = UUID.randomUUID(),
    val userId: String = "guest",
    val startedAt: Instant = Instant.now(),
    val audioFileLocalPath: String,
    val transcriptText: String = "",
    val recordingDurationSeconds: Int = 0,
    val updatedAt: Instant = Instant.now(),
)
