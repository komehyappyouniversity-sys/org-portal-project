package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.Manual
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

interface ManualRepository {
    suspend fun manuals(
        communityId: String?,
        idToken: String?,
    ): Result<List<Manual>>
}

class FirebaseRestManualRepository(
    projectId: String,
    private val baseUrl: String =
        "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)",
    private val connectionFactory: (URL) -> HttpURLConnection = {
        it.openConnection() as HttpURLConnection
    },
) : ManualRepository {
    override suspend fun manuals(
        communityId: String?,
        idToken: String?,
    ): Result<List<Manual>> = runCatching {
        val normalizedCommunityId = communityId?.trim()?.takeIf(String::isNotEmpty)
        val normalizedToken = idToken?.trim()?.takeIf(String::isNotEmpty)
        val manuals = if (normalizedCommunityId != null && normalizedToken != null) {
            coroutineScope {
                val shared = async { fetch("sharedManuals", null, null, null) }
                val community = async {
                    fetch(
                        "manuals",
                        "organizations/${encodePath(normalizedCommunityId)}",
                        normalizedCommunityId,
                        normalizedToken,
                    )
                }
                shared.await() + community.await()
            }
        } else {
            fetch("sharedManuals", null, null, null)
        }
        manuals.sortedWith(
            compareBy<Manual> { it.sortOrder }
                .thenBy { if (it.communityId == null) 0 else 1 }
                .thenBy { it.id },
        )
    }.onFailure { if (it is CancellationException) throw it }

    private suspend fun fetch(
        collectionId: String,
        parentPath: String?,
        communityId: String?,
        idToken: String?,
    ): List<Manual> = withContext(Dispatchers.IO) {
        val path = parentPath?.let { "documents/$it:runQuery" } ?: "documents:runQuery"
        val connection = connectionFactory(URL("$baseUrl/$path")).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 15_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            idToken?.let { setRequestProperty("Authorization", "Bearer $it") }
        }
        try {
            val body = JSONObject().put(
                "structuredQuery",
                JSONObject()
                    .put(
                        "from",
                        JSONArray().put(JSONObject().put("collectionId", collectionId)),
                    )
                    .put(
                        "where",
                        JSONObject().put(
                            "fieldFilter",
                            JSONObject()
                                .put("field", JSONObject().put("fieldPath", "isPublished"))
                                .put("op", "EQUAL")
                                .put("value", JSONObject().put("booleanValue", true)),
                        ),
                    ),
            )
            connection.outputStream.use {
                it.write(body.toString().toByteArray(Charsets.UTF_8))
            }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IllegalStateException(
                    if (status == 401 || status == 403) {
                        "このコミュニティのマニュアルを閲覧できません。"
                    } else {
                        "マニュアルを読み込めませんでした。"
                    },
                )
            }
            val text = connection.inputStream.bufferedReader().use { it.readText() }
            val rows = if (text.isBlank()) JSONArray() else JSONArray(text)
            buildList {
                for (index in 0 until rows.length()) {
                    rows.optJSONObject(index)
                        ?.optJSONObject("document")
                        ?.let { document ->
                            parseManualDocument(
                                document,
                                communityId,
                            )?.takeIf { it.isPublished }?.let(::add)
                        }
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun encodePath(value: String): String =
        URLEncoder.encode(value, Charsets.UTF_8.name()).replace("+", "%20")
}

internal fun parseManualDocument(document: JSONObject, communityId: String?): Manual? {
    val fields = document.optJSONObject("fields") ?: return null
    val id = document.optString("name").substringAfterLast("/").takeIf(String::isNotEmpty)
        ?: return null
    val title = firestoreString(fields, "title") ?: return null
    val body = firestoreString(fields, "body") ?: return null
    val sortOrder = firestoreInt(fields, "sortOrder") ?: return null
    return Manual(
        id = id,
        communityId = communityId,
        title = title,
        body = body,
        sortOrder = sortOrder,
        imageUrls = firestoreStringArray(fields, "imageUrls"),
        pdfUrl = firestoreString(fields, "pdfUrl")?.trim()?.takeIf(String::isNotEmpty),
        externalUrl = firestoreString(fields, "externalUrl")?.trim()?.takeIf(String::isNotEmpty),
        isPublished = firestoreBoolean(fields, "isPublished") ?: false,
    )
}

private fun firestoreString(fields: JSONObject, key: String): String? =
    fields.optJSONObject(key)?.optString("stringValue")?.takeIf(String::isNotEmpty)

private fun firestoreBoolean(fields: JSONObject, key: String): Boolean? {
    val value = fields.optJSONObject(key) ?: return null
    return if (value.has("booleanValue")) value.optBoolean("booleanValue") else null
}

private fun firestoreInt(fields: JSONObject, key: String): Int? {
    val value = fields.optJSONObject(key) ?: return null
    return when {
        value.has("integerValue") -> value.optString("integerValue").toIntOrNull()
        value.has("doubleValue") -> value.optDouble("doubleValue").toInt()
        else -> null
    }
}

private fun firestoreStringArray(fields: JSONObject, key: String): List<String> {
    val values = fields.optJSONObject(key)
        ?.optJSONObject("arrayValue")
        ?.optJSONArray("values") ?: return emptyList()
    return buildList {
        for (index in 0 until values.length()) {
            values.optJSONObject(index)
                ?.optString("stringValue")
                ?.takeIf(String::isNotEmpty)
                ?.let(::add)
        }
    }
}
