package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.model.DistributedVideo
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

object VideoMemoCsvExporter {
    private val formatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME

    fun export(memos: List<VimeoVideoMemo>, video: DistributedVideo, zoneId: ZoneId = ZoneId.systemDefault()): String {
        val headerLines = listOf(
            "schema_version=1",
            "video_title,video_url,playback_seconds,memo,category_primary,category_secondary,created_at",
        )
        val dataLines = memos.map { memo ->
            listOf(
                video.videoTitle,
                exportedVideoUrl(video),
                memo.playbackSeconds.toString(),
                memo.text,
                video.primaryCategoryId,
                video.secondaryCategoryId,
                if (memo.createdAtMillis <= 0L) {
                    ""
                } else {
                    formatter.format(Instant.ofEpochMilli(memo.createdAtMillis).atZone(zoneId))
                },
            ).joinToString(",") { value -> '"' + value.replace("\"", "\"\"") + '"' }
        }
        return (headerLines + dataLines).joinToString("\r\n") + "\r\n"
    }

    private fun exportedVideoUrl(video: DistributedVideo): String {
        return video.vimeoUrl.ifEmpty { video.videoUrl }
    }
}
