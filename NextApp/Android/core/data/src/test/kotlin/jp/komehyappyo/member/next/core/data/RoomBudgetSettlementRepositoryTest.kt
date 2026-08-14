package jp.komehyappyo.member.next.core.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import jp.komehyappyo.member.next.core.model.BudgetEntry
import jp.komehyappyo.member.next.core.model.BudgetEntryType
import jp.komehyappyo.member.next.core.model.BudgetSettlementReport
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.math.BigDecimal
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue

@RunWith(RobolectricTestRunner::class)
class RoomBudgetSettlementRepositoryTest {
    private lateinit var database: OrgPortalDatabase
    private lateinit var repository: RoomBudgetSettlementRepository
    private val deletedReceipts = mutableListOf<String>()

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext<Context>(),
            OrgPortalDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = RoomBudgetSettlementRepository(database) { deletedReceipts += it }
    }

    @After
    fun tearDown() = database.close()

    @Test
    fun savesFetchesAndRecalculatesWhenEntriesChange() = runTest {
        val report = BudgetSettlementReport(
            userId = "guest",
            fiscalYearStart = LocalDate.of(2025, 4, 1),
            fiscalYearEnd = LocalDate.of(2026, 3, 31),
            bookName = "家計簿",
        )
        repository.saveReport(report)
        val income = BudgetEntry(
            reportId = report.id,
            date = LocalDate.of(2025, 4, 2),
            entryType = BudgetEntryType.Income,
            accountItem = "給与",
            amount = BigDecimal("1000.50"),
        )
        val expense = BudgetEntry(
            reportId = report.id,
            date = LocalDate.of(2025, 4, 3),
            entryType = BudgetEntryType.Expense,
            accountItem = "消耗品",
            amount = BigDecimal("200.25"),
            receiptImageUrl = "receipts/expense.jpg",
        )

        repository.saveEntry(income)
        repository.saveEntry(expense)

        val savedReport = repository.observeReports().first().single()
        assertEquals(BigDecimal("1000.5"), savedReport.incomeTotal)
        assertEquals(BigDecimal("200.25"), savedReport.expenseTotal)
        assertEquals(BigDecimal("800.25"), savedReport.balance)
        assertEquals(listOf(expense, income).map { it.id }, repository.observeEntries(report.id).first().map { it.id })

        repository.deleteEntry(expense.id)

        val afterDelete = repository.observeReports().first().single()
        assertEquals(BigDecimal.ZERO, afterDelete.expenseTotal)
        assertEquals(BigDecimal("1000.5"), afterDelete.balance)
        assertEquals(listOf("receipts/expense.jpg"), deletedReceipts)
    }

    @Test
    fun deletingReportCascadesEntriesAndReceipts() = runTest {
        val report = BudgetSettlementReport(
            userId = "guest",
            fiscalYearStart = LocalDate.of(2025, 4, 1),
            fiscalYearEnd = LocalDate.of(2026, 3, 31),
            bookName = "家計簿",
        )
        repository.saveReport(report)
        repository.saveEntry(
            BudgetEntry(
                reportId = report.id,
                date = LocalDate.of(2025, 4, 2),
                entryType = BudgetEntryType.Expense,
                accountItem = "交通費",
                amount = BigDecimal("500"),
                receiptImageUrl = "receipts/train.jpg",
            ),
        )

        repository.deleteReport(report.id)

        assertTrue(repository.observeReports().first().isEmpty())
        assertTrue(repository.observeEntries(report.id).first().isEmpty())
        assertEquals(listOf("receipts/train.jpg"), deletedReceipts)
    }
}
