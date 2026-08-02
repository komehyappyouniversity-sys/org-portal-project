package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.VideoQuestion
import jp.komehyappyo.member.next.core.model.VideoQuestionStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.UUID

class FirebaseRestVideoQuestionRepository(
    private val projectId: String,
) : VideoQuestionRepository {
    override suspend fun myQuestions(
        communityId: String,
        memberUid: String,
        idToken: String,
    ): Result<List<VideoQuestion>> = runCatching {
        listDocuments(communityId, idToken)
            .mapNotNull { parse(it, communityId) }
            .filter { it.memberUid == memberUid }
            .sortedByDescending { it.createdAt }
    }

    override suspend fun openQuestions(
        communityId: String,
        idToken: String,
    ): Result<List<VideoQuestion>> = runCatching {
        listDocuments(communityId, idToken)
            .mapNotNull { parse(it, communityId) }
            .filter { it.status != VideoQuestionStatus.Answered }
            .sortedByDescending { it.createdAt }
    }

    override suspend fun createQuestion(
        communityId: String,
        videoId: String,
        videoType: String,
        videoTitle: String,
        memberUid: String,
        memberName: String,
        memberEmail: String,
        questionText: String,
        noteText: String,
        seconds: Int,
        idToken: String,
    ): Result<Unit> = runCatching {
        val now = Instant.now().toString()
        val fields = JSONObject()
            .put("organizationId", stringValue(communityId))
            .put("videoId", stringValue(videoId))
            .put("videoType", stringValue(videoType.ifBlank { "personal_youtube" }))
            .put("videoTitle", stringValue(videoTitle))
            .put("memberUid", stringValue(memberUid))
            .put("memberName", stringValue(memberName.ifBlank { "会員" }))
            .put("memberEmail", stringValue(memberEmail))
            .put("questionText", stringValue(questionText))
            .put("noteText", stringValue(noteText))
            .put("seconds", integerValue(seconds.coerceAtLeast(0)))
            .put("status", stringValue(VideoQuestionStatus.Unanswered.raw))
            .put("answerText", stringValue(""))
            .put("createdAt", timestampValue(now))
            .put("updatedAt", timestampValue(now))
        request(
            "documents/organizations/$communityId/videoQuestions?documentId=${UUID.randomUUID()}",
            "PATCH",
            idToken,
            JSONObject().put("fields", fields),
        )
        Unit
    }

    override suspend fun answerQuestion(
        communityId: String,
        questionId: String,
        answerText: String,
        idToken: String,
    ): Result<Unit> = runCatching {
        val fields = JSONObject()
            .put("answerText", stringValue(answerText.trim()))
            .put("status", stringValue(VideoQuestionStatus.Answered.raw))
            .put("answeredAt", timestampValue(Instant.now().toString()))
            .put("updatedAt", timestampValue(Instant.now().toString()))

        request(
            "documents/organizations/$communityId/videoQuestions/$questionId"
                + "?updateMask.fieldPaths=answerText"
                + "&updateMask.fieldPaths=status"
                + "&updateMask.fieldPaths=answeredAt"
                + "&updateMask.fieldPaths=updatedAt",
            "PATCH",
            idToken,
            JSONObject().put("fields", fields),
        )
        Unit
    }

    private suspend fun listDocuments(communityId: String, idToken: String): List<JSONObject> {
        val result = request(
            "documents/organizations/$communityId/videoQuestions?pageSize=1000",
            "GET",
            idToken,
            null,
        ) as JSONObject
        return result.optJSONArray("documents")?.let { documents ->
            buildList {
                for (index in 0 until documents.length()) {
                    documents.optJSONObject(index)?.let(::add)
                }
            }
        } ?: emptyList()
    }

    private fun parse(document: JSONObject, communityId: String): VideoQuestion? {
        val fields = document.optJSONObject("fields") ?: return null
        val rawId = document.optString("name").substringAfterLast("/")
        val id = runCatching { rawId.ifEmpty { java.util.UUID.randomUUID().toString() } }.getOrNull()
            ?: return null
        return runCatching {
            VideoQuestion(
                id = id,
                communityId = fields.string("organizationId") ?: communityId,
                videoId = fields.string("videoId") ?: "",
                videoType = fields.string("videoType") ?: "personal_youtube",
                videoTitle = fields.string("videoTitle") ?: "",
                memberUid = fields.string("memberUid") ?: "",
                memberName = fields.string("memberName") ?: "",
                memberEmail = fields.string("memberEmail") ?: "",
                noteText = fields.string("noteText") ?: "",
                questionText = fields.string("questionText") ?: "",
                seconds = fields.int("seconds"),
                answerText = fields.string("answerText") ?: "",
                status = VideoQuestionStatus.parse(fields.string("status")),
                createdAt = fields.timestamp("createdAt") ?: Instant.now(),
                updatedAt = fields.timestamp("updatedAt") ?: Instant.now(),
                answeredAt = fields.timestamp("answeredAt"),
            )
        }.getOrNull()
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
            body?.let {
                connection.outputStream.use { stream ->
                    stream.write(it.toString().toByteArray(Charsets.UTF_8))
                }
            }
            val status = connection.responseCode
            if (status !in 200..299) {
                if (status == 403) {
                    throw IllegalStateException("権限がありません。参加済みコミュニティと管理者権限を確認してください。")
                }
                throw IllegalStateException("動画質問を処理できませんでした。時間をおいて再度お試しください。")
            }
            if (status == HttpURLConnection.HTTP_NO_CONTENT) return@withContext JSONObject()
            val text = connection.inputStream.bufferedReader().use { it.readText() }
            if (text.isBlank()) JSONObject()
            else if (text.trimStart().startsWith("{")) JSONObject(text) else JSONObject()
        } finally {
            connection.disconnect()
        }
    }

    private fun JSONObject.string(key: String): String? =
        optJSONObject(key)?.takeIf { !it.optString("stringValue").isNullOrEmpty() }
            ?.optString("stringValue")

    private fun JSONObject.int(key: String): Int =
        optJSONObject(key)?.let {
            runCatching { it.optString("integerValue").toInt() }.getOrNull()
                ?: runCatching { it.optDouble("integerValue").toInt() }.getOrNull()
                ?: it.optDouble("doubleValue").toInt()
        } ?: 0

    private fun JSONObject.timestamp(key: String): Instant? {
        val raw = optJSONObject(key)?.optString("timestampValue") ?: return null
        return runCatching { Instant.parse(raw) }.getOrNull()
    }

    private fun stringValue(value: String) = JSONObject().put("stringValue", value)
    private fun integerValue(value: Int) = JSONObject().put("integerValue", value.toString())
    private fun timestampValue(value: String) = JSONObject().put("timestampValue", value)
}
