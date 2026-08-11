package jp.komehyappyo.member.next.feature.community

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class VimeoVideoMemo(
    val id: String,
    val text: String,
    val playbackSeconds: Double,
    val createdAtMillis: Long,
    val updatedAtMillis: Long,
)

class VimeoMemoStore(context: Context) {
    private val preferences = context.getSharedPreferences(
        "vimeo_video_memos",
        Context.MODE_PRIVATE,
    )

    fun entries(communityId: String, videoId: String): List<VimeoVideoMemo> {
        val stored = read().optString(key(communityId, videoId), "")
        if (stored.isBlank()) return emptyList()
        val entries = runCatching {
            val array = JSONArray(stored)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    add(
                        VimeoVideoMemo(
                            id = item.optString("id"),
                            text = item.optString("text"),
                            playbackSeconds = item.optDouble("playbackSeconds", 0.0),
                            createdAtMillis = item.optLong("createdAtMillis", 0),
                            updatedAtMillis = item.optLong("updatedAtMillis", 0),
                        ),
                    )
                }
            }
        }.getOrNull()
        return entries?.sortedByDescending { it.createdAtMillis }
            ?: listOf(VimeoVideoMemo("legacy", stored, 0.0, 0, 0))
    }

    fun serialized(entries: List<VimeoVideoMemo>): String {
        if (entries.isEmpty()) return ""
        return JSONArray().apply {
            entries.forEach { entry ->
                put(
                    JSONObject()
                        .put("id", entry.id)
                        .put("text", entry.text)
                        .put("playbackSeconds", entry.playbackSeconds)
                        .put("createdAtMillis", entry.createdAtMillis)
                        .put("updatedAtMillis", entry.updatedAtMillis),
                )
            }
        }.toString()
    }

    fun save(communityId: String, videoId: String, entries: List<VimeoVideoMemo>) {
        val values = read()
        val serialized = serialized(entries)
        if (serialized.isEmpty()) {
            values.remove(key(communityId, videoId))
        } else {
            values.put(key(communityId, videoId), serialized)
        }
        preferences.edit().putString(STORAGE_KEY, values.toString()).apply()
    }

    fun saveAll(memos: Map<String, String>) {
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
