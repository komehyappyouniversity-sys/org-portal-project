package jp.komehyappyo.member.next.feature.tools

import android.content.Context
import jp.komehyappyo.member.next.core.model.VideoQuestion
import jp.komehyappyo.member.next.core.model.VideoQuestionSyncStatus
import org.json.JSONArray
import org.json.JSONObject

interface VimeoMemoStoreProtocol {
    fun entries(communityId: String, videoId: String): List<VimeoVideoMemo>
    fun entries(fromRaw: String): List<VimeoVideoMemo>
    fun allEntries(): Map<String, List<VimeoVideoMemo>>
    fun pendingEntries(): Map<String, List<VimeoVideoMemo>>
    fun serialized(entries: List<VimeoVideoMemo>): String
    fun save(communityId: String, videoId: String, entries: List<VimeoVideoMemo>)
    fun saveAll(memos: Map<String, String>)
}

data class VimeoVideoMemo(
    val id: String,
    val text: String,
    val playbackSeconds: Double,
    val createdAtMillis: Long,
    val updatedAtMillis: Long,
    val syncStatus: jp.komehyappyo.member.next.core.model.VimeoVideoMemoSyncStatus =
        jp.komehyappyo.member.next.core.model.VimeoVideoMemoSyncStatus.Synced,
)

class VimeoMemoStore(context: Context) : VimeoMemoStoreProtocol {
    private val preferences = context.getSharedPreferences(
        "vimeo_video_memos",
        Context.MODE_PRIVATE,
    )

    override fun entries(communityId: String, videoId: String): List<VimeoVideoMemo> {
        return entries(fromRaw = read().optString(key(communityId, videoId), ""))
            .sortedByDescending { it.createdAtMillis }
    }

    override fun allEntries(): Map<String, List<VimeoVideoMemo>> {
        return read().let {
            buildMap {
                it.keys().forEach { k ->
                    put(k, entries(fromRaw = it.optString(k, "")))
                }
            }
        }
    }

    override fun pendingEntries(): Map<String, List<VimeoVideoMemo>> =
        allEntries().mapValues { it.value.filter { item ->
            item.syncStatus == jp.komehyappyo.member.next.core.model.VimeoVideoMemoSyncStatus.PendingSync
        } }.filterValues { it.isNotEmpty() }

    override fun entries(fromRaw: String): List<VimeoVideoMemo> {
        if (fromRaw.isBlank()) return emptyList()
        val parsed = runCatching {
            val array = JSONArray(fromRaw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val status = item.optString("syncStatus", "")
                    add(
                        VimeoVideoMemo(
                            id = item.optString("id"),
                            text = item.optString("text"),
                            playbackSeconds = item.optDouble("playbackSeconds", 0.0),
                            createdAtMillis = item.optLong("createdAtMillis", 0),
                            updatedAtMillis = item.optLong("updatedAtMillis", 0),
                            syncStatus = jp.komehyappyo.member.next.core.model.VimeoVideoMemoSyncStatus.fromValue(
                                status.ifBlank { "synced" },
                            ),
                        ),
                    )
                }
            }
        }.getOrNull()

        return parsed ?: listOf(
            VimeoVideoMemo(
                id = "legacy",
                text = fromRaw,
                playbackSeconds = 0.0,
                createdAtMillis = 0L,
                updatedAtMillis = 0L,
            ),
        )
    }

    override fun serialized(entries: List<VimeoVideoMemo>): String {
        if (entries.isEmpty()) return ""

        return JSONArray().apply {
            entries.forEach { entry ->
                put(
                    JSONObject()
                        .put("id", entry.id)
                        .put("text", entry.text)
                        .put("playbackSeconds", entry.playbackSeconds)
                        .put("createdAtMillis", entry.createdAtMillis)
                        .put("updatedAtMillis", entry.updatedAtMillis)
                        .put("syncStatus", entry.syncStatus.rawValue()),
                )
            }
        }.toString()
    }

    override fun save(communityId: String, videoId: String, entries: List<VimeoVideoMemo>) {
        val values = read()
        val value = serialized(entries)
        if (value.isEmpty()) {
            values.remove(key(communityId, videoId))
        } else {
            values.put(key(communityId, videoId), value)
        }
        preferences.edit().putString(STORAGE_KEY, values.toString()).apply()
    }

    override fun saveAll(memos: Map<String, String>) {
        val values = JSONObject()
        memos.forEach { (k, v) -> values.put(k, v) }
        preferences.edit().putString(STORAGE_KEY, values.toString()).apply()
    }

    private fun read(): JSONObject = runCatching {
        JSONObject(preferences.getString(STORAGE_KEY, "{}") ?: "{}")
    }.getOrDefault(JSONObject())

    private fun key(communityId: String, videoId: String): String =
        "$communityId:$videoId"

    private companion object {
        const val STORAGE_KEY = "memo_values"
    }
}

