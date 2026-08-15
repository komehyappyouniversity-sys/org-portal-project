package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.Community
import jp.komehyappyo.member.next.core.model.CommunityAdminAccess
import jp.komehyappyo.member.next.core.model.CommunityAdmin
import jp.komehyappyo.member.next.core.model.CommunityAuditLog
import jp.komehyappyo.member.next.core.model.BookingEvent
import jp.komehyappyo.member.next.core.model.BookingReservation
import jp.komehyappyo.member.next.core.model.BookingSlot
import jp.komehyappyo.member.next.core.model.DistributedVideo
import jp.komehyappyo.member.next.core.model.RadioProgram
import jp.komehyappyo.member.next.core.model.RadioPlaybackRecord
import jp.komehyappyo.member.next.core.model.VideoQuestion
import jp.komehyappyo.member.next.core.model.VideoQuestionSyncStatus
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
import java.util.UUID

interface CommunityRepository {
    suspend fun publicCommunities(query: String): Result<List<Community>>
    suspend fun findCommunity(code: String, idToken: String): Result<Community>
    suspend fun apply(community: Community, userId: String, idToken: String): Result<Unit>
    suspend fun memberships(
        userId: String,
        idToken: String,
    ): Result<List<Pair<CommunityMembership, Community>>>
    suspend fun adminAccess(
        communityId: String,
        userId: String,
        idToken: String,
    ): Result<CommunityAdminAccess?>
    suspend fun pendingApplications(
        communityId: String,
        idToken: String,
    ): Result<List<CommunityMembership>>
    suspend fun reviewApplication(
        communityId: String,
        applicantUserId: String,
        reviewerUserId: String,
        status: CommunityMembershipStatus,
        auditAction: String? = null,
        idToken: String,
    ): Result<Unit>
    suspend fun administrators(
        communityId: String,
        idToken: String,
    ): Result<List<CommunityAdmin>>
    suspend fun saveAdministrator(
        communityId: String,
        adminUserId: String,
        role: String,
        permissions: Set<String>,
        isActive: Boolean,
        actorUserId: String,
        idToken: String,
    ): Result<Unit>
    suspend fun communityMembers(
        communityId: String,
        idToken: String,
    ): Result<List<CommunityMembership>>
    suspend fun auditLogs(
        communityId: String,
        idToken: String,
    ): Result<List<CommunityAuditLog>>
    suspend fun bookingEvents(
        communityId: String,
        idToken: String,
    ): Result<List<BookingEvent>>
    suspend fun adminBookingEvents(
        communityId: String,
        idToken: String,
    ): Result<List<BookingEvent>>
    suspend fun saveBookingEvent(
        communityId: String,
        eventId: String,
        title: String,
        description: String,
        eventDate: String?,
        feeAmount: Int,
        paymentRequired: Boolean,
        zoomUrl: String,
        isPublished: Boolean,
        idToken: String,
    ): Result<Unit>
    suspend fun bookingSlots(
        communityId: String,
        eventId: String,
        idToken: String,
    ): Result<List<BookingSlot>>
    suspend fun bookingReservations(
        communityId: String,
        eventId: String,
        idToken: String,
    ): Result<List<BookingReservation>>
    suspend fun saveBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        startAt: String?,
        endAt: String?,
        capacity: Int,
        isOpen: Boolean,
        idToken: String,
    ): Result<Unit>
    suspend fun bookedSlotIds(
        communityId: String,
        eventId: String,
        userId: String,
        idToken: String,
    ): Result<Set<String>>
    suspend fun myBookingReservations(
        communityId: String,
        userId: String,
        idToken: String,
    ): Result<List<BookingReservation>>
    suspend fun reserveBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String,
    ): Result<Unit>
    suspend fun cancelBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String,
    ): Result<Unit>
    suspend fun communityVideos(
        communityId: String,
        idToken: String,
    ): Result<List<DistributedVideo>>
    suspend fun radioPrograms(
        communityId: String,
        idToken: String,
    ): Result<List<RadioProgram>>
    suspend fun radioPlaybackRecords(
        userId: String,
        idToken: String,
    ): Result<List<RadioPlaybackRecord>>
    suspend fun saveRadioPlaybackRecord(
        record: RadioPlaybackRecord,
        idToken: String,
    ): Result<Unit>
    suspend fun videoMemos(userId: String, idToken: String): Result<Map<String, String>>
    suspend fun saveVideoMemo(
        userId: String,
        communityId: String,
        videoId: String,
        memo: String,
        idToken: String,
    ): Result<Unit>
    suspend fun videoQuestions(
        communityId: String,
        memberUid: String,
        idToken: String,
    ): Result<List<VideoQuestion>>
    suspend fun adminVideoQuestions(
        communityId: String,
        idToken: String,
    ): Result<List<VideoQuestion>>
    suspend fun saveVideoQuestion(
        communityId: String,
        memberUid: String,
        video: DistributedVideo,
        memoText: String,
        questionText: String,
        playbackSeconds: Double,
        clientRequestId: String,
        idToken: String,
    ): Result<Unit>
    suspend fun answerVideoQuestion(
        communityId: String,
        questionId: String,
        answerText: String,
        idToken: String,
    ): Result<Unit>
    suspend fun adminCommunityVideos(
        communityId: String,
        idToken: String,
    ): Result<List<DistributedVideo>>
    suspend fun vimeoLibraryVideos(
        communityId: String,
        idToken: String,
        folderId: String? = null,
    ): Result<List<DistributedVideo>>
    suspend fun vimeoFolders(
        communityId: String,
        idToken: String,
    ): Result<List<VimeoFolder>>
    suspend fun vimeoConfiguration(
        communityId: String,
        idToken: String,
    ): Result<VimeoConfiguration>
    suspend fun saveVimeoConfiguration(
        communityId: String,
        accessToken: String,
        userId: String,
        query: String,
        idToken: String,
    ): Result<Unit>
    suspend fun saveCommunityVideo(
        communityId: String,
        videoId: String,
        title: String,
        description: String,
        vimeoVideoId: String,
        vimeoUrl: String,
        thumbnailUrl: String,
        isPublished: Boolean,
        idToken: String,
    ): Result<Unit>
}

data class VimeoConfiguration(
    val hasAccessToken: Boolean = false,
    val userId: String = "",
    val query: String = "",
)

data class VimeoFolder(
    val id: String,
    val name: String,
)

class CommunityRepositoryException(message: String) : IllegalStateException(message)
private class CommunityHttpException(
    val status: Int,
    message: String,
) : IllegalStateException(message)

