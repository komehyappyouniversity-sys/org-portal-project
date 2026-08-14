package jp.komehyappyo.member.next.core.model

import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

enum class BudgetEntryType(val wireValue: String) {
    Income("income"),
    Expense("expense"),
    ;

    companion object {
        fun fromWireValue(value: String): BudgetEntryType? = entries.firstOrNull {
            it.wireValue == value
        }
    }
}

data class BudgetEntry(
    val id: UUID = UUID.randomUUID(),
    val reportId: UUID,
    val date: LocalDate,
    val entryType: BudgetEntryType,
    val accountItem: String,
    val detail: String = "",
    val amount: BigDecimal,
    val receiptType: String = "",
    val receiptImageUrl: String? = null,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validated(now: Instant = Instant.now()): BudgetEntry {
        val normalizedAmount = amount.stripTrailingZeros()
        require(accountItem.trim().isNotEmpty()) { "科目を入力してください。" }
        require(normalizedAmount > BigDecimal.ZERO) { "金額は0より大きい値を入力してください。" }
        return copy(
            accountItem = accountItem.trim(),
            detail = detail.trim(),
            amount = normalizedAmount,
            receiptType = receiptType.trim(),
            receiptImageUrl = receiptImageUrl?.trim()?.takeIf(String::isNotEmpty),
            updatedAt = now,
        )
    }
}

data class BudgetSettlementReport(
    val id: UUID = UUID.randomUUID(),
    val userId: String,
    val fiscalYearStart: LocalDate,
    val fiscalYearEnd: LocalDate,
    val bookName: String,
    val incomeTotal: BigDecimal = BigDecimal.ZERO,
    val expenseTotal: BigDecimal = BigDecimal.ZERO,
    val balance: BigDecimal = BigDecimal.ZERO,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validated(now: Instant = Instant.now()): BudgetSettlementReport {
        require(userId.isNotBlank()) { "利用者IDが必要です。" }
        require(bookName.trim().isNotEmpty()) { "帳簿名を入力してください。" }
        require(!fiscalYearEnd.isBefore(fiscalYearStart)) {
            "会計年度の終了日は開始日以降にしてください。"
        }
        return copy(bookName = bookName.trim(), updatedAt = now)
    }

    fun recalculated(
        entries: Collection<BudgetEntry>,
        now: Instant = updatedAt,
    ): BudgetSettlementReport {
        require(entries.all { it.reportId == id }) { "別の帳簿の明細は集計できません。" }
        val income = entries.asSequence()
            .filter { it.entryType == BudgetEntryType.Income }
            .fold(BigDecimal.ZERO) { total, entry -> total + entry.amount }
        val expense = entries.asSequence()
            .filter { it.entryType == BudgetEntryType.Expense }
            .fold(BigDecimal.ZERO) { total, entry -> total + entry.amount }
        return copy(
            incomeTotal = income.normalized(),
            expenseTotal = expense.normalized(),
            balance = (income - expense).normalized(),
            updatedAt = now,
        )
    }
}

private fun BigDecimal.normalized(): BigDecimal {
    if (compareTo(BigDecimal.ZERO) == 0) return BigDecimal.ZERO
    // stripTrailingZeros() can push round numbers (e.g. 1300) into a negative
    // scale, which renders in scientific notation (1.3E+3) instead of 1300.
    val stripped = stripTrailingZeros()
    return if (stripped.scale() < 0) stripped.setScale(0) else stripped
}