interface VideoQuestionStoreProtocol {
    fun questions(communityId: String, memberUid: String): List<VideoQuestion>
    fun pendingQuestions(communityId: String, memberUid: String): List<VideoQuestion>
    fun save(question: VideoQuestion)
    fun replaceQuestions(communityId: String, memberUid: String, questions: List<VideoQuestion>)
}

class VideoQuestionDraftStore(context: Context) : VideoQuestionStoreProtocol {
    private val preferences = context.getSharedPreferences(
        "video_question_drafts",
        Context.MODE_PRIVATE,
    )

    override fun questions(communityId: String, memberUid: String): List<VideoQuestion> =
        allQuestions()
            .filter { it.communityId == communityId && it.memberUid == memberUid }
            .sortedByDescending { it.createdAt.orEmpty() }

    override fun pendingQuestions(communityId: String, memberUid: String): List<VideoQuestion> =
        questions(communityId, memberUid).filter { it.syncStatus.requiresSync }

    override fun save(question: VideoQuestion) {
        val values = allQuestions().toMutableList()
        val identity = identity(question)
        val index = values.indexOfFirst { identity(it) == identity }
        if (index >= 0) {
            values[index] = question
        } else {
            values += question
        }
        write(values)
    }

    override fun replaceQuestions(
        communityId: String,
        memberUid: String,
        questions: List<VideoQuestion>,
    ) {
        val retained = allQuestions().filter {
            it.communityId != communityId || it.memberUid != memberUid
        }
        write(retained + questions)
    }

    private fun allQuestions(): List<VideoQuestion> {
        val raw = preferences.getString(STORAGE_KEY, "[]") ?: "[]"
        val payload = runCatching { JSONArray(raw) }.getOrNull() ?: return emptyList()
        return buildList {
            for (index in 0 until payload.length()) {
                val item = payload.optJSONObject(index) ?: continue
                add(
                    VideoQuestion(
                        id = item.optString("id"),
                        communityId = item.optString("communityId"),
                        memberUid = item.optString("memberUid"),
                        videoId = item.optString("videoId"),
                        videoTitle = item.optString("videoTitle"),
                        playbackSeconds = item.optDouble("playbackSeconds", 0.0),
                        memoText = item.optString("memoText"),
                        questionText = item.optString("questionText"),
                        answerText = item.optString("answerText"),
                        createdAt = item.optString("createdAt").takeIf { it.isNotBlank() },
                        answeredAt = item.optString("answeredAt").takeIf { it.isNotBlank() },
                        syncStatus = VideoQuestionSyncStatus.fromValue(item.optString("syncStatus")),
                        clientRequestId = item.optString("clientRequestId"),
                    ),
                )
            }
        }
    }

    private fun write(questions: List<VideoQuestion>) {
        val payload = JSONArray()
        questions.forEach { question ->
            payload.put(
                JSONObject()
                    .put("id", question.id)
                    .put("communityId", question.communityId)
                    .put("memberUid", question.memberUid)
                    .put("videoId", question.videoId)
                    .put("videoTitle", question.videoTitle)
                    .put("playbackSeconds", question.playbackSeconds)
                    .put("memoText", question.memoText)
                    .put("questionText", question.questionText)
                    .put("answerText", question.answerText)
                    .put("createdAt", question.createdAt ?: "")
                    .put("answeredAt", question.answeredAt ?: "")
                    .put("syncStatus", question.syncStatus.rawValue())
                    .put("clientRequestId", question.clientRequestId),
            )
        }
        preferences.edit().putString(STORAGE_KEY, payload.toString()).apply()
    }

    private fun identity(question: VideoQuestion): String =
        question.clientRequestId.ifBlank { question.id }

    private companion object {
        const val STORAGE_KEY = "questions"
    }
}

internal class InMemoryVideoQuestionStore : VideoQuestionStoreProtocol {
    private val values = mutableListOf<VideoQuestion>()

    override fun questions(communityId: String, memberUid: String): List<VideoQuestion> =
        values.filter { it.communityId == communityId && it.memberUid == memberUid }
            .sortedByDescending { it.createdAt.orEmpty() }

    override fun pendingQuestions(communityId: String, memberUid: String): List<VideoQuestion> =
        questions(communityId, memberUid).filter { it.syncStatus.requiresSync }

    override fun save(question: VideoQuestion) {
        val identity = question.clientRequestId.ifBlank { question.id }
        val index = values.indexOfFirst { it.clientRequestId.ifBlank { it.id } == identity }
        if (index >= 0) values[index] = question else values += question
    }

    override fun replaceQuestions(
        communityId: String,
        memberUid: String,
        questions: List<VideoQuestion>,
    ) {
        values.removeAll { it.communityId == communityId && it.memberUid == memberUid }
        values += questions
    }
}