class FirebaseRestCommunityRepository(
    private val projectId: String,
) : CommunityRepository {
    override suspend fun publicCommunities(query: String): Result<List<Community>> =
        runCatching {
            val body = JSONObject().put(
                "structuredQuery",
                JSONObject()
                    .put(
                        "from",
                        JSONArray().put(JSONObject().put("collectionId", "organizations")),
                    )
                    .put(
                        "where",
                        JSONObject().put(
                            "fieldFilter",
                            JSONObject()
                                .put(
                                    "field",
                                    JSONObject().put(
                                        "fieldPath",
                                        "communitySurfingVisible",
                                    ),
                                )
                                .put("op", "EQUAL")
                                .put("value", booleanValue(true)),
                        ),
                    ),
            )
            val rows = request("documents:runQuery", "POST", null, body) as JSONArray
            buildList {
                for (index in 0 until rows.length()) {
                    val document = rows.optJSONObject(index)
                        ?.optJSONObject("document") ?: continue
                    runCatching { parseCommunity(document) }.getOrNull()
                        ?.takeIf {
                            it.isActive &&
                                it.surfingVisible &&
                                it.matchesPublicSearch(query)
                        }
                        ?.let(::add)
                }
            }.sortedBy { it.name }
        }

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
        val profile = runCatching { memberProfile(userId, idToken) }.getOrNull()
        val fields = JSONObject()
            .put("uid", stringValue(userId))
            .put("userId", stringValue(userId))
            .put("organizationId", stringValue(community.id))
            .put("communityId", stringValue(community.id))
            .put("status", stringValue("pending"))
            .put("role", stringValue("member"))
            .put("createdAt", timestampValue(now))
            .put("updatedAt", timestampValue(now))
        profile?.let {
            string(it, "name")?.let { value -> fields.put("applicantName", stringValue(value)) }
            string(it, "furigana")?.let { value -> fields.put("applicantFurigana", stringValue(value)) }
            string(it, "email")?.let { value -> fields.put("applicantEmail", stringValue(value)) }
        }
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

    override suspend fun adminAccess(
        communityId: String,
        userId: String,
        idToken: String,
    ): Result<CommunityAdminAccess?> = runCatching {
        val document = try {
            request(
                "documents/organizations/$communityId/admins/$userId",
                "GET",
                idToken,
                null,
            ) as JSONObject
        } catch (error: CommunityHttpException) {
            if (error.status == 403 || error.status == 404) return@runCatching null
            throw error
        }
        val fields = document.optJSONObject("fields") ?: return@runCatching null
        if (boolean(fields, "isActive") == false) return@runCatching null
        val permissions = permissionValues(fields.optJSONObject("permissions"))
        CommunityAdminAccess(
            communityId = communityId,
            userId = userId,
            role = string(fields, "role") ?: "admin",
            permissions = permissions,
            isLegacyFullAccess = !fields.has("permissions"),
        )
    }

    override suspend fun pendingApplications(
        communityId: String,
        idToken: String,
    ): Result<List<CommunityMembership>> = runCatching {
        val body = JSONObject().put(
            "structuredQuery",
            JSONObject()
                .put("from", JSONArray().put(JSONObject().put("collectionId", "members")))
                .put(
                    "where",
                    JSONObject().put(
                        "fieldFilter",
                        JSONObject()
                            .put("field", JSONObject().put("fieldPath", "status"))
                            .put("op", "EQUAL")
                            .put("value", stringValue("pending")),
                    ),
                ),
        )
        val rows = request(
            "documents/organizations/$communityId:runQuery",
            "POST",
            idToken,
            body,
        ) as JSONArray
        buildList {
            for (index in 0 until rows.length()) {
                val document = rows.optJSONObject(index)?.optJSONObject("document") ?: continue
                parseMembership(document, null)?.let(::add)
            }
        }.sortedBy { it.createdAt.orEmpty() }
    }

    override suspend fun reviewApplication(
        communityId: String,
        applicantUserId: String,
        reviewerUserId: String,
        status: CommunityMembershipStatus,
        auditAction: String?,
        idToken: String,
    ): Result<Unit> = runCatching {
        require(
            status == CommunityMembershipStatus.Approved ||
                status == CommunityMembershipStatus.Rejected,
        ) { "承認または却下を指定してください。" }
        val statusValue = when (status) {
            CommunityMembershipStatus.Approved -> "approved"
            CommunityMembershipStatus.Rejected -> "rejected"
            CommunityMembershipStatus.Pending -> error("承認または却下を指定してください。")
        }
        val databaseRoot =
            "projects/$projectId/databases/(default)/documents"
        val membershipName =
            "$databaseRoot/organizations/$communityId/members/$applicantUserId"
        val auditName =
            "$databaseRoot/organizations/$communityId/auditLogs/" +
                java.util.UUID.randomUUID().toString()
        val membershipFields = JSONObject()
            .put("status", stringValue(statusValue))
            .put("reviewedByUserId", stringValue(reviewerUserId))
        val auditFields = JSONObject()
            .put(
                "action",
                stringValue(
                    auditAction ?: if (status == CommunityMembershipStatus.Approved) {
                        "membership.approved"
                    } else {
                        "membership.rejected"
                    },
                ),
            )
            .put("actorUserId", stringValue(reviewerUserId))
            .put("targetUserId", stringValue(applicantUserId))
            .put("communityId", stringValue(communityId))
        val writes = JSONArray()
            .put(
                JSONObject()
                    .put(
                        "update",
                        JSONObject()
                            .put("name", membershipName)
                            .put("fields", membershipFields),
                    )
                    .put(
                        "updateMask",
                        JSONObject().put(
                            "fieldPaths",
                            JSONArray()
                                .put("status")
                                .put("reviewedByUserId"),
                        ),
                    )
                    .put(
                        "updateTransforms",
                        JSONArray()
                            .put(serverTimestamp("updatedAt"))
                            .put(serverTimestamp("reviewedAt")),
                    )
                    .put(
                        "currentDocument",
                        JSONObject().put("exists", true),
                    ),
            )
            .put(
                JSONObject()
                    .put(
                        "update",
                        JSONObject()
                            .put("name", auditName)
                            .put("fields", auditFields),
                    )
                    .put(
                        "updateTransforms",
                        JSONArray().put(serverTimestamp("createdAt")),
                    )
                    .put(
                        "currentDocument",
                        JSONObject().put("exists", false),
                    ),
            )
        request(
            "documents:commit",
            "POST",
            idToken,
            JSONObject().put("writes", writes),
        )
        Unit
    }

    override suspend fun administrators(
        communityId: String,
        idToken: String,
    ): Result<List<CommunityAdmin>> = runCatching {
        val response = request(
            "documents/organizations/$communityId/admins?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                val document = documents.optJSONObject(index) ?: continue
                val fields = document.optJSONObject("fields") ?: continue
                val userId = document.optString("name").substringAfterLast("/")
                if (userId.isNotEmpty()) {
                    add(
                        CommunityAdmin(
                            userId = userId,
                            role = string(fields, "role") ?: "admin",
                            permissions = permissionValues(fields.optJSONObject("permissions")),
                            isActive = boolean(fields, "isActive") ?: true,
                        ),
                    )
                }
            }
        }.sortedBy { it.userId }
    }

    override suspend fun saveAdministrator(
        communityId: String,
        adminUserId: String,
        role: String,
        permissions: Set<String>,
        isActive: Boolean,
        actorUserId: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        val normalizedUserId = adminUserId.trim()
        require(normalizedUserId.isNotBlank()) { "管理者のユーザーIDを入力してください。" }
        require(actorUserId.isNotBlank()) { "操作したユーザーIDを入力してください。" }
        val permissionValues = JSONArray().apply {
            permissions.sorted().forEach { put(stringValue(it)) }
        }
        val fields = JSONObject()
            .put("uid", stringValue(normalizedUserId))
            .put("role", stringValue(role.ifBlank { "admin" }))
            .put("isActive", booleanValue(isActive))
            .put("permissions", JSONObject().put("arrayValue", JSONObject().put("values", permissionValues)))
        val databaseRoot = "projects/$projectId/databases/(default)/documents"
        val auditFields = JSONObject()
            .put(
                "action",
                stringValue(
                    if (isActive) "administrator.added" else "administrator.deactivated",
                ),
            )
            .put("actorUserId", stringValue(actorUserId))
            .put("targetUserId", stringValue(normalizedUserId))
            .put("communityId", stringValue(communityId))
        request(
            "documents:commit",
            "POST",
            idToken,
            JSONObject().put(
                "writes",
                JSONArray()
                    .put(
                        JSONObject()
                            .put(
                                "update",
                                JSONObject()
                                    .put(
                                        "name",
                                        "$databaseRoot/organizations/$communityId/admins/$normalizedUserId",
                                    )
                                    .put("fields", fields),
                            )
                            .put(
                                "updateTransforms",
                                JSONArray().put(serverTimestamp("updatedAt")),
                            ),
                    )
                    .put(
                        JSONObject()
                            .put(
                                "update",
                                JSONObject()
                                    .put(
                                        "name",
                                        "$databaseRoot/organizations/$communityId/auditLogs/" +
                                            java.util.UUID.randomUUID().toString(),
                                    )
                                    .put("fields", auditFields),
                            )
                            .put(
                                "updateTransforms",
                                JSONArray().put(serverTimestamp("createdAt")),
                            )
                            .put("currentDocument", JSONObject().put("exists", false)),
                    ),
            ),
        )
        Unit
    }

    override suspend fun communityMembers(
        communityId: String,
        idToken: String,
    ): Result<List<CommunityMembership>> = runCatching {
        val response = request(
            "documents/organizations/$communityId/members?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                documents.optJSONObject(index)?.let { parseMembership(it, null)?.let(::add) }
            }
        }.sortedBy { it.createdAt.orEmpty() }
    }

    override suspend fun auditLogs(
        communityId: String,
        idToken: String,
    ): Result<List<CommunityAuditLog>> = runCatching {
        val response = request(
            "documents/organizations/$communityId/auditLogs?pageSize=100",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                val document = documents.optJSONObject(index) ?: continue
                parseAuditLog(document)?.let(::add)
            }
        }.sortedByDescending { it.createdAt.orEmpty() }
    }

    override suspend fun bookingEvents(
        communityId: String,
        idToken: String,
    ): Result<List<BookingEvent>> = runCatching {
        val response = request(
            "documents/organizations/$communityId/bookingEvents?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                val document = documents.optJSONObject(index) ?: continue
                val fields = document.optJSONObject("fields") ?: continue
                if (boolean(fields, "isPublished") != true) continue
                add(
                    BookingEvent(
                        id = document.optString("name").substringAfterLast("/"),
                        communityId = communityId,
                        title = string(fields, "title") ?: "イベント",
                        description = string(fields, "description").orEmpty(),
                        eventDate = timestamp(fields, "eventDate"),
                        feeAmount = number(fields, "feeAmount")?.toInt() ?: 0,
                        paymentRequired = boolean(fields, "paymentRequired") ?: false,
                        zoomUrl = string(fields, "zoomURL") ?: string(fields, "zoomUrl"),
                        isPublished = true,
                    ),
                )
            }
        }.sortedBy { it.eventDate.orEmpty() }
    }

    override suspend fun adminBookingEvents(
        communityId: String,
        idToken: String,
    ): Result<List<BookingEvent>> = runCatching {
        val response = request(
            "documents/organizations/$communityId/bookingEvents?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                val document = documents.optJSONObject(index) ?: continue
                val fields = document.optJSONObject("fields") ?: continue
                add(
                    BookingEvent(
                        id = document.optString("name").substringAfterLast("/"),
                        communityId = communityId,
                        title = string(fields, "title") ?: "イベント",
                        description = string(fields, "description").orEmpty(),
                        eventDate = timestamp(fields, "eventDate"),
                        feeAmount = number(fields, "feeAmount")?.toInt() ?: 0,
                        paymentRequired = boolean(fields, "paymentRequired") ?: false,
                        zoomUrl = string(fields, "zoomURL") ?: string(fields, "zoomUrl"),
                        isPublished = boolean(fields, "isPublished") ?: false,
                    ),
                )
            }
        }.sortedBy { it.eventDate.orEmpty() }
    }

    override suspend fun saveBookingEvent(
        communityId: String,
        eventId: String,
        title: String,
        description: String,
        eventDate: String?,
        feeAmount: Int,
        paymentRequired: Boolean,
        zoomUrl: String,
        isPublished: Boolean,
        idToken: String,
    ): Result<Unit> = runCatching {
        require(title.trim().isNotEmpty()) { "イベント名を入力してください。" }
        require(feeAmount >= 0) { "料金は0円以上で入力してください。" }
        val fields = JSONObject()
            .put("title", stringValue(title.trim()))
            .put("description", stringValue(description.trim()))
            .put("feeAmount", JSONObject().put("integerValue", feeAmount.toString()))
            .put("paymentRequired", booleanValue(paymentRequired))
            .put("zoomURL", stringValue(zoomUrl.trim()))
            .put("isPublished", booleanValue(isPublished))
            .put("updatedAt", timestampValue(Instant.now().toString()))
        eventDate?.trim()?.takeIf(String::isNotEmpty)?.let {
            fields.put("eventDate", timestampValue(it))
        }
        request(
            "documents/organizations/$communityId/bookingEvents/${eventId.trim().ifEmpty { java.util.UUID.randomUUID().toString() }}",
            "PATCH",
            idToken,
            JSONObject().put("fields", fields),
        )
        Unit
    }

    override suspend fun bookingSlots(
        communityId: String,
        eventId: String,
        idToken: String,
    ): Result<List<BookingSlot>> = runCatching {
        val response = request(
            "documents/organizations/$communityId/bookingEvents/$eventId/slots?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                val document = documents.optJSONObject(index) ?: continue
                val fields = document.optJSONObject("fields") ?: continue
                add(
                    BookingSlot(
                        id = document.optString("name").substringAfterLast("/"),
                        eventId = eventId,
                        startAt = timestamp(fields, "startAt"),
                        endAt = timestamp(fields, "endAt"),
                        capacity = number(fields, "capacity")?.toInt() ?: 0,
                        reservedCount = number(fields, "reservedCount")?.toInt() ?: 0,
                        paidCount = number(fields, "paidCount")?.toInt() ?: 0,
                        isOpen = boolean(fields, "isOpen") ?: true,
                    ),
                )
            }
        }.sortedBy { it.startAt.orEmpty() }
    }

    override suspend fun bookingReservations(
        communityId: String,
        eventId: String,
        idToken: String,
    ): Result<List<BookingReservation>> = runCatching {
        val body = JSONObject().put(
            "structuredQuery",
            JSONObject()
                .put(
                    "from",
                    JSONArray().put(
                        JSONObject()
                            .put("collectionId", "bookings")
                            .put("allDescendants", true),
                    ),
                )
                .put(
                    "where",
                    JSONObject().put(
                        "fieldFilter",
                        JSONObject()
                            .put("field", JSONObject().put("fieldPath", "eventId"))
                            .put("op", "EQUAL")
                            .put("value", stringValue(eventId)),
                    ),
                ),
        )
        val rows = request("documents:runQuery", "POST", idToken, body) as JSONArray
        buildList {
            for (index in 0 until rows.length()) {
                val fields = rows.optJSONObject(index)
                    ?.optJSONObject("document")
                    ?.optJSONObject("fields") ?: continue
                if (string(fields, "organizationId") != communityId) continue
                val slotId = string(fields, "slotId") ?: continue
                val userId = string(fields, "memberUid") ?: continue
                add(
                    BookingReservation(
                        slotId = slotId,
                        userId = userId,
                        status = string(fields, "status") ?: "reserved",
                        purchaseStatus = string(fields, "purchaseStatus") ?: "not-required",
                    ),
                )
            }
        }.sortedWith(compareBy<BookingReservation> { it.slotId }.thenBy { it.userId })
    }

    override suspend fun saveBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        startAt: String?,
        endAt: String?,
        capacity: Int,
        isOpen: Boolean,
        idToken: String,
    ): Result<Unit> = runCatching {
        require(eventId.isNotBlank()) { "イベントを選択してください。" }
        require(capacity > 0) { "定員は1名以上で入力してください。" }
        val fields = JSONObject()
            .put("capacity", JSONObject().put("integerValue", capacity.toString()))
            .put("isOpen", booleanValue(isOpen))
            .put("updatedAt", timestampValue(Instant.now().toString()))
        startAt?.trim()?.takeIf(String::isNotEmpty)?.let {
            fields.put("startAt", timestampValue(it))
        }
        endAt?.trim()?.takeIf(String::isNotEmpty)?.let {
            fields.put("endAt", timestampValue(it))
        }
        request(
            "documents/organizations/$communityId/bookingEvents/$eventId/slots/${slotId.trim().ifEmpty { java.util.UUID.randomUUID().toString() }}",
            "PATCH",
            idToken,
            JSONObject().put("fields", fields),
        )
        Unit
    }

    override suspend fun bookedSlotIds(
        communityId: String,
        eventId: String,
        userId: String,
        idToken: String,
    ): Result<Set<String>> = runCatching {
        val body = JSONObject().put(
            "structuredQuery",
            JSONObject()
                .put(
                    "from",
                    JSONArray().put(
                        JSONObject()
                            .put("collectionId", "bookings")
                            .put("allDescendants", true),
                    ),
                )
                .put(
                    "where",
                    JSONObject().put(
                        "fieldFilter",
                        JSONObject()
                            .put("field", JSONObject().put("fieldPath", "memberUid"))
                            .put("op", "EQUAL")
                            .put("value", stringValue(userId)),
                    ),
                ),
        )
        val rows = request("documents:runQuery", "POST", idToken, body) as JSONArray
        buildSet {
            for (index in 0 until rows.length()) {
                val fields = rows.optJSONObject(index)
                    ?.optJSONObject("document")
                    ?.optJSONObject("fields") ?: continue
                if (
                    string(fields, "organizationId") == communityId &&
                    string(fields, "eventId") == eventId &&
                    string(fields, "status") == "reserved"
                ) {
                    string(fields, "slotId")?.let(::add)
                }
            }
        }
    }

    override suspend fun myBookingReservations(
        communityId: String,
        userId: String,
        idToken: String,
    ): Result<List<BookingReservation>> = runCatching {
        val body = JSONObject().put(
            "structuredQuery",
            JSONObject()
                .put(
                    "from",
                    JSONArray().put(
                        JSONObject()
                            .put("collectionId", "bookings")
                            .put("allDescendants", true),
                    ),
                )
                .put(
                    "where",
                    JSONObject().put(
                        "fieldFilter",
                        JSONObject()
                            .put("field", JSONObject().put("fieldPath", "memberUid"))
                            .put("op", "EQUAL")
                            .put("value", stringValue(userId)),
                    ),
                ),
        )
        val rows = request("documents:runQuery", "POST", idToken, body) as JSONArray
        buildList {
            for (index in 0 until rows.length()) {
                val fields = rows.optJSONObject(index)
                    ?.optJSONObject("document")
                    ?.optJSONObject("fields") ?: continue
                if (string(fields, "organizationId") != communityId) continue
                val eventId = string(fields, "eventId") ?: continue
                val slotId = string(fields, "slotId") ?: continue
                if (string(fields, "status") != "reserved") continue
                add(
                    BookingReservation(
                        eventId = eventId,
                        slotId = slotId,
                        userId = userId,
                        status = "reserved",
                        purchaseStatus = string(fields, "purchaseStatus") ?: "not-required",
                    ),
                )
            }
        }.sortedWith(compareBy<BookingReservation> { it.eventId }.thenBy { it.slotId })
    }

    override suspend fun reserveBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String,
    ): Result<Unit> = bookingRequest(
        endpoint = "reserveBookingSlotHttp",
        communityId = communityId,
        eventId = eventId,
        slotId = slotId,
        idToken = idToken,
    )

    override suspend fun cancelBookingSlot(
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String,
    ): Result<Unit> = bookingRequest(
        endpoint = "cancelBookingSlotHttp",
        communityId = communityId,
        eventId = eventId,
        slotId = slotId,
        idToken = idToken,
    )

    override suspend fun communityVideos(
        communityId: String,
        idToken: String,
    ): Result<List<DistributedVideo>> = runCatching {
        val response = request(
            "documents/organizations/$communityId/videos?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                val document = documents.optJSONObject(index) ?: continue
                val video = parseDistributedVideo(document, communityId)
                if (!video.isPublished || video.isPremium) continue
                add(video)
            }
        }.sortedWith(compareBy<DistributedVideo> { it.sortOrder }.thenBy { it.title })
    }

    override suspend fun radioPrograms(
        communityId: String,
        idToken: String,
    ): Result<List<RadioProgram>> = runCatching {
        val response = request(
            "documents/organizations/$communityId/radioPrograms?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                val document = documents.optJSONObject(index) ?: continue
                add(parseRadioProgram(document, communityId))
            }
        }
    }

    override suspend fun radioPlaybackRecords(
        userId: String,
        idToken: String,
    ): Result<List<RadioPlaybackRecord>> = runCatching {
        val response = request(
            "documents/memberPrivate/$userId/radioPlaybackRecords?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                val fields = documents.optJSONObject(index)?.optJSONObject("fields") ?: continue
                val programId = string(fields, "programId") ?: continue
                add(
                    RadioPlaybackRecord(
                        userId = string(fields, "userId") ?: userId,
                        programId = programId,
                        lastPositionSeconds = maxOf(
                            0,
                            (number(fields, "lastPositionSeconds") ?: 0.0).toLong(),
                        ),
                        playCount = maxOf(0, (number(fields, "playCount") ?: 0.0).toInt()),
                        lastPlayedAt = timestamp(fields, "lastPlayedAt")
                            ?.let { runCatching { Instant.parse(it) }.getOrNull() },
                    ),
                )
            }
        }
    }

    override suspend fun saveRadioPlaybackRecord(
        record: RadioPlaybackRecord,
        idToken: String,
    ): Result<Unit> = runCatching {
        val documentId = record.programId.replace(Regex("[^A-Za-z0-9_-]"), "_")
        val fields = JSONObject()
            .put("userId", stringValue(record.userId))
            .put("programId", stringValue(record.programId))
            .put(
                "lastPositionSeconds",
                JSONObject().put("integerValue", maxOf(0, record.lastPositionSeconds).toString()),
            )
            .put(
                "playCount",
                JSONObject().put("integerValue", maxOf(0, record.playCount).toString()),
            )
            .put(
                "lastPlayedAt",
                timestampValue((record.lastPlayedAt ?: Instant.now()).toString()),
            )
        request(
            "documents/memberPrivate/${record.userId}/radioPlaybackRecords/$documentId",
            "PATCH",
            idToken,
            JSONObject().put("fields", fields),
        )
        Unit
    }

    override suspend fun videoMemos(
        userId: String,
        idToken: String,
    ): Result<Map<String, String>> = runCatching {
        val response = request(
            "documents/memberPrivate/$userId/videoMemos?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildMap {
            for (index in 0 until documents.length()) {
                val fields = documents.optJSONObject(index)?.optJSONObject("fields") ?: continue
                val communityId = string(fields, "communityId") ?: continue
                val videoId = string(fields, "videoId") ?: continue
                string(fields, "memo")?.let { put("$communityId:$videoId", it) }
            }
        }
    }

    override suspend fun saveVideoMemo(
        userId: String,
        communityId: String,
        videoId: String,
        memo: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        val documentId = "$communityId-$videoId".replace(Regex("[^A-Za-z0-9_-]"), "_")
        val path = "documents/memberPrivate/$userId/videoMemos/$documentId"
        val normalized = memo.trim()
        if (normalized.isEmpty()) {
            request(path, "DELETE", idToken, null)
        } else {
            val fields = JSONObject()
                .put("userId", stringValue(userId))
                .put("communityId", stringValue(communityId))
                .put("videoId", stringValue(videoId))
                .put("memo", stringValue(normalized))
                .put("updatedAt", timestampValue(Instant.now().toString()))
            request(path, "PATCH", idToken, JSONObject().put("fields", fields))
        }
        Unit
    }

    override suspend fun videoQuestions(
        communityId: String,
        memberUid: String,
        idToken: String,
    ): Result<List<VideoQuestion>> = runCatching {
        val body = JSONObject().put(
            "structuredQuery",
            JSONObject()
                .put("from", JSONArray().put(JSONObject().put("collectionId", "videoQuestions")))
                .put(
                    "where",
                    JSONObject().put(
                        "fieldFilter",
                        JSONObject()
                            .put("field", JSONObject().put("fieldPath", "memberUid"))
                            .put("op", "EQUAL")
                            .put("value", stringValue(memberUid)),
                    ),
                ),
        )
        val rows = request("documents/organizations/$communityId:runQuery", "POST", idToken, body) as JSONArray
        buildList {
            for (index in 0 until rows.length()) {
                val document = rows.optJSONObject(index)?.optJSONObject("document") ?: continue
                val fields = document.optJSONObject("fields") ?: continue
                val question = string(fields, "questionText") ?: continue
                add(
                    VideoQuestion(
                        id = document.optString("name").substringAfterLast("/"),
                        communityId = communityId,
                        memberUid = string(fields, "memberUid") ?: memberUid,
                        videoId = string(fields, "videoId").orEmpty(),
                        videoTitle = string(fields, "videoTitle").orEmpty(),
                        playbackSeconds = number(fields, "playbackSeconds") ?: 0.0,
                        memoText = string(fields, "memoText").orEmpty(),
                        questionText = question,
                        answerText = string(fields, "answerText").orEmpty(),
                        createdAt = timestamp(fields, "createdAt"),
                        answeredAt = timestamp(fields, "answeredAt"),
                        syncStatus = VideoQuestionSyncStatus.fromValue(string(fields, "syncStatus")),
                        clientRequestId = string(fields, "clientRequestId") ?: document.optString("name").substringAfterLast("/"),
                    ),
                )
            }
        }.sortedByDescending { it.createdAt.orEmpty() }
    }

    override suspend fun adminVideoQuestions(
        communityId: String,
        idToken: String,
    ): Result<List<VideoQuestion>> = runCatching {
        val response = request(
            "documents/organizations/$communityId/videoQuestions?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                val document = documents.optJSONObject(index) ?: continue
                val fields = document.optJSONObject("fields") ?: continue
                val question = string(fields, "questionText") ?: continue
                add(
                    VideoQuestion(
                        id = document.optString("name").substringAfterLast("/"),
                        communityId = communityId,
                        memberUid = string(fields, "memberUid").orEmpty(),
                        videoId = string(fields, "videoId").orEmpty(),
                        videoTitle = string(fields, "videoTitle").orEmpty(),
                        playbackSeconds = number(fields, "playbackSeconds") ?: 0.0,
                        memoText = string(fields, "memoText").orEmpty(),
                        questionText = question,
                        answerText = string(fields, "answerText").orEmpty(),
                        createdAt = timestamp(fields, "createdAt"),
                        answeredAt = timestamp(fields, "answeredAt"),
                        syncStatus = VideoQuestionSyncStatus.fromValue(string(fields, "syncStatus")),
                        clientRequestId = string(fields, "clientRequestId") ?: document.optString("name").substringAfterLast("/"),
                    ),
                )
            }
        }.sortedByDescending { it.createdAt.orEmpty() }
    }

    override suspend fun saveVideoQuestion(
        communityId: String,
        memberUid: String,
        video: DistributedVideo,
        memoText: String,
        questionText: String,
        playbackSeconds: Double,
        clientRequestId: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        val normalized = questionText.trim()
        require(normalized.isNotEmpty()) { "質問内容を入力してください。" }
        val normalizedRequestId = clientRequestId.trim()
        require(normalizedRequestId.isNotEmpty()) { "clientRequestId is required." }
        val documentId = normalizedRequestId.replace(Regex("[^A-Za-z0-9_-]"), "_")
        val fields = JSONObject()
            .put("memberUid", stringValue(memberUid))
            .put("videoId", stringValue(video.id))
            .put("videoType", stringValue("vimeo"))
            .put("videoTitle", stringValue(video.title))
            .put("playbackSeconds", JSONObject().put("doubleValue", playbackSeconds))
            .put("memoText", stringValue(memoText.trim()))
            .put("questionText", stringValue(normalized))
            .put("answerText", stringValue(""))
            .put("answeredAt", JSONObject().put("nullValue", JSONObject.NULL))
            .put("syncStatus", stringValue(VideoQuestionSyncStatus.Synced.rawValue()))
            .put("clientRequestId", stringValue(normalizedRequestId))
            .put("createdAt", timestampValue(Instant.now().toString()))
        try {
            request(
                "documents/organizations/$communityId/videoQuestions?documentId=$documentId",
                "POST",
                idToken,
                JSONObject().put("fields", fields),
            )
        } catch (error: CommunityHttpException) {
            if (error.status != 409) throw error
            // A create-only retry means the first request already committed.
        }
        Unit
    }

    override suspend fun answerVideoQuestion(
        communityId: String,
        questionId: String,
        answerText: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        val normalized = answerText.trim()
        val answeredAt = Instant.now().toString()
        val fields = JSONObject()
            .put("answerText", stringValue(normalized))
            .put("answeredAt", timestampValue(answeredAt))
            .put("updatedAt", timestampValue(answeredAt))
        request(
            "documents/organizations/$communityId/videoQuestions/$questionId",
            "PATCH",
            idToken,
            JSONObject().put("fields", fields),
        )
        Unit
    }

    override suspend fun adminCommunityVideos(
        communityId: String,
        idToken: String,
    ): Result<List<DistributedVideo>> = runCatching {
        val response = request(
            "documents/organizations/$communityId/videos?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        val documents = response.optJSONArray("documents") ?: JSONArray()
        buildList {
            for (index in 0 until documents.length()) {
                val document = documents.optJSONObject(index) ?: continue
                val video = parseDistributedVideo(document, communityId)
                if (video.isPremium) continue
                add(video)
            }
        }.sortedWith(compareBy<DistributedVideo> { it.sortOrder }.thenBy { it.title })
    }

    override suspend fun vimeoLibraryVideos(
        communityId: String,
        idToken: String,
        folderId: String?,
    ): Result<List<DistributedVideo>> = runCatching {
        withContext(Dispatchers.IO) {
            val connection = (
                URL(
                    "https://asia-northeast1-$projectId.cloudfunctions.net/" +
                        "fetchVimeoVideosHttp",
                ).openConnection() as HttpURLConnection
                ).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Authorization", "Bearer $idToken")
                setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            }
            try {
                connection.outputStream.use {
                    it.write(JSONObject().put("organizationId", communityId)
                        .apply { if (!folderId.isNullOrBlank()) put("folderId", folderId) }
                        .toString()
                        .toByteArray(Charsets.UTF_8))
                }
                val status = connection.responseCode
                val responseText = (if (status in 200..299) connection.inputStream else connection.errorStream)
                    ?.bufferedReader()?.use { it.readText() }.orEmpty()
                if (status !in 200..299) {
                    throw CommunityRepositoryException(
                        "Vimeo動画の取得に失敗しました（HTTP $status）。",
                    )
                }
                        val videos = JSONObject(responseText).optJSONArray("videos") ?: JSONArray()
                        buildList {
                            for (index in 0 until videos.length()) {
                                val video = videos.optJSONObject(index) ?: continue
                                val vimeoVideoId = video.optString("id").trim()
                                if (vimeoVideoId.isEmpty()) continue
                                add(
                                    DistributedVideo(
                                        id = vimeoVideoId,
                                        communityId = communityId,
                                        videoTitle = video.optString("title", "Vimeo動画"),
                                        description = video.optString("description"),
                                        videoUrl = video.optString("link").ifBlank { "" },
                                        vimeoUrl = "https://vimeo.com/$vimeoVideoId",
                                        providerVideoId = vimeoVideoId,
                                        videoType = "distributed_vimeo",
                                        thumbnailUrl = video.optString("thumbnailUrl").ifBlank { "" },
                                        isPublished = false,
                                        isMembersOnly = true,
                                        isPremium = false,
                                        sortOrder = 0,
                                    ),
                                )
                            }
                        }.sortedBy { it.title }
            } finally {
                connection.disconnect()
            }
        }
    }

    override suspend fun vimeoFolders(
        communityId: String,
        idToken: String,
    ): Result<List<VimeoFolder>> = runCatching {
        withContext(Dispatchers.IO) {
            val connection = (
                URL(
                    "https://asia-northeast1-$projectId.cloudfunctions.net/" +
                        "fetchVimeoFoldersHttp",
                ).openConnection() as HttpURLConnection
                ).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Authorization", "Bearer $idToken")
                setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            }
            try {
                connection.outputStream.use {
                    it.write(JSONObject().put("organizationId", communityId).toString()
                        .toByteArray(Charsets.UTF_8))
                }
                val status = connection.responseCode
                val responseText = (if (status in 200..299) connection.inputStream else connection.errorStream)
                    ?.bufferedReader()?.use { it.readText() }.orEmpty()
                if (status !in 200..299) {
                    throw CommunityRepositoryException(
                        "Vimeoフォルダの取得に失敗しました（HTTP $status）。",
                    )
                }
                val folders = JSONObject(responseText).optJSONArray("folders") ?: JSONArray()
                buildList {
                    for (index in 0 until folders.length()) {
                        val folder = folders.optJSONObject(index) ?: continue
                        val id = folder.optString("id").trim()
                        if (id.isNotEmpty()) {
                            add(VimeoFolder(id, folder.optString("name", "名称未設定フォルダ")))
                        }
                    }
                }.sortedBy { it.name }
            } finally {
                connection.disconnect()
            }
        }
    }

    override suspend fun vimeoConfiguration(
        communityId: String,
        idToken: String,
    ): Result<VimeoConfiguration> = runCatching {
        withContext(Dispatchers.IO) {
            val connection = (
                URL("https://asia-northeast1-$projectId.cloudfunctions.net/getVimeoConfigHttp")
                    .openConnection() as HttpURLConnection
                ).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Authorization", "Bearer $idToken")
                setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            }
            try {
                connection.outputStream.use {
                    it.write(JSONObject().put("organizationId", communityId).toString()
                        .toByteArray(Charsets.UTF_8))
                }
                val status = connection.responseCode
                val text = (if (status in 200..299) connection.inputStream else connection.errorStream)
                    ?.bufferedReader()?.use { it.readText() }.orEmpty()
                if (status !in 200..299) {
                    throw CommunityRepositoryException("Vimeo接続設定を取得できませんでした（HTTP $status）。")
                }
                val payload = JSONObject(text)
                VimeoConfiguration(
                    hasAccessToken = payload.optBoolean("hasAccessToken"),
                    userId = payload.optString("userId"),
                    query = payload.optString("query"),
                )
            } finally {
                connection.disconnect()
            }
        }
    }

    override suspend fun saveVimeoConfiguration(
        communityId: String,
        accessToken: String,
        userId: String,
        query: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        require(accessToken.trim().isNotEmpty()) { "Vimeoアクセストークンを入力してください。" }
        require(userId.trim().isNotEmpty()) { "VimeoユーザーIDを入力してください。" }
        withContext(Dispatchers.IO) {
            val connection = (
                URL("https://asia-northeast1-$projectId.cloudfunctions.net/saveVimeoConfigHttp")
                    .openConnection() as HttpURLConnection
                ).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Authorization", "Bearer $idToken")
                setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            }
            try {
                val body = JSONObject()
                    .put("organizationId", communityId)
                    .put("accessToken", accessToken.trim())
                    .put("userId", userId.trim())
                    .put("query", query.trim())
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                if (connection.responseCode !in 200..299) {
                    throw CommunityRepositoryException("Vimeo接続設定を保存できませんでした。")
                }
                Unit
            } finally {
                connection.disconnect()
            }
        }
    }

    override suspend fun saveCommunityVideo(
        communityId: String,
        videoId: String,
        title: String,
        description: String,
        vimeoVideoId: String,
        vimeoUrl: String,
        thumbnailUrl: String,
        isPublished: Boolean,
        idToken: String,
    ): Result<Unit> = runCatching {
        require(title.trim().isNotEmpty()) { "動画タイトルを入力してください。" }
        require(vimeoVideoId.trim().isNotEmpty()) { "Vimeo動画IDを入力してください。" }
        val fields = JSONObject()
            .put("title", stringValue(title.trim()))
            .put("description", stringValue(description.trim()))
            .put("vimeoVideoId", stringValue(vimeoVideoId.trim()))
            .put("vimeoUrl", stringValue(vimeoUrl.trim().ifEmpty { "https://vimeo.com/${vimeoVideoId.trim()}" }))
            .put("thumbnailUrl", stringValue(thumbnailUrl.trim()))
            .put("isPublished", booleanValue(isPublished))
            .put("isMembersOnly", booleanValue(true))
            .put("sortOrder", stringValue("0"))
            .put("updatedAt", timestampValue(Instant.now().toString()))
        request(
            "documents/organizations/$communityId/videos/${videoId.trim().ifEmpty { java.util.UUID.randomUUID().toString() }}",
            "PATCH",
            idToken,
            JSONObject().put("fields", fields),
        )
        Unit
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
            surfingVisible = boolean(fields, "communitySurfingVisible") ?: false,
        )
    }

    private fun parseMembership(
        document: JSONObject,
        userId: String?,
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
            id = parts.lastOrNull() ?: userId.orEmpty(),
            communityId = parts[organizationIndex + 1],
            userId = string(fields, "uid") ?: string(fields, "userId") ?: userId.orEmpty(),
            status = status,
            role = string(fields, "role") ?: "member",
            joinedAt = timestamp(fields, "joinedAt"),
            applicantName = string(fields, "applicantName"),
            applicantFurigana = string(fields, "applicantFurigana"),
            applicantEmail = string(fields, "applicantEmail"),
            createdAt = timestamp(fields, "createdAt"),
            categoryIds = (
                stringArray(fields, "categoryIds") +
                    stringArray(fields, "categories") +
                    listOfNotNull(string(fields, "categoryId"))
                ).toSet(),
        )
    }

    private fun parseAuditLog(document: JSONObject): CommunityAuditLog? {
        val fields = document.optJSONObject("fields") ?: return null
        val action = string(fields, "action") ?: return null
        val pathParts = document.optString("name").split("/")
        val organizationIndex = pathParts.indexOfLast { it == "organizations" }
        val communityId = when {
            organizationIndex >= 0 && organizationIndex + 1 < pathParts.size ->
                pathParts[organizationIndex + 1]
            else -> string(fields, "communityId")
        } ?: return null
        return CommunityAuditLog(
            id = document.optString("name").substringAfterLast("/"),
            action = action,
            actorUserId = string(fields, "actorUserId"),
            targetUserId = string(fields, "targetUserId"),
            communityId = communityId,
            createdAt = timestamp(fields, "createdAt"),
        )
    }

    private suspend fun memberProfile(userId: String, idToken: String): JSONObject {
        val document = request(
            "documents/memberPrivate/$userId",
            "GET",
            idToken,
            null,
        ) as JSONObject
        return document.optJSONObject("fields") ?: JSONObject()
    }

    private suspend fun bookingRequest(
        endpoint: String,
        communityId: String,
        eventId: String,
        slotId: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        withContext(Dispatchers.IO) {
            val connection = (
                URL("https://asia-northeast1-$projectId.cloudfunctions.net/$endpoint")
                    .openConnection() as HttpURLConnection
                ).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Authorization", "Bearer $idToken")
                setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            }
            try {
                connection.outputStream.use {
                    it.write(
                        JSONObject()
                            .put("organizationId", communityId)
                            .put("eventId", eventId)
                            .put("slotId", slotId)
                            .toString()
                            .toByteArray(Charsets.UTF_8),
                    )
                }
                if (connection.responseCode !in 200..299) {
                    throw CommunityRepositoryException("イベント予約の処理に失敗しました。")
                }
            } finally {
                connection.disconnect()
            }
        }
        Unit
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
            idToken?.let {
                setRequestProperty("Authorization", "Bearer $it")
            }
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
                throw CommunityHttpException(status, message)
            }
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
    private fun serverTimestamp(fieldPath: String) = JSONObject()
        .put("fieldPath", fieldPath)
        .put("setToServerValue", "REQUEST_TIME")
    private fun permissionValues(value: JSONObject?): Set<String> {
        if (value == null) return emptySet()
        value.optJSONObject("arrayValue")
            ?.optJSONArray("values")
            ?.let { values ->
                return buildSet {
                    for (index in 0 until values.length()) {
                        values.optJSONObject(index)
                            ?.optString("stringValue")
                            ?.takeIf { it.isNotEmpty() }
                            ?.let(::add)
                    }
                }
            }
        value.optJSONObject("mapValue")
            ?.optJSONObject("fields")
            ?.let { fields ->
                return buildSet {
                    val keys = fields.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        if (fields.optJSONObject(key)?.optBoolean("booleanValue") == true) {
                            add(key)
                        }
                    }
                }
            }
        return emptySet()
    }
    private fun stringArray(fields: JSONObject, key: String): List<String> {
        val values = fields.optJSONObject(key)
            ?.optJSONObject("arrayValue")
            ?.optJSONArray("values") ?: return emptyList()
        return buildList {
            for (index in 0 until values.length()) {
                values.optJSONObject(index)
                    ?.optString("stringValue")
                    ?.takeIf { it.isNotEmpty() }
                    ?.let(::add)
            }
        }
    }
}

