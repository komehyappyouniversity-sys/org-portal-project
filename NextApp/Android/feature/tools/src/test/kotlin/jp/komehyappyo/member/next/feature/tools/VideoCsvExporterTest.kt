package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.model.DistributedVideo
import jp.komehyappyo.member.next.core.model.VideoQuestion
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class VideoCsvExporterTest {
    @Test
    fun exportsMemoCsvWithHeadersAndEscapedQuotes() {
        val video = distributedVideo(
            id = "video-1",
            title = "配信動画",
            vimeoUrl = "https://vimeo.com/abc",
        )
        val memos = listOf(
            VimeoVideoMemo(
                id = "memo-1",
                text = "quote \"and, comma\"",
                playbackSeconds = 12.5,
                createdAtMillis = 1_700_000_000_000,
                updatedAtMillis = 1_700_000_001_000,
            ),
        )
        val csv = VideoMemoCsvExporter.export(
            memos = memos,
            video = video,
            zoneId = ZoneId.of("UTC"),
        )
        val lines = csv.split("\r\n", ignoreCase = false, limit = Int.MAX_VALUE)

        assertEquals("schema_version=1", lines[0])
        assertEquals(
            "video_title,video_url,playback_seconds,memo,category_primary,category_secondary,created_at",
            lines[1],
        )
        assertTrue(lines[2].contains("\"quote \"\"and, comma\"\"\""))
    }

    @Test
    fun exportsQuestionCsvWithStatusAndHeaders() {
        val video = distributedVideo(
            id = "video-2",
            title = "質問動画",
            vimeoUrl = "https://vimeo.com/def",
        )
        val questions = listOf(
            VideoQuestion(
                id = "question-1",
                communityId = "community-1",
                memberUid = "member-1",
                videoId = "video-2",
                videoTitle = "質問動画",
                playbackSeconds = 9.0,
                memoText = "",
                questionText = "質問\"内容\"",
                answerText = "回答",
                createdAt = "2026-07-23T01:00:00Z",
                answeredAt = "2026-07-23T02:00:00Z",
            ),
        )
        val csv = VideoQuestionCsvExporter.export(
            questions = questions,
            video = video,
            zoneId = ZoneId.of("UTC"),
        )
        val lines = csv.split("\r\n", ignoreCase = false, limit = Int.MAX_VALUE)

        assertEquals("schema_version=1", lines[0])
        assertEquals(
            "video_title,video_url,playback_seconds,question,answer,status,created_at,answered_at,memo",
            lines[1],
        )

        val formatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME
        val expectedCreatedAt = formatter.format(java.time.Instant.parse("2026-07-23T01:00:00Z").atZone(ZoneId.of("UTC")))
        val expectedAnsweredAt = formatter.format(java.time.Instant.parse("2026-07-23T02:00:00Z").atZone(ZoneId.of("UTC")))
        assertTrue(lines[2].contains("\"質問\"\"内容\"\""))
        assertTrue(lines[2].contains("\"回答\""))
        assertTrue(lines[2].contains("\"answered\""))
        assertTrue(lines[2].contains("\"$expectedCreatedAt\""))
        assertTrue(lines[2].contains("\"$expectedAnsweredAt\""))
    }

    @Test
    fun exportsMemoCsvWithOnlyHeadersWhenEmpty() {
        val video = distributedVideo(
            id = "video-empty",
            title = "配信動画",
            vimeoUrl = "https://vimeo.com/empty",
        )
        val csv = VideoMemoCsvExporter.export(memos = emptyList(), video = video, zoneId = ZoneId.of("UTC"))
        assertEquals(
            listOf(
                "schema_version=1",
                "video_title,video_url,playback_seconds,memo,category_primary,category_secondary,created_at",
                "",
            ),
            csv.split("\r\n", ignoreCase = false, limit = Int.MAX_VALUE),
        )
    }

    @Test
    fun exportsQuestionCsvWithOnlyHeadersWhenEmpty() {
        val video = distributedVideo(
            id = "video-empty-question",
            title = "質問動画",
            vimeoUrl = "https://vimeo.com/empty-question",
        )
        val csv = VideoQuestionCsvExporter.export(questions = emptyList(), video = video, zoneId = ZoneId.of("UTC"))
        assertEquals(
            listOf(
                "schema_version=1",
                "video_title,video_url,playback_seconds,question,answer,status,created_at,answered_at,memo",
                "",
            ),
            csv.split("\r\n", ignoreCase = false, limit = Int.MAX_VALUE),
        )
    }

    private fun distributedVideo(
        id: String,
        title: String,
        vimeoUrl: String = "",
        videoUrl: String = "",
    ): DistributedVideo = DistributedVideo(
        id = id,
        communityId = "community-1",
        videoTitle = title,
        description = "",
        embedHtml = "",
        videoUrl = videoUrl,
        vimeoUrl = vimeoUrl,
        providerVideoId = "",
        videoType = "distributed_vimeo",
        thumbnailUrl = "",
        isPremium = false,
        isPublished = true,
        isMembersOnly = false,
        sortOrder = 0,
    )
}
