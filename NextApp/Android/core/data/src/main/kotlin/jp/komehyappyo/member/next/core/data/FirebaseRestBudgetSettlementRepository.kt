package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.BudgetEntry
import jp.komehyappyo.member.next.core.model.BudgetEntryType
import jp.komehyappyo.member.next.core.model.BudgetSettlementReport
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

data class BudgetRemoteAuth(val userId: String, val idToken: String)

interface BudgetSettlementRemoteRepository {
    suspend fun fetchReports(auth: BudgetRemoteAuth): List<BudgetSettlementReport>
    suspend fun fetchEntries(auth: BudgetRemoteAuth, reportId: UUID): List<BudgetEntry>
    suspend fun saveReport(auth: BudgetRemoteAuth, report: BudgetSettlementReport)
    suspend fun saveEntry(auth: BudgetRemoteAuth, entry: BudgetEntry)
    suspend fun deleteEntry(auth: BudgetRemoteAuth, reportId: UUID, entryId: UUID)
    suspend fun deleteReport(auth: BudgetRemoteAuth, reportId: UUID)
    suspend fun uploadReceipt(
        auth: BudgetRemoteAuth,
        reportId: UUID,
        entryId: UUID,
        jpegData: ByteArray,
    ): String
}

class FirebaseRestBudgetSettlementRepository(
    private val projectId: String,
    private val storageBucket: String,
) : BudgetSettlementRemoteRepository {
    private val firestoreRoot =
        "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents"

    override suspend fun fetchReports(auth: BudgetRemoteAuth): List<BudgetSettlementReport> {
        return fetchDocuments(reportsPath(auth.userId), auth.idToken).mapNotNull { document ->
            runCatching { document.toReport() }.getOrNull()
        }
    }

    override suspend fun fetchEntries(
        auth: BudgetRemoteAuth,
        reportId: UUID,
    ): List<BudgetEntry> {
        return fetchDocuments(entriesPath(auth.userId, reportId), auth.idToken).mapNotNull { document ->
            runCatching { document.toEntry(reportId) }.getOrNull()
        }.sortedWith(compareByDescending<BudgetEntry> { it.date }.thenByDescending { it.updatedAt })
    }

    override suspend fun saveReport(
        auth: BudgetRemoteAuth,
        report: BudgetSettlementReport,
    ) {
        require(report.userId == auth.userId) { "本人以外の帳簿は保存できません。" }
        val entries = fetchEntries(auth, report.id)
        val value = report.validated(now = report.updatedAt)
            .recalculated(entries, now = report.updatedAt)
        requestJson(
            "PATCH",
            "${reportsPath(auth.userId)}/${value.id}",
            auth.idToken,
            value.toFirestoreDocument(),
        )
    }

    override suspend fun saveEntry(auth: BudgetRemoteAuth, entry: BudgetEntry) {
        val validated = entry.validated(now = entry.updatedAt)
        requestJson(
            "PATCH",
            "${entriesPath(auth.userId, entry.reportId)}/${entry.id}",
            auth.idToken,
            validated.toFirestoreDocument(),
        )
        val report = fetchReports(auth).firstOrNull { it.id == entry.reportId }
            ?: error("帳簿が見つかりません。")
        saveReport(auth, report.copy(updatedAt = Instant.now()))
    }

    override suspend fun deleteEntry(
        auth: BudgetRemoteAuth,
        reportId: UUID,
        entryId: UUID,
    ) {
        requestJson(
            "DELETE",
            "${entriesPath(auth.userId, reportId)}/$entryId",
            auth.idToken,
        )
        deleteStorageObject(auth, reportId, entryId)
        fetchReports(auth).firstOrNull { it.id == reportId }?.let {
            saveReport(auth, it.copy(updatedAt = Instant.now()))
        }
    }

    override suspend fun deleteReport(auth: BudgetRemoteAuth, reportId: UUID) {
        fetchEntries(auth, reportId).forEach { entry ->
            requestJson(
                "DELETE",
                "${entriesPath(auth.userId, reportId)}/${entry.id}",
                auth.idToken,
            )
            deleteStorageObject(auth, reportId, entry.id)
        }
        requestJson(
            "DELETE",
            "${reportsPath(auth.userId)}/$reportId",
            auth.idToken,
        )
    }

    override suspend fun uploadReceipt(
        auth: BudgetRemoteAuth,
        reportId: UUID,
        entryId: UUID,
        jpegData: ByteArray,
    ): String = withContext(Dispatchers.IO) {
        require(jpegData.isNotEmpty()) { "領収書画像が空です。" }
        val objectPath = storageObjectPath(auth.userId, reportId, entryId)
        val encodedName = URLEncoder.encode(objectPath, StandardCharsets.UTF_8).replace("+", "%20")
        val url = URI(
            "https://firebasestorage.googleapis.com/v0/b/$storageBucket/o" +
                "?uploadType=media&name=$encodedName",
        ).toURL()
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            setRequestProperty("Authorization", "Bearer ${auth.idToken}")
            setRequestProperty("Content-Type", "image/jpeg")
            doOutput = true
        }
        connection.outputStream.use { it.write(jpegData) }
        connection.requireSuccess()
        "gs://$storageBucket/$objectPath"
    }

    private suspend fun deleteStorageObject(
        auth: BudgetRemoteAuth,
        reportId: UUID,
        entryId: UUID,
    ) = withContext(Dispatchers.IO) {
        val encodedName = URLEncoder.encode(
            storageObjectPath(auth.userId, reportId, entryId),
            StandardCharsets.UTF_8,
        ).replace("+", "%20")
        val connection = (
            URI("https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/$encodedName")
                .toURL().openConnection() as HttpURLConnection
            ).apply {
            requestMethod = "DELETE"
            setRequestProperty("Authorization", "Bearer ${auth.idToken}")
        }
        if (connection.responseCode !in listOf(200, 204, 404)) {
            connection.requireSuccess()
        }
    }

    private suspend fun requestJson(
        method: String,
        path: String,
        token: String,
        body: JSONObject? = null,
    ): JSONObject = withContext(Dispatchers.IO) {
        val connection = (URI("$firestoreRoot/$path").toURL().openConnection() as HttpURLConnection)
            .apply {
                requestMethod = method
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                if (body != null) {
                    doOutput = true
                    outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                }
            }
        val code = connection.responseCode
        if (method == "GET" && code == 404) return@withContext JSONObject()
        connection.requireSuccess()
        val response = connection.inputStream.bufferedReader().use { it.readText() }
        if (response.isBlank()) JSONObject() else JSONObject(response)
    }

    private suspend fun fetchDocuments(path: String, token: String): List<JSONObject> {
        val documents = mutableListOf<JSONObject>()
        var pageToken: String? = null
        do {
            val encodedToken = pageToken?.let {
                "&pageToken=${URLEncoder.encode(it, StandardCharsets.UTF_8)}"
            }.orEmpty()
            val page = requestJson("GET", "$path?pageSize=100$encodedToken", token)
            documents += page.optJSONArray("documents").objects()
            pageToken = page.optString("nextPageToken").takeIf(String::isNotBlank)
        } while (pageToken != null)
        return documents
    }

    private fun reportsPath(userId: String) =
        "memberPrivate/$userId/budgetSettlementReports"

    private fun entriesPath(userId: String, reportId: UUID) =
        "${reportsPath(userId)}/$reportId/entries"

    private fun storageObjectPath(userId: String, reportId: UUID, entryId: UUID) =
        "memberPrivate/$userId/budgetSettlementReports/$reportId/$entryId.jpg"
}

