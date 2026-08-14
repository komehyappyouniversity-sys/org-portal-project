package jp.komehyappyo.member.next.core.model

import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class BudgetSettlementTest {
    @Test
    fun recalculatesIncomeExpenseAndBalanceFromEntries() {
        val report = report()
        val entries = listOf(
            entry(report.id, BudgetEntryType.Income, "1250.50"),
            entry(report.id, BudgetEntryType.Income, "49.50"),
            entry(report.id, BudgetEntryType.Expense, "325.25"),
        )

        val recalculated = report.recalculated(entries)

        assertEquals(BigDecimal("1300"), recalculated.incomeTotal)
        assertEquals(BigDecimal("325.25"), recalculated.expenseTotal)
        assertEquals(BigDecimal("974.75"), recalculated.balance)
    }

    @Test
    fun recalculationReturnsZeroTotalsAfterAllEntriesAreRemoved() {
        val report = report().copy(
            incomeTotal = BigDecimal.TEN,
            expenseTotal = BigDecimal.ONE,
            balance = BigDecimal("9"),
        )

        assertEquals(BigDecimal.ZERO, report.recalculated(emptyList()).incomeTotal)
        assertEquals(BigDecimal.ZERO, report.recalculated(emptyList()).expenseTotal)
        assertEquals(BigDecimal.ZERO, report.recalculated(emptyList()).balance)
    }

    @Test
    fun rejectsInvalidReportAndEntryInput() {
        assertFailsWith<IllegalArgumentException> { report().copy(bookName = " ").validated() }
        assertFailsWith<IllegalArgumentException> {
            report().copy(fiscalYearEnd = LocalDate.of(2025, 3, 31)).validated()
        }
        assertFailsWith<IllegalArgumentException> {
            entry(report().id, BudgetEntryType.Expense, "-1").validated()
        }
        assertFailsWith<IllegalArgumentException> {
            entry(report().id, BudgetEntryType.Expense, "10").copy(accountItem = "").validated()
        }
    }

    private fun report() = BudgetSettlementReport(
        userId = "guest",
        fiscalYearStart = LocalDate.of(2025, 4, 1),
        fiscalYearEnd = LocalDate.of(2026, 3, 31),
        bookName = "個人帳簿",
        createdAt = Instant.EPOCH,
        updatedAt = Instant.EPOCH,
    )

    private fun entry(reportId: UUID, type: BudgetEntryType, amount: String) = BudgetEntry(
        reportId = reportId,
        date = LocalDate.of(2025, 4, 1),
        entryType = type,
        accountItem = "科目",
        amount = BigDecimal(amount),
        createdAt = Instant.EPOCH,
        updatedAt = Instant.EPOCH,
    )
}
