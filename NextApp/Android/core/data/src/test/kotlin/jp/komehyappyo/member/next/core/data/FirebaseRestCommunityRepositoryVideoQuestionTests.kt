package jp.komehyappyo.member.next.core.data

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLConnection
import java.net.URLStreamHandler
import java.net.URLStreamHandlerFactory
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
        installMockStreamHandler()
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
        installMockStreamHandler()
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

    private fun installMockStreamHandler() {
        try {
            URL.setURLStreamHandlerFactory(HTTPSchemeRewriter)
        } catch (_: Error) {
            // URLStreamHandlerFactory can be set only once per JVM.
        }
    }
}

private data class PathMethodKey(
    val path: String,
    val method: String,
    val query: String? = null,
)

private data class FakeResponse(
    val statusCode: Int,
    val body: String,
)

private data class RecordedRequest(
    val method: String,
    val path: String,
    val query: String?,
    val body: String,
)

private object FakeFirestoreRequestHandler {
    var responses: Map<PathMethodKey, FakeResponse> = emptyMap()
    val requests: MutableList<RecordedRequest> = mutableListOf()

    fun reset() {
        responses = emptyMap()
        requests.clear()
    }

    fun responseFor(path: String, query: String?, method: String, body: String): FakeResponse {
        requests.add(RecordedRequest(method = method, path = path, query = query, body = body))

        responses[PathMethodKey(path = path, method = method, query = query)]?.let { return it }
        return responses[PathMethodKey(path = path, method = method)] ?: FakeResponse(
            statusCode = 500,
            body = "{}",
        )
    }
}

private object HTTPSchemeRewriter : URLStreamHandlerFactory {
    private val handler = object : URLStreamHandler() {
        override fun openConnection(url: URL): URLConnection =
            FakeFirestoreHttpURLConnection(url)
    }

    override fun createURLStreamHandler(protocol: String): URLStreamHandler? =
        if (protocol == "https") handler else null
}

private class FakeFirestoreHttpURLConnection(
    url: URL,
) : HttpURLConnection(url) {
    private val output = ByteArrayOutputStream()
    private var connected = false
    private var response = FakeResponse(500, "{}")
    private var httpMethod = "GET"

    override fun disconnect() {
        // No-op.
    }

    override fun usingProxy(): Boolean = false

    // The JDK's HttpURLConnection.setRequestMethod() rejects "PATCH" (not in its fixed
    // method whitelist), even though Android's real implementation allows it. Bypass that
    // validation here so PATCH-based repository calls can be exercised in this JVM test.
    override fun setRequestMethod(method: String) {
        httpMethod = method
    }

    override fun getRequestMethod(): String = httpMethod

    override fun connect() {
        if (connected) return
        connected = true
        val body = output.toString(Charsets.UTF_8)
        response = FakeFirestoreRequestHandler.responseFor(url.path, url.query, httpMethod, body)
    }

    override fun getResponseCode(): Int {
        connect()
        return response.statusCode
    }

    override fun getInputStream(): InputStream {
        connect()
        return ByteArrayInputStream(response.body.toByteArray(Charsets.UTF_8))
    }

    override fun getOutputStream(): java.io.OutputStream = output

    override fun getErrorStream(): InputStream {
        return ByteArrayInputStream(response.body.toByteArray(Charsets.UTF_8))
    }

    override fun getHeaderField(name: String?): String? = null
}
