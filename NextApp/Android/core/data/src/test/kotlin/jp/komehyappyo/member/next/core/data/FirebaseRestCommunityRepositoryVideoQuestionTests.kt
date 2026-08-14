package jp.komehyappyo.member.next.core.data

import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class FirebaseRestCommunityRepositoryVideoQuestionTests {
    @Test
    fun adminVideoQuestionsLoadsAllQuestionsSortedByCreatedAt() = runBlocking {
        installMockFirestoreStreamHandler()
        FakeFirestoreRequestHandler.reset()

        FakeFirestoreRequestHandler.responses = mapOf(
            PathMethodKey(
                path = "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions",
                query = "pageSize=1000",
                method = "GET",
            ) to FakeResponse(
                statusCode = 200,
                body = JSONObject().apply {
                    put(
                        "documents",
                        JSONArray().apply {
                            put(
                                JSONObject().apply {
                                    put("name", "projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions/q-new")
                                    put(
                                        "fields",
                                        JSONObject().apply {
                                            put("questionText", JSONObject().put("stringValue", "新しい質問"))
                                            put("videoTitle", JSONObject().put("stringValue", "動画A"))
                                            put("memoText", JSONObject().put("stringValue", "メモ"))
                                            put("answerText", JSONObject().put("stringValue", ""))
                                            put("memberUid", JSONObject().put("stringValue", "member-a"))
                                            put("videoId", JSONObject().put("stringValue", "video-a"))
                                            put("playbackSeconds", JSONObject().put("doubleValue", 10.0))
                                            put("createdAt", JSONObject().put("timestampValue", "2026-08-13T12:00:00Z"))
                                        },
                                    )
                                },
                            )
                            put(
                                JSONObject().apply {
                                    put("name", "projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions/q-old")
                                    put(
                                        "fields",
                                        JSONObject().apply {
                                            put("questionText", JSONObject().put("stringValue", "古い質問"))
                                            put("videoTitle", JSONObject().put("stringValue", "動画B"))
                                            put("answerText", JSONObject().put("stringValue", "既に回答"))
                                            put("memberUid", JSONObject().put("stringValue", "member-b"))
                                            put("videoId", JSONObject().put("stringValue", "video-b"))
                                            put("playbackSeconds", JSONObject().put("doubleValue", 20.0))
                                            put("createdAt", JSONObject().put("timestampValue", "2026-08-12T09:00:00Z"))
                                        },
                                    )
                                },
                            )
                        },
                    )
                }.toString(),
            ),
        )

        val result = repository().adminVideoQuestions("org-1", "id-token").getOrThrow()

        assertEquals(2, result.size)
        assertEquals("q-new", result.first().id)
        assertEquals("q-old", result.last().id)
        assertEquals("動画A", result.first().videoTitle)
        assertEquals("member-a", result.first().memberUid)
        assertEquals("メモ", result.first().memoText)
        assertEquals("", result.first().answerText)
    }

    @Test
    fun answerVideoQuestionSendsTrimmedPatchPayload() = runBlocking {
        installMockFirestoreStreamHandler()
        FakeFirestoreRequestHandler.reset()

        FakeFirestoreRequestHandler.responses = mapOf(
            PathMethodKey(
                path = "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions/q-new",
                method = "PATCH",
            ) to FakeResponse(
                statusCode = 200,
                body = JSONObject().put("writeTime", JSONObject()).toString(),
            ),
        )

        val response = repository().answerVideoQuestion(
            "org-1",
            "q-new",
            "  回答します  ",
            "id-token",
        )

        assertTrue(response.isSuccess)
        assertEquals(1, FakeFirestoreRequestHandler.requests.size)
        val request = FakeFirestoreRequestHandler.requests.first()
        assertEquals("PATCH", request.method)
        assertEquals(
            "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions/q-new",
            request.path,
        )
        val payload = JSONObject(request.body)
        val fields = payload.getJSONObject("fields")
        assertEquals("回答します", fields.getJSONObject("answerText").getString("stringValue"))
        assertTrue(fields.getJSONObject("updatedAt").has("timestampValue"))
    }

    private fun repository(): FirebaseRestCommunityRepository {
        return FirebaseRestCommunityRepository(projectId = "test-project")
    }
}
