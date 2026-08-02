package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class VideoMemoModelsTest {
    @Test
    fun `personal video trims values and builds category path`() {
        val video = PersonalVideo(
            providerVideoId = "dQw4w9WgXcQ",
            title = " 公式解説動画 ",
            originalUrl = " https://www.youtube.com/watch?v=dQw4w9WgXcQ ",
            note = " 大事なポイント ",
            category = " ",
            secondaryCategory = " 学習 ",
            tertiaryCategory = " YouTube ",
        ).validated()

        assertEquals("公式解説動画", video.title)
        assertEquals("https://www.youtube.com/watch?v=dQw4w9WgXcQ", video.originalUrl)
        assertEquals("未分類", video.category)
        assertEquals("学習", video.secondaryCategory)
        assertEquals("YouTube", video.tertiaryCategory)
        assertEquals("未分類 / 学習 / YouTube", video.categoryPath)
        assertEquals("https://www.youtube.com/watch?v=dQw4w9WgXcQ", video.canonicalUrl)
        assertEquals("https://www.youtube.com/watch?v=dQw4w9WgXcQ", video.timestampedUrl.toString())
    }

    @Test
    fun `personal video keeps category when only primary is set`() {
        val video = PersonalVideo(
            providerVideoId = "dQw4w9WgXcQ",
            title = "公式動画",
            originalUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            category = "業務",
            secondaryCategory = "",
            tertiaryCategory = "",
        ).validated()

        assertEquals("業務", video.categoryPath)
        assertEquals("", video.tertiaryCategory)
    }

    @Test
    fun `video validation rejects invalid data`() {
        assertFailsWith<IllegalArgumentException> {
            PersonalVideo(
                providerVideoId = "dQw4w9WgXcQ",
                title = " ",
                originalUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            ).validated()
        }
        assertFailsWith<IllegalArgumentException> {
            PersonalVideo(
                providerVideoId = "short",
                title = "タイトル",
                originalUrl = "https://www.youtube.com/watch?v=short",
            ).validated()
        }
        assertFailsWith<IllegalArgumentException> {
            VideoMemo(
                id = java.util.UUID.randomUUID(),
                videoId = java.util.UUID.randomUUID(),
                memoText = " "
            ).validated()
        }
    }

    @Test
    fun `video memo keeps seconds non negative`() {
        val memo = VideoMemo(
            videoId = java.util.UUID.randomUUID(),
            memoText = "重要メモ",
            positionSeconds = -12,
        ).validated()
        assertEquals(0, memo.positionSeconds)
    }

    @Test
    fun `video question normalizes fields and validates required values`() {
        val question = VideoQuestion(
            communityId = "community-id",
            videoId = " dQw4w9WgXcQ ",
            videoTitle = " 公式動画 ",
            memberUid = " user-1 ",
            memberName = "  ",
            memberEmail = "user@example.com",
            noteText = " 注目箇所 ",
            questionText = " これは質問です ",
            seconds = -10,
            answerText = " \n ",
            status = VideoQuestionStatus.Unanswered,
        ).validated()

        assertEquals("dQw4w9WgXcQ", question.videoId)
        assertEquals("personal_youtube", question.videoType)
        assertEquals("公式動画", question.videoTitle)
        assertEquals("user-1", question.memberUid)
        assertEquals("会員", question.memberName)
        assertEquals("注目箇所", question.noteText)
        assertEquals("これは質問です", question.questionText)
        assertEquals(0, question.seconds)
        assertEquals("", question.answerText)
        assertEquals(VideoQuestionStatus.Unanswered, question.status)
    }

    @Test
    fun `video question requires communityVideoQuestionText`() {
        assertFailsWith<IllegalArgumentException> {
            VideoQuestion(
                communityId = "community-id",
                videoId = "dQw4w9WgXcQ",
                videoTitle = "公式動画",
                memberUid = "user-1",
                memberName = "会員",
                memberEmail = "user@example.com",
                questionText = " ",
            ).validated()
        }
    }

    @Test
    fun `video question status parses legacy value`() {
        assertEquals(VideoQuestionStatus.Unanswered, VideoQuestionStatus.parse("open"))
        assertEquals(VideoQuestionStatus.Answered, VideoQuestionStatus.parse("answered"))
        assertEquals(VideoQuestionStatus.Unanswered, VideoQuestionStatus.parse(null))
    }
}
