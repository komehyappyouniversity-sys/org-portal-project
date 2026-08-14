package jp.komehyappyo.member.next.core.data

import androidx.room.withTransaction
import jp.komehyappyo.member.next.core.model.BudgetEntry
import jp.komehyappyo.member.next.core.model.BudgetEntryType
import jp.komehyappyo.member.next.core.model.BudgetSettlementReport
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

interface BudgetSettlementRepository {
    fun observeReports(): Flow<List<BudgetSettlementReport>>
    fun observeEntries(reportId: UUID): Flow<List<BudgetEntry>>
    suspend fun saveReport(report: BudgetSettlementReport)
    suspend fun saveEntry(entry: BudgetEntry)
    suspend fun deleteEntry(id: UUID)
    suspend fun deleteReport(id: UUID)
}

class RoomBudgetSettlementRepository(
    private val database: OrgPortalDatabase,
    private val deleteReceipt: suspend (String) -> Unit = {},
) : BudgetSettlementRepository {
    private val dao = database.budgetSettlementDao()

    override fun observeReports(): Flow<List<BudgetSettlementReport>> =
        dao.observeReports().map { reports -> reports.map(BudgetSettlementReportEntity::toDomain) }

    override fun observeEntries(reportId: UUID): Flow<List<BudgetEntry>> =
        dao.observeEntries(reportId.toString()).map { entries -> entries.map(BudgetEntryEntity::toDomain) }

    override suspend fun saveReport(report: BudgetSettlementReport) {
        database.withTransaction {
            val existingEntries = dao.findEntries(report.id.toString()).map(BudgetEntryEntity::toDomain)
            val validated = report.validated(now = report.updatedAt)
                .recalculated(existingEntries, now = report.updatedAt)
            dao.upsertReport(validated.toEntity())
        }
    }

    override suspend fun saveEntry(entry: BudgetEntry) {
        database.withTransaction {
            val validated = entry.validated(now = entry.updatedAt)
            checkNotNull(dao.findReport(entry.reportId.toString())) { "帳簿が見つかりません。" }
            dao.upsertEntry(validated.toEntity())
            recalculate(entry.reportId)
        }
    }

    override suspend fun deleteEntry(id: UUID) {
        var receiptToDelete: String? = null
        database.withTransaction {
            val existing = dao.findEntry(id.toString()) ?: return@withTransaction
            receiptToDelete = existing.receiptImageUrl
            dao.deleteEntry(id.toString())
            recalculate(UUID.fromString(existing.reportId))
        }
        receiptToDelete?.let { deleteReceipt(it) }
    }

    override suspend fun deleteReport(id: UUID) {
        val receipts = database.withTransaction {
            val values = dao.findEntries(id.toString()).mapNotNull { it.receiptImageUrl }
            dao.deleteEntries(id.toString())
            dao.deleteReport(id.toString())
            values
        }
        receipts.forEach { deleteReceipt(it) }
    }

    private suspend fun recalculate(reportId: UUID) {
        val report = dao.findReport(reportId.toString())?.toDomain() ?: return
        val entries = dao.findEntries(reportId.toString()).map(BudgetEntryEntity::toDomain)
        dao.upsertReport(report.recalculated(entries, now = Instant.now()).toEntity())
    }
}

private fun BudgetSettlementReport.toEntity() = BudgetSettlementReportEntity(
    id = id.toString(),
    userId = userId,
    fiscalYearStartEpochDay = fiscalYearStart.toEpochDay(),
    fiscalYearEndEpochDay = fiscalYearEnd.toEpochDay(),
    bookName = bookName,
    incomeTotalDecimal = incomeTotal.toPlainString(),
    expenseTotalDecimal = expenseTotal.toPlainString(),
    balanceDecimal = balance.toPlainString(),
    createdAtEpochMillis = createdAt.toEpochMilli(),
    updatedAtEpochMillis = updatedAt.toEpochMilli(),
)

private fun BudgetSettlementReportEntity.toDomain() = BudgetSettlementReport(
    id = UUID.fromString(id),
    userId = userId,
    fiscalYearStart = LocalDate.ofEpochDay(fiscalYearStartEpochDay),
    fiscalYearEnd = LocalDate.ofEpochDay(fiscalYearEndEpochDay),
    bookName = bookName,
    incomeTotal = BigDecimal(incomeTotalDecimal),
    expenseTotal = BigDecimal(expenseTotalDecimal),
    balance = BigDecimal(balanceDecimal),
    createdAt = Instant.ofEpochMilli(createdAtEpochMillis),
    updatedAt = Instant.ofEpochMilli(updatedAtEpochMillis),
)

private fun BudgetEntry.toEntity() = BudgetEntryEntity(
    id = id.toString(),
    reportId = reportId.toString(),
    dateEpochDay = date.toEpochDay(),
    entryType = entryType.wireValue,
    accountItem = accountItem,
    detail = detail,
    amountDecimal = amount.toPlainString(),
    receiptType = receiptType,
    receiptImageUrl = receiptImageUrl,
    createdAtEpochMillis = createdAt.toEpochMilli(),
    updatedAtEpochMillis = updatedAt.toEpochMilli(),
)

private fun BudgetEntryEntity.toDomain() = BudgetEntry(
    id = UUID.fromString(id),
    reportId = UUID.fromString(reportId),
    date = LocalDate.ofEpochDay(dateEpochDay),
    entryType = BudgetEntryType.fromWireValue(entryType) ?: BudgetEntryType.Expense,
    accountItem = accountItem,
    detail = detail,
    amount = BigDecimal(amountDecimal),
    receiptType = receiptType,
    receiptImageUrl = receiptImageUrl,
    createdAt = Instant.ofEpochMilli(createdAtEpochMillis),
    updatedAt = Instant.ofEpochMilli(updatedAtEpochMillis),
)