class BudgetSettlementMigrationService(
    private val localRepository: BudgetSettlementRepository,
    private val localReceiptStore: BudgetReceiptStore,
    private val remoteRepository: BudgetSettlementRemoteRepository,
    private val stateStore: BudgetMigrationStateStore,
) {
    suspend fun candidateCount(auth: BudgetRemoteAuth): Int =
        if (stateStore.isCompleted(auth.userId)) 0 else localRepository.observeReports().first().size

    suspend fun migrate(auth: BudgetRemoteAuth): BudgetMigrationResult {
        val reports = kotlinx.coroutines.flow.first(localRepository.observeReports())
        var migratedEntries = 0
        for (report in reports) {
            val entries = kotlinx.coroutines.flow.first(localRepository.observeEntries(report.id))
            remoteRepository.saveReport(auth, report.copy(userId = auth.userId))
            for (entry in entries) {
                val remoteReceipt = entry.receiptImageUrl?.let { localReference ->
                    remoteRepository.uploadReceipt(
                        auth,
                        report.id,
                        entry.id,
                        localReceiptStore.load(localReference),
                    )
                }
                remoteRepository.saveEntry(auth, entry.copy(receiptImageUrl = remoteReceipt))
                migratedEntries += 1
            }
        }
        val remoteIds = remoteRepository.fetchReports(auth).map { it.id }.toSet()
        check(reports.all { it.id in remoteIds }) { "Firebaseへの移行確認に失敗しました。" }
        stateStore.markCompleted(auth.userId)
        return BudgetMigrationResult(reports.size, migratedEntries)
    }
}

data class BudgetMigrationResult(val reportCount: Int, val entryCount: Int)

