package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class DenominationTest {
    @Test
    fun allJapaneseYenDenominationsHaveTheSharedOrder() {
        assertEquals(
            listOf(1L, 5L, 10L, 50L, 100L, 500L, 1_000L, 2_000L, 5_000L, 10_000L),
            Denomination.entries.map(Denomination::yenValue),
        )
    }

    @Test
    fun calculatorTotalsCoinsAndBanknotes() {
        assertEquals(
            43_003L,
            DenominationCalculator.total(
                mapOf(
                    Denomination.One to 3,
                    Denomination.FiveHundred to 2,
                    Denomination.TwoThousand to 1,
                    Denomination.TenThousand to 4,
                ),
            ),
        )
    }

    @Test
    fun missingCountsAreTreatedAsZero() {
        assertEquals(0L, DenominationCalculator.total(emptyMap()))
    }

    @Test
    fun negativeCountIsRejected() {
        assertFailsWith<DenominationCalculationException.NegativeCount> {
            DenominationCalculator.total(mapOf(Denomination.One to -1))
        }
    }

    @Test
    fun overflowIsRejected() {
        assertFailsWith<DenominationCalculationException.Overflow> {
            DenominationCalculator.total(mapOf(Denomination.TenThousand to Long.MAX_VALUE))
        }
    }

    @Test
    fun cashDistributionDecomposesEachRecipientSeparately() {
        val counts = CashDistributionCalculator.requiredCounts(
            listOf(
                CashDistributionEntry(
                    recipientName1 = "A",
                    amount1 = 6_000,
                    recipientName2 = "B",
                    amount2 = 6_000,
                ),
            ),
        )

        assertEquals(2L, counts[Denomination.FiveThousand])
        assertEquals(2L, counts[Denomination.OneThousand])
        assertEquals(0L, counts[Denomination.TenThousand])
        assertEquals(0L, counts[Denomination.TwoThousand])
    }

    @Test
    fun cashDistributionUsesTwoThousandYenBanknote() {
        val counts = CashDistributionCalculator.requiredCounts(12_000)

        assertEquals(1L, counts[Denomination.TenThousand])
        assertEquals(1L, counts[Denomination.TwoThousand])
    }

    @Test
    fun cashDistributionRequiresTitleAndRecipientName() {
        assertFailsWith<CashDistributionValidationException.TitleRequired> {
            CashDistribution(
                title = "",
                entries = listOf(
                    CashDistributionEntry(recipientName1 = "A", amount1 = 1_000),
                ),
            ).validated()
        }

        assertFailsWith<CashDistributionValidationException.RecipientNameRequired> {
            CashDistribution(
                title = "配布",
                entries = listOf(
                    CashDistributionEntry(recipientName1 = "", amount1 = 1_000),
                ),
            ).validated()
        }
    }
}
