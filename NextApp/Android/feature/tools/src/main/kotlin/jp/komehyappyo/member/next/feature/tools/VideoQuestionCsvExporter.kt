package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.model.DistributedVideo
import jp.komehyappyo.member.next.core.model.VideoQuestion
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

object VideoQuestionCsvExporter {
    private val formatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME

    fun export(
        questions: List<VideoQuestion>,
        video: DistributedVideo,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): String {
        val headerLines = listOf(
            "schema_version=1",
            "video_title,video_url,playback_seconds,question,answer,status,created_at,answered_at,memo",
        )
        val dataLines = questions.map { question ->
            listOf(
                question.videoTitle,
                exportedVideoUrl(video),
                question.playbackSeconds.toString(),
                question.questionText,
                question.answerText,
                if (question.answerText.isBlank()) "unanswered" else "answered",
                question.createdAt?.let { timestamp ->
                    formatter.format(
                        Instant.parse(timestamp).atZone(zoneId),
                    )
                } ?: "",
                "",
                question.memoText,
            ).joinToString(",") { value -> '"' + value.replace("\"", "\"\"") + '"' }
        }
        return (headerLines + dataLines).joinToString("\r\n") + "\r\n"
    }

    private fun exportedVideoUrl(video: DistributedVideo): String {
        return video.vimeoUrl.ifEmpty { video.videoUrl }
    }
}
