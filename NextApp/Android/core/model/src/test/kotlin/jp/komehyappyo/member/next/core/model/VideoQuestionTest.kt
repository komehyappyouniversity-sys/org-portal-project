package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class VideoQuestionTest {
    @Test
    fun storesAnsweredAtAndClassifiesTrimmedAnswerText() {
        val answered = question(
            answerText = "  回答  ",
            answeredAt = "2026-08-14T10:00:00Z",
        )
        val unanswered = question(answerText = " \n ", answeredAt = null)

        assertTrue(answered.isAnswered)
        assertFalse(unanswered.isAnswered)
        assertEquals("2026-08-14T10:00:00Z", answered.answeredAt)
        assertEquals(null, unanswered.answeredAt)
    }

    @Test
    fun exposesSameOfflineSyncStatesAsSerializedValues() {
        assertEquals("draft", VideoQuestionSyncStatus.Draft.rawValue())
        assertEquals("sending", VideoQuestionSyncStatus.Sending.rawValue())
        assertEquals("synced", VideoQuestionSyncStatus.Synced.rawValue())
        assertEquals("failed", VideoQuestionSyncStatus.Failed.rawValue())
        assertTrue(VideoQuestionSyncStatus.Draft.requiresSync)
        assertTrue(VideoQuestionSyncStatus.Sending.requiresSync)
        assertTrue(VideoQuestionSyncStatus.Failed.requiresSync)
        assertFalse(VideoQuestionSyncStatus.Synced.requiresSync)
    }

    private fun question(answerText: String, answeredAt: String?): VideoQuestion = VideoQuestion(
        id = "question-1",
        communityId = "org-1",
        memberUid = "member-1",
        videoId = "video-1",
        videoTitle = "動画",
        questionText = "質問",
        answerText = answerText,
        answeredAt = answeredAt,
    )
}
