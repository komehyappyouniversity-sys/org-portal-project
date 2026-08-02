package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.VideoQuestion

interface VideoQuestionRepository {
    suspend fun myQuestions(
        communityId: String,
        memberUid: String,
        idToken: String,
    ): Result<List<VideoQuestion>>

    suspend fun openQuestions(
        communityId: String,
        idToken: String,
    ): Result<List<VideoQuestion>>

    suspend fun createQuestion(
        communityId: String,
        videoId: String,
        videoType: String,
        videoTitle: String,
        memberUid: String,
        memberName: String,
        memberEmail: String,
        questionText: String,
        noteText: String,
        seconds: Int,
        idToken: String,
    ): Result<Unit>

    suspend fun answerQuestion(
        communityId: String,
        questionId: String,
        answerText: String,
        idToken: String,
    ): Result<Unit>
}
