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
    ): String = exportRows(
        questions = questions,
        videosById = mapOf(video.id to video),
        fallbackVideo = video,
        zoneId = zoneId,
    )

    fun export(
        questions: List<VideoQuestion>,
        videos: List<DistributedVideo>,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): String = exportRows(
        questions = questions,
        videosById = videos.associateBy { it.id },
        fallbackVideo = null,
        zoneId = zoneId,
    )

    private fun exportRows(
        questions: List<VideoQuestion>,
        videosById: Map<String, DistributedVideo>,
        fallbackVideo: DistributedVideo?,
        zoneId: ZoneId,
    ): String {
        val headerLines = listOf(
            "schema_version=1",
            "video_title,video_url,playback_seconds,question,answer,status,created_at,answered_at,memo",
        )
        val dataLines = questions.map { question ->
            val video = videosById[question.videoId] ?: fallbackVideo
            listOf(
                question.videoTitle.ifEmpty { video?.videoTitle.orEmpty() },
                video?.let(::exportedVideoUrl).orEmpty(),
                question.playbackSeconds.toString(),
                question.questionText,
                question.answerText,
                if (question.isAnswered) "answered" else "unanswered",
                question.createdAt?.let { timestamp ->
                    formatter.format(
                        Instant.parse(timestamp).atZone(zoneId),
                    )
                } ?: "",
                question.answeredAt?.let { timestamp ->
                    formatter.format(
                        Instant.parse(timestamp).atZone(zoneId),
                    )
                } ?: "",
                question.memoText,
            ).joinToString(",") { value -> '"' + value.replace("\"", "\"\"") + '"' }
        }
        return (headerLines + dataLines).joinToString("\r\n") + "\r\n"
    }

    private fun exportedVideoUrl(video: DistributedVideo): String {
        return video.vimeoUrl.ifEmpty { video.videoUrl }
    }
}
