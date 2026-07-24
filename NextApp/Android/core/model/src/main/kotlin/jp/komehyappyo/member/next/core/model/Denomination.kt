package jp.komehyappyo.member.next.core.model

import java.time.Instant
import java.util.UUID

enum class Denomination(
    val yenValue: Long,
    val isCoin: Boolean,
) {
    One(1, true),
    Five(5, true),
    Ten(10, true),
    Fifty(50, true),
    OneHundred(100, true),
    FiveHundred(500, true),
    OneThousand(1_000, false),
    TwoThousand(2_000, false),
    FiveThousand(5_000, false),
    TenThousand(10_000, false),
}

sealed class DenominationCalculationException : IllegalArgumentException() {
    data object NegativeCount : DenominationCalculationException()
    data object Overflow : DenominationCalculationException()
}

object DenominationCalculator {
    fun total(counts: Map<Denomination, Long>): Long {
        var total = 0L
        Denomination.entries.forEach { denomination ->
            val count = counts[denomination] ?: 0L
            if (count < 0) {
                throw DenominationCalculationException.NegativeCount
            }
            try {
                val lineTotal = Math.multiplyExact(denomination.yenValue, count)
                total = Math.addExact(total, lineTotal)
            } catch (_: ArithmeticException) {
                throw DenominationCalculationException.Overflow
            }
        }
        return total
    }
}

data class CashDistributionEntry(
    val id: UUID = UUID.randomUUID(),
    val recipientName1: String = "",
    val amount1: Long = 0,
    val recipientName2: String = "",
    val amount2: Long = 0,
    val recipientName3: String = "",
    val amount3: Long = 0,
    val receivedDate: Instant? = null,
    val receiverName: String = "",
) {
    val recipientAmounts: List<Pair<String, Long>>
        get() = listOf(
            recipientName1 to amount1,
            recipientName2 to amount2,
            recipientName3 to amount3,
        )

    val totalAmount: Long
        get() = recipientAmounts.fold(0L) { total, pair ->
            try {
                Math.addExact(total, pair.second)
            } catch (_: ArithmeticException) {
                throw CashDistributionValidationException.Overflow
            }
        }
}

data class CashDistribution(
    val id: UUID = UUID.randomUUID(),
    val userId: String = "guest",
    val distributionDate: Instant = Instant.now(),
    val title: String = "",
    val entries: List<CashDistributionEntry> = listOf(CashDistributionEntry()),
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    val totalAmount: Long
        get() = entries.fold(0L) { total, entry ->
            try {
                Math.addExact(total, entry.totalAmount)
            } catch (_: ArithmeticException) {
                throw CashDistributionValidationException.Overflow
            }
        }

    fun validated(now: Instant = Instant.now()): CashDistribution {
        val cleanedTitle = title.trim()
        if (cleanedTitle.isEmpty()) {
            throw CashDistributionValidationException.TitleRequired
        }
        var hasAmount = false
        val cleanedEntries = entries.map { entry ->
            val cleaned = entry.copy(
                recipientName1 = entry.recipientName1.trim(),
                recipientName2 = entry.recipientName2.trim(),
                recipientName3 = entry.recipientName3.trim(),
                receiverName = entry.receiverName.trim(),
            )
            cleaned.recipientAmounts.forEach { (name, amount) ->
                if (amount < 0) throw CashDistributionValidationException.NegativeAmount
                if (amount > 0) {
                    hasAmount = true
                    if (name.isEmpty()) {
                        throw CashDistributionValidationException.RecipientNameRequired
                    }
                }
            }
            cleaned
        }
        if (!hasAmount) throw CashDistributionValidationException.AmountRequired
        CashDistributionCalculator.requiredCounts(cleanedEntries)
        return copy(title = cleanedTitle, entries = cleanedEntries, updatedAt = now)
    }
}

sealed class CashDistributionValidationException : IllegalArgumentException() {
    data object TitleRequired : CashDistributionValidationException()
    data object AmountRequired : CashDistributionValidationException()
    data object RecipientNameRequired : CashDistributionValidationException()
    data object NegativeAmount : CashDistributionValidationException()
    data object Overflow : CashDistributionValidationException()
}

object CashDistributionCalculator {
    fun requiredCounts(amount: Long): Map<Denomination, Long> {
        if (amount < 0) throw CashDistributionValidationException.NegativeAmount
        var remainder = amount
        return Denomination.entries
            .sortedByDescending(Denomination::yenValue)
            .associateWith { denomination ->
                val count = remainder / denomination.yenValue
                remainder %= denomination.yenValue
                count
            }
    }

    fun requiredCounts(entries: List<CashDistributionEntry>): Map<Denomination, Long> {
        val result = Denomination.entries.associateWith { 0L }.toMutableMap()
        entries.forEach { entry ->
            entry.recipientAmounts.filter { it.second > 0 }.forEach { (_, amount) ->
                requiredCounts(amount).forEach { (denomination, count) ->
                    result[denomination] = try {
                        Math.addExact(result.getValue(denomination), count)
                    } catch (_: ArithmeticException) {
                        throw CashDistributionValidationException.Overflow
                    }
                }
            }
        }
        return result
    }
}
