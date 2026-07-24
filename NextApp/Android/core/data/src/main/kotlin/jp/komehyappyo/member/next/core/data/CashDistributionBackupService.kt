package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.CashDistribution
import jp.komehyappyo.member.next.core.model.CashDistributionEntry
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

class CashDistributionBackupService(
    private val repository: CashDistributionRepository,
) {
    suspend fun exportData(now: Instant = Instant.now()): ByteArray {
        val items = JSONArray()
        repository.observeAll().first().forEach { items.put(it.toJson()) }
        return JSONObject()
            .put("format", FORMAT_IDENTIFIER)
            .put("version", CURRENT_VERSION)
            .put("exportedAtEpochMillis", now.toEpochMilli())
            .put("distributions", items)
            .toString(2)
            .toByteArray(Charsets.UTF_8)
    }

    suspend fun importData(data: ByteArray): Int {
        val root = runCatching { JSONObject(data.toString(Charsets.UTF_8)) }
            .getOrElse { throw CashDistributionBackupException.InvalidFormat }
        if (root.optString("format") != FORMAT_IDENTIFIER) {
            throw CashDistributionBackupException.InvalidFormat
        }
        if (root.optInt("version") != CURRENT_VERSION) {
            throw CashDistributionBackupException.UnsupportedVersion
        }
        val items = root.optJSONArray("distributions")
            ?: throw CashDistributionBackupException.InvalidFormat
        for (index in 0 until items.length()) {
            val distribution = runCatching {
                items.getJSONObject(index).toCashDistribution().validated(
                    now = Instant.ofEpochMilli(
                        items.getJSONObject(index).getLong("updatedAtEpochMillis"),
                    ),
                )
            }.getOrElse { throw CashDistributionBackupException.InvalidFormat }
            repository.save(distribution)
        }
        return items.length()
    }

    companion object {
        const val FORMAT_IDENTIFIER = "org-portal-cash-distribution-backup"
        const val CURRENT_VERSION = 1
    }
}

sealed class CashDistributionBackupException : Exception() {
    data object InvalidFormat : CashDistributionBackupException()
    data object UnsupportedVersion : CashDistributionBackupException()
}

internal fun CashDistribution.toJson(): JSONObject = JSONObject()
    .put("id", id.toString())
    .put("userId", userId)
    .put("distributionDateEpochMillis", distributionDate.toEpochMilli())
    .put("title", title)
    .put("entries", JSONArray().also { array -> entries.forEach { array.put(it.toJson()) } })
    .put("createdAtEpochMillis", createdAt.toEpochMilli())
    .put("updatedAtEpochMillis", updatedAt.toEpochMilli())

internal fun JSONObject.toCashDistribution(): CashDistribution = CashDistribution(
    id = UUID.fromString(getString("id")),
    userId = optString("userId", "guest"),
    distributionDate = Instant.ofEpochMilli(getLong("distributionDateEpochMillis")),
    title = getString("title"),
    entries = getJSONArray("entries").let { array ->
        (0 until array.length()).map { array.getJSONObject(it).toCashDistributionEntry() }
    },
    createdAt = Instant.ofEpochMilli(getLong("createdAtEpochMillis")),
    updatedAt = Instant.ofEpochMilli(getLong("updatedAtEpochMillis")),
)

private fun CashDistributionEntry.toJson(): JSONObject = JSONObject()
    .put("id", id.toString())
    .put("recipientName1", recipientName1)
    .put("amount1", amount1)
    .put("recipientName2", recipientName2)
    .put("amount2", amount2)
    .put("recipientName3", recipientName3)
    .put("amount3", amount3)
    .put("receivedDateEpochMillis", receivedDate?.toEpochMilli() ?: JSONObject.NULL)
    .put("receiverName", receiverName)

private fun JSONObject.toCashDistributionEntry() = CashDistributionEntry(
    id = UUID.fromString(getString("id")),
    recipientName1 = optString("recipientName1"),
    amount1 = getLong("amount1"),
    recipientName2 = optString("recipientName2"),
    amount2 = getLong("amount2"),
    recipientName3 = optString("recipientName3"),
    amount3 = getLong("amount3"),
    receivedDate = if (isNull("receivedDateEpochMillis")) {
        null
    } else {
        Instant.ofEpochMilli(getLong("receivedDateEpochMillis"))
    },
    receiverName = optString("receiverName"),
)
