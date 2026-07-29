package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.AdminReply
import jp.komehyappyo.member.next.core.model.MemberPost
import jp.komehyappyo.member.next.core.model.PostAttachment
import jp.komehyappyo.member.next.core.model.PublicPost
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.UUID

interface PostRepository {
    suspend fun publicPosts(): Result<List<PublicPost>>
    suspend fun memberPosts(
        communityId: String,
        userId: String,
        idToken: String,
    ): Result<List<MemberPost>>
    suspend fun replies(
        communityId: String,
        postId: String,
        idToken: String,
    ): Result<List<AdminReply>>
    suspend fun createMemberPost(
        communityId: String,
        userId: String,
        memberName: String,
        title: String,
        body: String,
        idToken: String,
    ): Result<Unit>
    suspend fun updateMemberPost(
        communityId: String,
        postId: String,
        title: String,
        body: String,
        idToken: String,
    ): Result<Unit>
    suspend fun deleteMemberPost(
        communityId: String,
        postId: String,
        idToken: String,
    ): Result<Unit>
    suspend fun markReplyRead(
        communityId: String,
        postId: String,
        idToken: String,
    ): Result<Unit>
}

class FirebaseRestPostRepository(
    private val projectId: String,
) : PostRepository {
    override suspend fun publicPosts(): Result<List<PublicPost>> = runCatching {
        collectionGroup("publicPosts", null, publicOnly = true)
            .mapNotNull(::parsePublicPost)
            .filter { it.body.isNotBlank() || it.title.isNotBlank() }
            .sortedByDescending { it.createdAt.orEmpty() }
    }

    override suspend fun memberPosts(
        communityId: String,
        userId: String,
        idToken: String,
    ): Result<List<MemberPost>> = runCatching {
        listDocuments("organizations/$communityId/memberPosts", idToken)
            .mapNotNull { parseMemberPost(communityId, it) }
            .filter { it.authorUserId == userId }
            .sortedByDescending { it.updatedAt ?: it.createdAt.orEmpty() }
    }

    override suspend fun replies(
        communityId: String,
        postId: String,
        idToken: String,
    ): Result<List<AdminReply>> = runCatching {
        listDocuments("organizations/$communityId/memberPosts/$postId/replies", idToken)
            .mapNotNull { parseReply(postId, it) }
            .sortedBy { it.createdAt.orEmpty() }
    }

    override suspend fun createMemberPost(
        communityId: String,
        userId: String,
        memberName: String,
        title: String,
        body: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        val now = Instant.now().toString()
        val fields = JSONObject()
            .put("organizationId", stringValue(communityId))
            .put("memberUid", stringValue(userId))
            .put("memberName", stringValue(memberName))
            .put("title", stringValue(title.trim()))
            .put("body", stringValue(body.trim()))
            .put("imageURLs", arrayValue(emptyList()))
            .put("status", stringValue("submitted"))
            .put("adminReply", stringValue(""))
            .put("memberHasReadReply", booleanValue(true))
            .put("createdAt", timestampValue(now))
            .put("updatedAt", timestampValue(now))
        request(
            "documents/organizations/$communityId/memberPosts/${UUID.randomUUID()}",
            "PATCH",
            idToken,
            JSONObject().put("fields", fields),
        )
        Unit
    }

    override suspend fun updateMemberPost(
        communityId: String,
        postId: String,
        title: String,
        body: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        val fields = JSONObject()
            .put("title", stringValue(title.trim()))
            .put("body", stringValue(body.trim()))
            .put("updatedAt", timestampValue(Instant.now().toString()))
        request(
            "documents/organizations/$communityId/memberPosts/$postId" +
                "?updateMask.fieldPaths=title&updateMask.fieldPaths=body" +
                "&updateMask.fieldPaths=updatedAt",
            "PATCH",
            idToken,
            JSONObject().put("fields", fields),
        )
        Unit
    }

    override suspend fun deleteMemberPost(
        communityId: String,
        postId: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        request(
            "documents/organizations/$communityId/memberPosts/$postId",
            "DELETE",
            idToken,
            null,
        )
        Unit
    }

    override suspend fun markReplyRead(
        communityId: String,
        postId: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        request(
            "documents/organizations/$communityId/memberPosts/$postId" +
                "?updateMask.fieldPaths=memberHasReadReply",
            "PATCH",
            idToken,
            JSONObject().put(
                "fields",
                JSONObject().put("memberHasReadReply", booleanValue(true)),
            ),
        )
        Unit
    }

    private suspend fun listDocuments(path: String, idToken: String): List<JSONObject> {
        val result = request("documents/$path?pageSize=1000", "GET", idToken, null) as JSONObject
        val values = result.optJSONArray("documents") ?: return emptyList()
        return buildList {
            for (index in 0 until values.length()) {
                values.optJSONObject(index)?.let(::add)
            }
        }
    }

    private suspend fun collectionGroup(
        collection: String,
        idToken: String?,
        publicOnly: Boolean = false,
    ): List<JSONObject> {
        val structuredQuery = JSONObject().put(
            "from",
            JSONArray().put(
                JSONObject()
                    .put("collectionId", collection)
                    .put("allDescendants", true),
            ),
        )
        if (publicOnly) {
            structuredQuery.put(
                "where",
                JSONObject().put(
                    "fieldFilter",
                    JSONObject()
                        .put("field", JSONObject().put("fieldPath", "isPublic"))
                        .put("op", "EQUAL")
                        .put("value", booleanValue(true)),
                ),
            )
        }
        val query = JSONObject().put("structuredQuery", structuredQuery)
        val rows = request("documents:runQuery", "POST", idToken, query) as JSONArray
        return buildList {
            for (index in 0 until rows.length()) {
                rows.optJSONObject(index)?.optJSONObject("document")?.let(::add)
            }
        }
    }

    internal fun parseMemberPost(communityId: String, document: JSONObject): MemberPost? {
        val fields = document.optJSONObject("fields") ?: return null
        val id = document.optString("name").substringAfterLast("/")
        return MemberPost(
            id = id,
            communityId = string(fields, "organizationId") ?: communityId,
            authorUserId = string(fields, "memberUid")
                ?: string(fields, "authorUserId") ?: return null,
            authorName = string(fields, "memberName")
                ?: string(fields, "authorName") ?: "会員",
            title = string(fields, "title").orEmpty(),
            body = string(fields, "body").orEmpty(),
            attachments = attachments(fields),
            status = string(fields, "status") ?: "submitted",
            adminReply = string(fields, "adminReply").orEmpty(),
            memberHasReadReply = boolean(fields, "memberHasReadReply") ?: true,
            createdAt = timestamp(fields, "createdAt"),
            updatedAt = timestamp(fields, "updatedAt"),
        )
    }

    internal fun parsePublicPost(document: JSONObject): PublicPost? {
        val fields = document.optJSONObject("fields") ?: return null
        if (boolean(fields, "isPublic") != true) return null
        return PublicPost(
            id = document.optString("name").substringAfterLast("/"),
            authorUserId = string(fields, "authorUserId")
                ?: string(fields, "memberUid").orEmpty(),
            authorName = string(fields, "authorName")
                ?: string(fields, "memberName") ?: "投稿者",
            title = string(fields, "title").orEmpty(),
            body = string(fields, "body").orEmpty(),
            categoryId = string(fields, "categoryId") ?: string(fields, "category"),
            attachments = attachments(fields),
            createdAt = timestamp(fields, "createdAt"),
        )
    }

    private fun parseReply(postId: String, document: JSONObject): AdminReply? {
        val fields = document.optJSONObject("fields") ?: return null
        return AdminReply(
            id = document.optString("name").substringAfterLast("/"),
            postId = postId,
            adminUserId = string(fields, "createdBy")
                ?: string(fields, "adminUserId").orEmpty(),
            adminName = string(fields, "createdByName")
                ?: string(fields, "adminName") ?: "管理者",
            body = string(fields, "body") ?: return null,
            createdAt = timestamp(fields, "createdAt"),
        )
    }

    private fun attachments(fields: JSONObject): List<PostAttachment> {
        val result = mutableListOf<PostAttachment>()
        val values = fields.optJSONObject("attachments")
            ?.optJSONObject("arrayValue")?.optJSONArray("values")
        if (values != null) {
            for (index in 0 until values.length()) {
                val entry = values.optJSONObject(index)
                    ?.optJSONObject("mapValue")?.optJSONObject("fields") ?: continue
                val url = string(entry, "url") ?: continue
                result += PostAttachment(
                    type = string(entry, "type") ?: "url",
                    name = string(entry, "name") ?: "添付ファイル",
                    url = url,
                )
            }
        }
        stringArray(fields, "imageURLs").forEachIndexed { index, url ->
            result += PostAttachment("image", "画像 ${index + 1}", url)
        }
        string(fields, "pdfURL")?.let { result += PostAttachment("pdf", "PDF", it) }
        return result.distinctBy(PostAttachment::url)
    }

    private suspend fun request(
        path: String,
        method: String,
        idToken: String?,
        body: JSONObject?,
    ): Any = withContext(Dispatchers.IO) {
        val connection = (
            URL(
                "https://firestore.googleapis.com/v1/projects/$projectId/" +
                    "databases/(default)/$path",
            ).openConnection() as HttpURLConnection
            ).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 15_000
            idToken?.let { setRequestProperty("Authorization", "Bearer $it") }
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            }
        }
        try {
            body?.let {
                connection.outputStream.use { stream ->
                    stream.write(it.toString().toByteArray(Charsets.UTF_8))
                }
            }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IllegalStateException(
                    if (status == 403) {
                        "投稿を操作する権限がありません。参加承認後に再度お試しください。"
                    } else {
                        "投稿を処理できませんでした。時間をおいて再度お試しください。"
                    },
                )
            }
            if (status == HttpURLConnection.HTTP_NO_CONTENT) return@withContext JSONObject()
            val text = connection.inputStream.bufferedReader().use { it.readText() }
            if (text.isBlank()) JSONObject()
            else if (text.trimStart().startsWith("[")) JSONArray(text) else JSONObject(text)
        } finally {
            connection.disconnect()
        }
    }

    private fun stringValue(value: String) = JSONObject().put("stringValue", value)
    private fun booleanValue(value: Boolean) = JSONObject().put("booleanValue", value)
    private fun timestampValue(value: String) = JSONObject().put("timestampValue", value)
    private fun arrayValue(values: List<String>) = JSONObject().put(
        "arrayValue",
        JSONObject().put(
            "values",
            JSONArray().apply { values.forEach { put(stringValue(it)) } },
        ),
    )
    private fun string(fields: JSONObject, key: String): String? =
        fields.optJSONObject(key)?.optString("stringValue")?.takeIf(String::isNotEmpty)
    private fun boolean(fields: JSONObject, key: String): Boolean? =
        fields.optJSONObject(key)?.takeIf { it.has("booleanValue") }?.optBoolean("booleanValue")
    private fun timestamp(fields: JSONObject, key: String): String? =
        fields.optJSONObject(key)?.optString("timestampValue")?.takeIf(String::isNotEmpty)
    private fun stringArray(fields: JSONObject, key: String): List<String> {
        val values = fields.optJSONObject(key)
            ?.optJSONObject("arrayValue")?.optJSONArray("values") ?: return emptyList()
        return buildList {
            for (index in 0 until values.length()) {
                values.optJSONObject(index)?.optString("stringValue")
                    ?.takeIf(String::isNotEmpty)?.let(::add)
            }
        }
    }
}
