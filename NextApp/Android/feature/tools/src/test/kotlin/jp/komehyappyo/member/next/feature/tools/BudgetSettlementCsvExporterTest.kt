package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.model.BudgetEntry
import jp.komehyappyo.member.next.core.model.BudgetEntryType
import jp.komehyappyo.member.next.core.model.BudgetSettlementReport
import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertTrue

class BudgetSettlementCsvExporterTest {
    @Test
    fun exportsBomCrLfRfc4180AndIso8601Timestamps() {
        val report = BudgetSettlementReport(
            userId = "guest",
            fiscalYearStart = LocalDate.of(2025, 4, 1),
            fiscalYearEnd = LocalDate.of(2026, 3, 31),
            bookName = "家計,帳簿",
        )
        val entry = BudgetEntry(
            reportId = report.id,
            date = LocalDate.of(2025, 5, 1),
            entryType = BudgetEntryType.Expense,
            accountItem = "備品\"費",
            detail = "机\n椅子",
            amount = BigDecimal("100.50"),
            receiptType = "領収書",
            createdAt = Instant.parse("2025-05-01T01:02:03Z"),
            updatedAt = Instant.parse("2025-05-01T02:03:04Z"),
        )

        val data = BudgetSettlementCsvExporter.export(report, listOf(entry), ZoneOffset.UTC)
        val csv = data.drop(3).toByteArray().toString(Charsets.UTF_8)

        assertContentEquals(byteArrayOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte()), data.take(3).toByteArray())
        assertTrue(csv.startsWith("schema_version=1\r\n"))
        assertTrue(csv.contains("\"家計,帳簿\""))
        assertTrue(csv.contains("\"備品\"\"費\""))
        assertTrue(csv.contains("\"机\n椅子\""))
        assertTrue(csv.contains("\"2025-05-01T01:02:03Z\""))
        assertTrue(csv.endsWith("\r\n"))
    }
}