interface BudgetMigrationStateStore {
    suspend fun isCompleted(userId: String): Boolean
    suspend fun markCompleted(userId: String)
}

private val Context.budgetMigrationDataStore by preferencesDataStore(
    name = "budget_settlement_migration",
)

class DataStoreBudgetMigrationStateStore(
    private val context: Context,
) : BudgetMigrationStateStore {
    override suspend fun isCompleted(userId: String): Boolean =
        context.budgetMigrationDataStore.data.first()[key(userId)] ?: false

    override suspend fun markCompleted(userId: String) {
        context.budgetMigrationDataStore.edit { values -> values[key(userId)] = true }
    }

    private fun key(userId: String) = booleanPreferencesKey("completed_$userId")
}

private fun BudgetSettlementReport.toFirestoreDocument() = JSONObject().put(
    "fields",
    JSONObject()
        .field("userId", "stringValue", userId)
        .field("fiscalYearStart", "stringValue", fiscalYearStart.toString())
        .field("fiscalYearEnd", "stringValue", fiscalYearEnd.toString())
        .field("bookName", "stringValue", bookName)
        .field("incomeTotal", "doubleValue", incomeTotal.toDouble())
        .field("expenseTotal", "doubleValue", expenseTotal.toDouble())
        .field("balance", "doubleValue", balance.toDouble())
        .field("createdAt", "timestampValue", createdAt.toString())
        .field("updatedAt", "timestampValue", updatedAt.toString()),
)

private fun BudgetEntry.toFirestoreDocument() = JSONObject().put(
    "fields",
    JSONObject()
        .field("reportId", "stringValue", reportId.toString())
        .field("date", "stringValue", date.toString())
        .field("entryType", "stringValue", entryType.wireValue)
        .field("accountItem", "stringValue", accountItem)
        .field("detail", "stringValue", detail)
        .field("amount", "doubleValue", amount.toDouble())
        .field("receiptType", "stringValue", receiptType)
        .field("receiptImageUrl", "stringValue", receiptImageUrl.orEmpty())
        .field("createdAt", "timestampValue", createdAt.toString())
        .field("updatedAt", "timestampValue", updatedAt.toString()),
)

private fun JSONObject.toReport(): BudgetSettlementReport {
    val fields = getJSONObject("fields")
    return BudgetSettlementReport(
        id = UUID.fromString(getString("name").substringAfterLast('/')),
        userId = fields.value("userId"),
        fiscalYearStart = LocalDate.parse(fields.value("fiscalYearStart")),
        fiscalYearEnd = LocalDate.parse(fields.value("fiscalYearEnd")),
        bookName = fields.value("bookName"),
        incomeTotal = fields.decimal("incomeTotal"),
        expenseTotal = fields.decimal("expenseTotal"),
        balance = fields.decimal("balance"),
        createdAt = Instant.parse(fields.value("createdAt")),
        updatedAt = Instant.parse(fields.value("updatedAt")),
    )
}

private fun JSONObject.toEntry(reportId: UUID): BudgetEntry {
    val fields = getJSONObject("fields")
    return BudgetEntry(
        id = UUID.fromString(getString("name").substringAfterLast('/')),
        reportId = reportId,
        date = LocalDate.parse(fields.value("date")),
        entryType = BudgetEntryType.fromWireValue(fields.value("entryType"))
            ?: BudgetEntryType.Expense,
        accountItem = fields.value("accountItem"),
        detail = fields.value("detail"),
        amount = fields.decimal("amount"),
        receiptType = fields.value("receiptType"),
        receiptImageUrl = fields.value("receiptImageUrl").takeIf(String::isNotBlank),
        createdAt = Instant.parse(fields.value("createdAt")),
        updatedAt = Instant.parse(fields.value("updatedAt")),
    )
}

private fun JSONObject.field(name: String, type: String, value: Any): JSONObject =
    put(name, JSONObject().put(type, value))

private fun JSONObject.value(name: String): String {
    val value = getJSONObject(name)
    return when {
        value.has("stringValue") -> value.getString("stringValue")
        value.has("timestampValue") -> value.getString("timestampValue")
        value.has("doubleValue") -> value.get("doubleValue").toString()
        value.has("integerValue") -> value.get("integerValue").toString()
        else -> ""
    }
}

private fun JSONObject.decimal(name: String) = java.math.BigDecimal(value(name))

private fun JSONArray?.objects(): List<JSONObject> =
    if (this == null) emptyList() else (0 until length()).map { getJSONObject(it) }

private fun HttpURLConnection.requireSuccess() {
    if (responseCode !in 200..299) {
        val error = errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
        throw IllegalStateException("Firebase request failed ($responseCode): $error")
    }
}
