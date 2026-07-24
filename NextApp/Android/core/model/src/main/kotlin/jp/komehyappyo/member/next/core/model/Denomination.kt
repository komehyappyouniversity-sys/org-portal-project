package jp.komehyappyo.member.next.core.model

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
