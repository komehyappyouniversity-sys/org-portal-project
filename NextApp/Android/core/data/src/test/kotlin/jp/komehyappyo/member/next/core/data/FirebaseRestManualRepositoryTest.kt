package jp.komehyappyo.member.next.core.data

import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

@RunWith(RobolectricTestRunner::class)
class FirebaseRestManualRepositoryTest {
    @Test
    fun guestLoadsOnlyPublishedSharedManuals() = runBlocking {
        val connections = mutableListOf<FakeManualConnection>()
        val repository = repository(
            shared = rows(
                document("published", "公開", 2, true),
                document("draft", "下書き", 1, false),
            ),
            community = rows(),
            connections = connections,
        )

        val manuals = repository.manuals(null, null).getOrThrow()

        assertEquals(listOf("published"), manuals.map { it.id })
        assertNull(manuals.first().communityId)
        assertEquals(1, connections.size)
        assertNull(connections.first().requestHeaders["Authorization"])
        assertPublishedQuery(connections.first().requestBody())
    }

    @Test
    fun memberMergesCollectionsInStableSortOrder() = runBlocking {
        val connections = mutableListOf<FakeManualConnection>()
        val repository = repository(
            shared = rows(
                document("z-shared", "共通Z", 10, true),
                document("a-shared", "共通A", 10, true),
            ),
            community = rows(
                document("community", "専用", 5, true),
                document("same", "専用同順", 10, true),
            ),
            connections = connections,
        )

        val manuals = repository.manuals("org-1", "member-token").getOrThrow()

        assertEquals(
            listOf("community", "a-shared", "z-shared", "same"),
            manuals.map { it.id },
        )
        assertEquals(listOf("org-1", null, null, "org-1"), manuals.map { it.communityId })
        assertEquals(2, connections.size)
        val communityConnection = connections.first {
            it.requestUrl.path.contains("organizations/org-1")
        }
        assertEquals("Bearer member-token", communityConnection.requestHeaders["Authorization"])
        val sharedConnection = connections.first {
            !it.requestUrl.path.contains("organizations/org-1")
        }
        assertNull(sharedConnection.requestHeaders["Authorization"])
        connections.forEach { assertPublishedQuery(it.requestBody()) }
    }

    @Test
    fun parserMapsAllDomainFields() {
        val parsed = parseManualDocument(
            document(
                id = "guide",
                title = "ガイド",
                sortOrder = 3,
                isPublished = true,
                body = "本文",
                imageUrls = listOf("https://example.com/1.jpg", "https://example.com/2.jpg"),
                pdfUrl = "https://example.com/guide.pdf",
                externalUrl = "https://example.com/help",
            ),
            communityId = "org-1",
        )!!

        assertEquals("guide", parsed.id)
        assertEquals("org-1", parsed.communityId)
        assertEquals("本文", parsed.body)
        assertEquals(3, parsed.sortOrder)
        assertEquals(2, parsed.imageUrls.size)
        assertEquals("https://example.com/guide.pdf", parsed.pdfUrl)
        assertEquals("https://example.com/help", parsed.externalUrl)
        assertTrue(parsed.isPublished)
    }

    private fun repository(
        shared: String,
        community: String,
        connections: MutableList<FakeManualConnection>,
    ) = FirebaseRestManualRepository(
        projectId = "test-project",
        connectionFactory = { url ->
            FakeManualConnection(
                url,
                if (url.path.contains("organizations/org-1")) community else shared,
            ).also { synchronized(connections) { connections += it } }
        },
    )

    private fun assertPublishedQuery(body: String) {
        val filter = JSONObject(body)
            .getJSONObject("structuredQuery")
            .getJSONObject("where")
            .getJSONObject("fieldFilter")
        assertEquals("isPublished", filter.getJSONObject("field").getString("fieldPath"))
        assertEquals("EQUAL", filter.getString("op"))
        assertTrue(filter.getJSONObject("value").getBoolean("booleanValue"))
    }
}

private class FakeManualConnection(
    val requestUrl: URL,
    private val responseBody: String,
) : HttpURLConnection(requestUrl) {
    private val output = ByteArrayOutputStream()
    val requestHeaders = mutableMapOf<String, String>()

    override fun connect() = Unit
    override fun disconnect() = Unit
    override fun usingProxy(): Boolean = false
    override fun getResponseCode(): Int = 200
    override fun getInputStream(): InputStream =
        ByteArrayInputStream(responseBody.toByteArray(Charsets.UTF_8))
    override fun getOutputStream() = output
    override fun setRequestProperty(key: String, value: String) {
        requestHeaders[key] = value
    }

    fun requestBody(): String = output.toString(Charsets.UTF_8.name())
}

private fun rows(vararg documents: JSONObject): String =
    JSONArray().apply {
        documents.forEach { put(JSONObject().put("document", it)) }
    }.toString()

private fun document(
    id: String,
    title: String,
    sortOrder: Int,
    isPublished: Boolean,
    body: String = "本文",
    imageUrls: List<String> = emptyList(),
    pdfUrl: String? = null,
    externalUrl: String? = null,
): JSONObject {
    val fields = JSONObject()
        .put("title", JSONObject().put("stringValue", title))
        .put("body", JSONObject().put("stringValue", body))
        .put("sortOrder", JSONObject().put("integerValue", sortOrder.toString()))
        .put(
            "imageUrls",
            JSONObject().put(
                "arrayValue",
                JSONObject().put(
                    "values",
                    JSONArray().apply {
                        imageUrls.forEach { put(JSONObject().put("stringValue", it)) }
                    },
                ),
            ),
        )
        .put("isPublished", JSONObject().put("booleanValue", isPublished))
    pdfUrl?.let { fields.put("pdfUrl", JSONObject().put("stringValue", it)) }
    externalUrl?.let { fields.put("externalUrl", JSONObject().put("stringValue", it)) }
    return JSONObject()
        .put("name", "projects/test-project/databases/(default)/documents/manuals/$id")
        .put("fields", fields)
}
