package jp.komehyappyo.member.next.core.data

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLConnection
import java.net.URLStreamHandler
import java.net.URLStreamHandlerFactory

// Shared Firestore REST mocking harness for core:data unit tests. URL.setURLStreamHandlerFactory
// can only be set once per JVM, so every test class that needs to fake HttpURLConnection-based
// Firestore calls must share this single handler/registry rather than defining its own copy.
internal data class PathMethodKey(
    val path: String,
    val method: String,
    val query: String? = null,
)

internal data class FakeResponse(
    val statusCode: Int,
    val body: String,
)

internal data class RecordedRequest(
    val method: String,
    val path: String,
    val query: String?,
    val body: String,
)

internal object FakeFirestoreRequestHandler {
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

internal object HTTPSchemeRewriter : URLStreamHandlerFactory {
    private val handler = object : URLStreamHandler() {
        override fun openConnection(url: URL): URLConnection = FakeFirestoreHttpURLConnection(url)
    }

    override fun createURLStreamHandler(protocol: String): URLStreamHandler? =
        if (protocol == "https") handler else null
}

internal class FakeFirestoreHttpURLConnection(
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

    // The JDK's HttpURLConnection#setRequestMethod rejects "PATCH". Android allows it.
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

internal fun installMockFirestoreStreamHandler() {
    try {
        URL.setURLStreamHandlerFactory(HTTPSchemeRewriter)
    } catch (_: Error) {
        // URLStreamHandlerFactory can only be set once per JVM.
    }
}
