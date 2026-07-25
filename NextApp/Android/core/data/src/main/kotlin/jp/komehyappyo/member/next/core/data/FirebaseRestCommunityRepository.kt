package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.Community
import jp.komehyappyo.member.next.core.model.CommunityCodeParser
import jp.komehyappyo.member.next.core.model.CommunityMembership
import jp.komehyappyo.member.next.core.model.CommunityMembershipStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

interface CommunityRepository {
    suspend fun findCommunity(code: String, idToken: String): Result<Community>
    suspend fun apply(community: Community, userId: String, idToken: String): Result<Unit>
    suspend fun memberships(
        userId: String,
        idToken: String,
    ): Result<List<Pair<CommunityMembership, Community>>>
}

class CommunityRepositoryException(message: String) : IllegalStateException(message)

class FirebaseRestCommunityRepository(
    private val projectId: String,
) : CommunityRepository {
    override suspend fun findCommunity(code: String, idToken: String): Result<Community> =
        runCatching {
            val normalized = CommunityCodeParser.parse(code)
                ?: throw CommunityRepositoryException("コミュニティコードを確認してください。")
            val direct = runCatching { getCommunity(normalized, idToken) }.getOrNull()
            val community = direct ?: queryCommunity(normalized, idToken)
            when {
                !community.isActive ->
                    throw CommunityRepositoryException("このコミュニティは現在利用できません。")
                !community.joinEnabled ->
                    throw CommunityRepositoryException("このコミュニティは現在、参加申請を受け付けていません。")
                else -> community
            }
        }

    override suspend fun apply(
        community: Community,
        userId: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        val now = Instant.now().toString()
        val fields = JSONObject()
            .put("uid", stringValue(userId))
            .put("userId", stringValue(userId))
            .put("organizationId", stringValue(community.id))
            .put("communityId", stringValue(community.id))
            .put("status", stringValue("pending"))
            .put("role", stringValue("member"))
            .put("createdAt", timestampValue(now))
            .put("updatedAt", timestampValue(now))
        request(
            path = "documents/organizations/${community.id}/members/$userId",
            method = "PATCH",
            idToken = idToken,
            body = JSONObject().put("fields", fields),
        )
        Unit
    }

    override suspend fun memberships(
        userId: String,
        idToken: String,
    ): Result<List<Pair<CommunityMembership, Community>>> = runCatching {
        val body = JSONObject().put(
            "structuredQuery",
            JSONObject()
                .put(
                    "from",
                    JSONArray().put(
                        JSONObject()
                            .put("collectionId", "members")
                            .put("allDescendants", true),
                    ),
                )
                .put(
                    "where",
                    JSONObject().put(
                        "fieldFilter",
                        JSONObject()
                            .put("field", JSONObject().put("fieldPath", "uid"))
                            .put("op", "EQUAL")
                            .put("value", stringValue(userId)),
                    ),
                ),
        )
        val rows = request("documents:runQuery", "POST", idToken, body) as JSONArray
        buildList {
            for (index in 0 until rows.length()) {
                val document = rows.optJSONObject(index)?.optJSONObject("document") ?: continue
                val membership = parseMembership(document, userId) ?: continue
                val community = runCatching {
                    getCommunity(membership.communityId, idToken)
                }.getOrNull() ?: continue
                add(membership to community)
            }
        }.sortedBy { it.second.name }
    }

    private suspend fun queryCommunity(code: String, idToken: String): Community {
        val body = JSONObject().put(
            "structuredQuery",
            JSONObject()
                .put("from", JSONArray().put(JSONObject().put("collectionId", "organizations")))
                .put(
                    "where",
                    JSONObject().put(
                        "fieldFilter",
                        JSONObject()
                            .put(
                                "field",
                                JSONObject().put("fieldPath", "organizationCode"),
                            )
                            .put("op", "EQUAL")
                            .put("value", stringValue(code)),
                    ),
                )
                .put("limit", 1),
        )
        val rows = request("documents:runQuery", "POST", idToken, body) as JSONArray
        val document = rows.optJSONObject(0)?.optJSONObject("document")
            ?: throw CommunityRepositoryException("該当するコミュニティが見つかりませんでした。")
        return parseCommunity(document)
    }

    private suspend fun getCommunity(id: String, idToken: String): Community =
        parseCommunity(
            request("documents/organizations/$id", "GET", idToken, null) as JSONObject,
        )

    private fun parseCommunity(document: JSONObject): Community {
        val fields = document.optJSONObject("fields")
            ?: throw CommunityRepositoryException("コミュニティ情報を読み取れませんでした。")
        val id = document.optString("name").substringAfterLast("/")
        val name = string(fields, "name")
            ?: throw CommunityRepositoryException("コミュニティ情報を読み取れませんでした。")
        return Community(
            id = id,
            code = string(fields, "organizationCode") ?: id,
            name = name,
            description = string(fields, "description").orEmpty(),
            logoUrl = string(fields, "logoImageURL"),
            homepageUrl = string(fields, "homepageURL"),
            isActive = boolean(fields, "isActive") ?: true,
            joinEnabled = boolean(fields, "communityJoinEnabled") ?: false,
        )
    }

    private fun parseMembership(
        document: JSONObject,
        userId: String,
    ): CommunityMembership? {
        val fields = document.optJSONObject("fields") ?: return null
        val parts = document.optString("name").split("/")
        val organizationIndex = parts.indexOfLast { it == "organizations" }
        if (organizationIndex < 0 || organizationIndex + 1 >= parts.size) return null
        val status = when (string(fields, "status")) {
            "pending" -> CommunityMembershipStatus.Pending
            "approved" -> CommunityMembershipStatus.Approved
            "rejected" -> CommunityMembershipStatus.Rejected
            else -> return null
        }
        return CommunityMembership(
            id = parts.lastOrNull() ?: userId,
            communityId = parts[organizationIndex + 1],
            userId = userId,
            status = status,
            role = string(fields, "role") ?: "member",
            joinedAt = timestamp(fields, "joinedAt"),
        )
    }

    private suspend fun request(
        path: String,
        method: String,
        idToken: String,
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
            setRequestProperty("Authorization", "Bearer $idToken")
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
                val message = if (status == 404) {
                    "該当するコミュニティが見つかりませんでした。"
                } else {
                    "通信に失敗しました。時間をおいて再度お試しください。"
                }
                throw CommunityRepositoryException(message)
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
        fields.optJSONObject(key)?.optString("stringValue")?.takeIf { it.isNotEmpty() }
    private fun boolean(fields: JSONObject, key: String): Boolean? =
        fields.optJSONObject(key)?.takeIf { it.has("booleanValue") }?.optBoolean("booleanValue")
    private fun timestamp(fields: JSONObject, key: String): String? =
        fields.optJSONObject(key)?.optString("timestampValue")?.takeIf { it.isNotEmpty() }
}
