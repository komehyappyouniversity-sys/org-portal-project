package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.Announcement
import jp.komehyappyo.member.next.core.model.AnnouncementAttachment
import jp.komehyappyo.member.next.core.model.AnnouncementPublishScope
import jp.komehyappyo.member.next.core.model.CommunityMembership
import jp.komehyappyo.member.next.core.model.CommunityMembershipStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

interface AnnouncementRepository {
    suspend fun announcements(
        communityId: String?,
        membership: CommunityMembership?,
        userId: String?,
        idToken: String?,
    ): Result<List<Announcement>>

    suspend fun readAnnouncementIds(
        userId: String,
        idToken: String,
    ): Result<Set<String>>

    suspend fun markRead(
        userId: String,
        announcementId: String,
        idToken: String,
    ): Result<Unit>
}

class FirebaseRestAnnouncementRepository(
    private val projectId: String,
) : AnnouncementRepository {
    override suspend fun announcements(
        communityId: String?,
        membership: CommunityMembership?,
        userId: String?,
        idToken: String?,
    ): Result<List<Announcement>> = runCatching {
        val approved = membership?.status == CommunityMembershipStatus.Approved
        val documents = if (communityId != null && approved && idToken != null) {
            listDocuments(communityId, "announcements", idToken) +
                listDocuments(communityId, "messages", idToken)
        } else {
            publicDocuments("announcements", "publishScope", "public") +
                publicDocuments("messages", "messageType", "publicAnnouncement") +
                publicDocuments("messages", "visibility", "public")
        }
        documents
            .mapNotNull(::parseAnnouncement)
            .distinctBy(Announcement::id)
            .filter {
                it.isVisibleTo(
                    userId = userId,
                    categoryIds = membership?.categoryIds.orEmpty(),
                    isApprovedMember = approved,
                )
            }
            .sortedByDescending { it.createdAt.orEmpty() }
    }

    override suspend fun readAnnouncementIds(
        userId: String,
        idToken: String,
    ): Result<Set<String>> = runCatching {
        val response = request(
            "documents/memberPrivate/$userId/announcementReadStates?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildSet {
            for (index in 0 until documents.length()) {
                val fields = documents.optJSONObject(index)?.optJSONObject("fields") ?: continue
                string(fields, "announcementId")?.let(::add)
            }
        }
    }

    override suspend fun markRead(
        userId: String,
        announcementId: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        val documentId = announcementId.replace(Regex("[^A-Za-z0-9_-]"), "_")
        val fields = JSONObject()
            .put("userId", stringValue(userId))
            .put("announcementId", stringValue(announcementId))
            .put("readAt", timestampValue(Instant.now().toString()))
        request(
            "documents/memberPrivate/$userId/announcementReadStates/$documentId",
            "PATCH",
            idToken,
            JSONObject().put("fields", fields),
        )
        Unit
    }

    private suspend fun listDocuments(
        communityId: String,
        collection: String,
        idToken: String,
    ): List<Pair<String, JSONObject>> {
        val result = request(
            "documents/organizations/$communityId/$collection?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        return documents(result, collection)
    }

    private suspend fun publicDocuments(
        collection: String,
        field: String,
        value: String,
    ): List<Pair<String, JSONObject>> {
        val body = JSONObject().put(
            "structuredQuery",
            JSONObject()
                .put(
                    "from",
                    JSONArray().put(
                        JSONObject()
                            .put("collectionId", collection)
                            .put("allDescendants", true),
                    ),
                )
                .put(
                    "where",
                    JSONObject().put(
                        "fieldFilter",
                        JSONObject()
                            .put("field", JSONObject().put("fieldPath", field))
                            .put("op", "EQUAL")
                            .put("value", stringValue(value)),
                    ),
                ),
        )
        val rows = request("documents:runQuery", "POST", null, body) as JSONArray
        return buildList {
            for (index in 0 until rows.length()) {
                rows.optJSONObject(index)?.optJSONObject("document")?.let {
                    add(collection to it)
                }
            }
        }
    }

    private fun documents(
        response: JSONObject,
        source: String,
    ): List<Pair<String, JSONObject>> {
        val values = response.optJSONArray("documents") ?: return emptyList()
        return buildList {
            for (index in 0 until values.length()) {
                values.optJSONObject(index)?.let { add(source to it) }
            }
        }
    }

    internal fun parseAnnouncement(sourceDocument: Pair<String, JSONObject>): Announcement? {
        val (source, document) = sourceDocument
        val fields = document.optJSONObject("fields") ?: return null
        val path = document.optString("name").split("/")
        val organizationsIndex = path.indexOfLast { it == "organizations" }
        if (organizationsIndex < 0 || organizationsIndex + 1 >= path.size) return null
        val rawId = path.lastOrNull().orEmpty()
        val scope = when {
            source == "announcements" -> when (string(fields, "publishScope")) {
                "public" -> AnnouncementPublishScope.Public
                "category" -> AnnouncementPublishScope.Category
                "individual" -> AnnouncementPublishScope.Individual
                else -> AnnouncementPublishScope.MemberAll
            }
            string(fields, "messageType") == "publicAnnouncement" ||
                string(fields, "visibility") == "public" ||
                string(fields, "deliveryType") == "公開お知らせ" ->
                AnnouncementPublishScope.Public
            stringArray(fields, "targetMemberUids").isNotEmpty() ||
                stringArray(fields, "toUids").isNotEmpty() ->
                AnnouncementPublishScope.Individual
            stringArray(fields, "categoryTargets").isNotEmpty() ->
                AnnouncementPublishScope.Category
            else -> AnnouncementPublishScope.MemberAll
        }
        return Announcement(
            id = "${path[organizationsIndex + 1]}:$source:$rawId",
            communityId = path[organizationsIndex + 1],
            title = string(fields, "title") ?: return null,
            body = string(fields, "body").orEmpty(),
            publishScope = scope,
            targetCategoryIds = (
                stringArray(fields, "targetCategoryIds") +
                    stringArray(fields, "categoryTargets") +
                    listOfNotNull(string(fields, "targetCategoryId"))
                ).toSet(),
            targetUserIds = (
                stringArray(fields, "targetUserIds") +
                    stringArray(fields, "targetMemberUids") +
                    stringArray(fields, "toUids")
                ).toSet(),
            attachments = attachments(fields),
            zoomUrl = string(fields, "zoomUrl") ?: string(fields, "zoomURL"),
            videoUrl = string(fields, "videoUrl") ?: string(fields, "videoURL"),
            createdAt = timestamp(fields, "createdAt"),
        )
    }

    private fun attachments(fields: JSONObject): List<AnnouncementAttachment> {
        val values = fields.optJSONObject("attachments")
            ?.optJSONObject("arrayValue")
            ?.optJSONArray("values") ?: return emptyList()
        return buildList {
            for (index in 0 until values.length()) {
                val mapFields = values.optJSONObject(index)
                    ?.optJSONObject("mapValue")
                    ?.optJSONObject("fields") ?: continue
                val url = string(mapFields, "url") ?: continue
                add(
                    AnnouncementAttachment(
                        type = string(mapFields, "type") ?: "url",
                        name = string(mapFields, "name") ?: "添付ファイル",
                        url = url,
                    ),
                )
            }
        }
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
            if (body != null) {
                connection.outputStream.use {
                    it.write(body.toString().toByteArray(Charsets.UTF_8))
                }
            }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IllegalStateException("お知らせを取得できませんでした。時間をおいて再度お試しください。")
            }
            val text = connection.inputStream.bufferedReader().use { it.readText() }
            if (text.trimStart().startsWith("[")) JSONArray(text) else JSONObject(text)
        } finally {
            connection.disconnect()
        }
    }

    private fun stringValue(value: String) = JSONObject().put("stringValue", value)
    private fun timestampValue(value: String) = JSONObject().put("timestampValue", value)
    private fun string(fields: JSONObject, key: String): String? =
        fields.optJSONObject(key)?.optString("stringValue")?.takeIf(String::isNotEmpty)
    private fun timestamp(fields: JSONObject, key: String): String? =
        fields.optJSONObject(key)?.optString("timestampValue")?.takeIf(String::isNotEmpty)
    private fun stringArray(fields: JSONObject, key: String): List<String> {
        val values = fields.optJSONObject(key)
            ?.optJSONObject("arrayValue")
            ?.optJSONArray("values") ?: return emptyList()
        return buildList {
            for (index in 0 until values.length()) {
                values.optJSONObject(index)?.optString("stringValue")
                    ?.takeIf(String::isNotEmpty)?.let(::add)
            }
        }
    }
}
