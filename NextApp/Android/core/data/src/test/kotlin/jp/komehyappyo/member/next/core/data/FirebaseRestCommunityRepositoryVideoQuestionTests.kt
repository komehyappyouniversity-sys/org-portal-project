package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.DistributedVideo
import jp.komehyappyo.member.next.core.model.CommunityAdminAccess
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
    fun saveVideoQuestionUsesClientRequestIdAsIdempotentDocumentId() = runBlocking {
        installMockFirestoreStreamHandler()
        FakeFirestoreRequestHandler.reset()
        val path = "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/videoQuestions"
        val request = PathMethodKey(
            path = path,
            query = "documentId=request-123",
            method = "POST",
        )
        val video = DistributedVideo(
            id = "video-1",
            communityId = "org-1",
            videoTitle = "動画",
            description = "",
            embedHtml = "",
            videoUrl = "",
            vimeoUrl = "",
            providerVideoId = "",
            videoType = "distributed_vimeo",
            thumbnailUrl = "",
            isPremium = false,
            createdAt = null,
            updatedAt = null,
            isPublished = true,
            isMembersOnly = false,
            sortOrder = 0,
        )

        listOf(200, 409).forEach { statusCode ->
            FakeFirestoreRequestHandler.responses = mapOf(
                request to FakeResponse(
                    statusCode = statusCode,
                    body = JSONObject().put("writeTime", JSONObject()).toString(),
                ),
            )
            repository().saveVideoQuestion(
                communityId = "org-1",
                memberUid = "member",
                video = video,
                memoText = "メモ",
                questionText = "質問",
                playbackSeconds = 10.0,
                clientRequestId = "request-123",
                idToken = "id-token",
            ).getOrThrow()
        }

        assertEquals(listOf(path, path), FakeFirestoreRequestHandler.requests.map { it.path })
        assertEquals(listOf("POST", "POST"), FakeFirestoreRequestHandler.requests.map { it.method })
        assertEquals(
            listOf("documentId=request-123", "documentId=request-123"),
            FakeFirestoreRequestHandler.requests.map { it.query },
        )
        val fields = JSONObject(FakeFirestoreRequestHandler.requests.first().body).getJSONObject("fields")
        assertEquals("request-123", fields.getJSONObject("clientRequestId").getString("stringValue"))
        assertEquals("synced", fields.getJSONObject("syncStatus").getString("stringValue"))
    }

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
                                            put("answeredAt", JSONObject().put("timestampValue", "2026-08-12T10:00:00Z"))
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
        assertEquals(null, result.first().answeredAt)
        assertEquals("2026-08-12T10:00:00Z", result.last().answeredAt)
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
        assertTrue(fields.getJSONObject("answeredAt").has("timestampValue"))
        assertEquals(
            fields.getJSONObject("updatedAt").getString("timestampValue"),
            fields.getJSONObject("answeredAt").getString("timestampValue"),
        )
    }

    @Test
    fun saveAdministratorPersistsSelectedPermissionSetAndAuditLog() = runBlocking {
        installMockFirestoreStreamHandler()
        FakeFirestoreRequestHandler.reset()
        FakeFirestoreRequestHandler.responses = mapOf(
            PathMethodKey(
                path = "/v1/projects/test-project/databases/(default)/documents:commit",
                method = "POST",
            ) to FakeResponse(
                statusCode = 200,
                body = JSONObject().put("commitTime", "2026-08-15T00:00:00Z").toString(),
            ),
        )

        repository().saveAdministrator(
            communityId = "org-1",
            adminUserId = " manager-1 ",
            role = "manager",
            permissions = setOf(
                CommunityAdminAccess.USAGE_ANALYTICS_READ_PERMISSION,
                CommunityAdminAccess.ANNOUNCEMENT_PUBLISH_PERMISSION,
            ),
            isActive = true,
            actorUserId = "owner-1",
            idToken = "id-token",
        ).getOrThrow()

        val request = FakeFirestoreRequestHandler.requests.single()
        assertEquals("POST", request.method)
        val writes = JSONObject(request.body).getJSONArray("writes")
        val administratorFields = writes.getJSONObject(0)
            .getJSONObject("update")
            .getJSONObject("fields")
        assertEquals(
            "projects/test-project/databases/(default)/documents/organizations/org-1/admins/manager-1",
            writes.getJSONObject(0).getJSONObject("update").getString("name"),
        )
        val permissions = administratorFields.getJSONObject("permissions")
            .getJSONObject("arrayValue")
            .getJSONArray("values")
        assertEquals(2, permissions.length())
        assertEquals("announcementPublish", permissions.getJSONObject(0).getString("stringValue"))
        assertEquals("usageAnalyticsRead", permissions.getJSONObject(1).getString("stringValue"))
        val auditFields = writes.getJSONObject(1).getJSONObject("update").getJSONObject("fields")
        assertEquals("administrator.added", auditFields.getJSONObject("action").getString("stringValue"))
        assertEquals("manager-1", auditFields.getJSONObject("targetUserId").getString("stringValue"))
    }

    private fun repository(): FirebaseRestCommunityRepository {
        return FirebaseRestCommunityRepository(projectId = "test-project")
    }
}
