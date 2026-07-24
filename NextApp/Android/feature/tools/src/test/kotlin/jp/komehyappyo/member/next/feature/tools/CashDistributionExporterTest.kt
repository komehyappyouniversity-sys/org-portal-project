package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.model.CashDistribution
import jp.komehyappyo.member.next.core.model.CashDistributionEntry
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertContentEquals

class CashDistributionExporterTest {
    @Test
    fun csvContainsReceiptFieldsAndUsesBomAndCrlf() {
        val distribution = CashDistribution(
            distributionDate = Instant.EPOCH,
            title = "謝礼, \"夏\"",
            entries = listOf(
                CashDistributionEntry(
                    recipientName1 = "講師A",
                    amount1 = 12_000,
                    receivedDate = Instant.ofEpochSecond(86_400),
                    receiverName = "担当者",
                ),
            ),
        )

        val data = CashDistributionExporter.csvData(distribution)
        assertContentEquals(
            byteArrayOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte()),
            data.take(3).toByteArray(),
        )
        val text = data.drop(3).toByteArray().toString(Charsets.UTF_8)
        assertContains(text, "\r\n")
        assertContains(text, "\"謝礼, \"\"夏\"\"\"")
        assertContains(text, "\"講師A\"")
        assertContains(text, "\"12000\"")
        assertContains(text, "\"担当者\"")
    }
}