private fun string(fields: JSONObject, key: String): String? =
    fields.optJSONObject(key)?.optString("stringValue")?.takeIf { it.isNotEmpty() }
private fun boolean(fields: JSONObject, key: String): Boolean? =
    fields.optJSONObject(key)?.takeIf { it.has("booleanValue") }?.optBoolean("booleanValue")
private fun timestamp(fields: JSONObject, key: String): String? =
    fields.optJSONObject(key)?.optString("timestampValue")?.takeIf { it.isNotEmpty() }
private fun number(fields: JSONObject, key: String): Double? =
    fields.optJSONObject(key)?.let { value ->
        when {
            value.has("doubleValue") -> value.optDouble("doubleValue")
            value.has("integerValue") -> value.optString("integerValue").toDoubleOrNull()
            else -> null
        }
    }

internal fun parseDistributedVideo(document: JSONObject, communityId: String): DistributedVideo {
    val fields = document.optJSONObject("fields") ?: JSONObject()
    val documentId = document.optString("name").substringAfterLast("/")
    val providerVideoId = string(fields, "providerVideoId")
        ?: string(fields, "vimeoVideoId")
        ?: ""
    val resolvedId = when {
        documentId.isNotBlank() -> documentId
        providerVideoId.isNotBlank() -> providerVideoId
        else -> UUID.randomUUID().toString()
    }
    return DistributedVideo(
        id = resolvedId,
        communityId = communityId,
        videoTitle = string(fields, "videoTitle")
            ?: string(fields, "title")
            ?: "Vimeo動画",
        description = string(fields, "description") ?: "",
        embedHtml = string(fields, "embedHtml") ?: "",
        videoUrl = string(fields, "videoUrl") ?: "",
        vimeoUrl = if (providerVideoId.isNotBlank()) {
            "https://vimeo.com/$providerVideoId"
        } else {
            string(fields, "vimeoUrl") ?: string(fields, "videoUrl") ?: ""
        },
        providerVideoId = providerVideoId,
        videoType = string(fields, "videoType") ?: "distributed_vimeo",
        thumbnailUrl = string(fields, "thumbnailUrl") ?: "",
        sortOrder = (number(fields, "sortOrder")?.toInt() ?: 0),
        primaryCategoryId = string(fields, "primaryCategoryId")
            ?: string(fields, "category")
            ?: string(fields, "categoryId")
            ?: "",
        secondaryCategoryId = string(fields, "secondaryCategoryId") ?: "",
        isPublished = boolean(fields, "isPublished") ?: false,
        isMembersOnly = boolean(fields, "isMembersOnly") ?: false,
        isPremium = boolean(fields, "isPremium") ?: false,
        createdAt = timestamp(fields, "createdAt") ?: "",
        updatedAt = timestamp(fields, "updatedAt") ?: "",
    )
}

internal fun parseRadioProgram(document: JSONObject, communityId: String): RadioProgram {
    val fields = document.optJSONObject("fields") ?: JSONObject()
    val documentId = document.optString("name").substringAfterLast("/")
    fun instant(key: String): Instant = timestamp(fields, key)
        ?.let { value -> runCatching { Instant.parse(value) }.getOrNull() }
        ?: Instant.EPOCH

    return RadioProgram(
        id = documentId.takeIf(String::isNotBlank) ?: UUID.randomUUID().toString(),
        communityId = communityId,
        title = string(fields, "title") ?: "ラジオ番組",
        description = string(fields, "description") ?: "",
        imageUrl = string(fields, "imageUrl") ?: "",
        audioUrl = string(fields, "audioUrl") ?: "",
        broadcastStartAt = instant("broadcastStartAt"),
        broadcastEndAt = instant("broadcastEndAt"),
    )
}
