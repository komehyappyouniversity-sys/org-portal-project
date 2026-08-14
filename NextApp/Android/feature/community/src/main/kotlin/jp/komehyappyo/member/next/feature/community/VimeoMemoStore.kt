package jp.komehyappyo.member.next.feature.community

import android.content.Context
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
        return read().let { values ->
            buildMap {
                values.keys().forEach { key ->
                    put(key, entries(fromRaw = values.optString(key, "")))
                }
            }
        }
    }

    override fun pendingEntries(): Map<String, List<VimeoVideoMemo>> =
        allEntries().mapValues { it.value.filter {
            it.syncStatus == jp.komehyappyo.member.next.core.model.VimeoVideoMemoSyncStatus.PendingSync
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
                createdAtMillis = 0,
                updatedAtMillis = 0,
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
        val serialized = serialized(entries)
        if (serialized.isEmpty()) {
            values.remove(key(communityId, videoId))
        } else {
            values.put(key(communityId, videoId), serialized)
        }
        preferences.edit().putString(STORAGE_KEY, values.toString()).apply()
    }

    override fun saveAll(memos: Map<String, String>) {
        val values = JSONObject()
        memos.forEach { (key, value) -> values.put(key, value) }
        preferences.edit().putString(STORAGE_KEY, values.toString()).apply()
    }

    private fun read(): JSONObject = runCatching {
        JSONObject(preferences.getString(STORAGE_KEY, "{}") ?: "{}")
    }.getOrDefault(JSONObject())

    private fun key(communityId: String, videoId: String) = "$communityId:$videoId"

    private companion object {
        const val STORAGE_KEY = "memo_values"
    }
}
