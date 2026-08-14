package jp.komehyappyo.member.next.core.data

import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class FirebaseRestPostRepositoryAdminReplyTests {
    @Test
    fun saveAdminReplySendsTrimmedPayloadAndResetsUnreadState() = runBlocking {
        installMockFirestoreStreamHandler()
        FakeFirestoreRequestHandler.reset()
        FakeFirestoreRequestHandler.responses = mapOf(
            PathMethodKey(
                path = "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/memberPosts/post-1/replies/adminReply",
                method = "PATCH",
            ) to FakeResponse(
                statusCode = 200,
                body = JSONObject().put("writeTime", JSONObject()).toString(),
            ),
            PathMethodKey(
                path = "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/memberPosts/post-1",
                query = "updateMask.fieldPaths=adminReply&updateMask.fieldPaths=memberHasReadReply&updateMask.fieldPaths=updatedAt",
                method = "PATCH",
            ) to FakeResponse(
                statusCode = 200,
                body = JSONObject().put("writeTime", JSONObject()).toString(),
            ),
        )

        val result = repository().saveAdminReply(
            communityId = "org-1",
            postId = "post-1",
            adminUserId = "admin-1",
            adminName = "運営者名",
            body = "  ありがとうございました  ",
            idToken = "id-token",
        )

        assertTrue(result.isSuccess)
        assertEquals(2, FakeFirestoreRequestHandler.requests.size)

        val replyRequest = FakeFirestoreRequestHandler.requests[0]
        assertEquals("PATCH", replyRequest.method)
        assertEquals(
            "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/memberPosts/post-1/replies/adminReply",
            replyRequest.path,
        )
        val replyPayload = JSONObject(replyRequest.body)
        val replyFields = replyPayload.getJSONObject("fields")
        assertEquals("admin-1", replyFields.getJSONObject("createdBy").getString("stringValue"))
        assertEquals("運営者名", replyFields.getJSONObject("createdByName").getString("stringValue"))
        assertEquals("ありがとうございました", replyFields.getJSONObject("body").getString("stringValue"))
        assertTrue(replyFields.getJSONObject("createdAt").has("timestampValue"))

        val syncRequest = FakeFirestoreRequestHandler.requests[1]
        assertEquals(
            "updateMask.fieldPaths=adminReply&updateMask.fieldPaths=memberHasReadReply&updateMask.fieldPaths=updatedAt",
            syncRequest.query,
        )
        val syncPayload = JSONObject(syncRequest.body)
        val syncFields = syncPayload.getJSONObject("fields")
        assertEquals(
            "ありがとうございました",
            syncFields.getJSONObject("adminReply").getString("stringValue"),
        )
        assertEquals(false, syncFields.getJSONObject("memberHasReadReply").getBoolean("booleanValue"))
        assertTrue(syncFields.getJSONObject("updatedAt").has("timestampValue"))
    }

    @Test
    fun saveAdminReplyFallsBackDefaultAdminName() = runBlocking {
        installMockFirestoreStreamHandler()
        FakeFirestoreRequestHandler.reset()
        FakeFirestoreRequestHandler.responses = mapOf(
            PathMethodKey(
                path = "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/memberPosts/post-1/replies/adminReply",
                method = "PATCH",
            ) to FakeResponse(
                statusCode = 200,
                body = JSONObject().put("writeTime", JSONObject()).toString(),
            ),
            PathMethodKey(
                path = "/v1/projects/test-project/databases/(default)/documents/organizations/org-1/memberPosts/post-1",
                query = "updateMask.fieldPaths=adminReply&updateMask.fieldPaths=memberHasReadReply&updateMask.fieldPaths=updatedAt",
                method = "PATCH",
            ) to FakeResponse(
                statusCode = 200,
                body = JSONObject().put("writeTime", JSONObject()).toString(),
            ),
        )

        val result = repository().saveAdminReply(
            communityId = "org-1",
            postId = "post-1",
            adminUserId = "admin-1",
            adminName = null,
            body = "返信",
            idToken = "id-token",
        )

        assertTrue(result.isSuccess)
        val payload = JSONObject(FakeFirestoreRequestHandler.requests[0].body)
        val fields = payload.getJSONObject("fields")
        assertEquals("管理者", fields.getJSONObject("createdByName").getString("stringValue"))
    }

    private fun repository(): FirebaseRestPostRepository {
        return FirebaseRestPostRepository(projectId = "test-project")
    }
}
