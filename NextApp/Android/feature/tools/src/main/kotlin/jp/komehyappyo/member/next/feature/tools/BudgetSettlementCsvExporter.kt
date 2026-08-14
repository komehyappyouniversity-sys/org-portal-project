package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.model.BudgetEntry
import jp.komehyappyo.member.next.core.model.BudgetSettlementReport
import java.time.ZoneId
import java.time.format.DateTimeFormatter

object BudgetSettlementCsvExporter {
    private val timestampFormatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME

    fun export(
        report: BudgetSettlementReport,
        entries: List<BudgetEntry>,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): ByteArray {
        val rows = mutableListOf(
            "schema_version=1",
            listOf(
                "report_id",
                "book_name",
                "fiscal_year_start",
                "fiscal_year_end",
                "entry_id",
                "date",
                "entry_type",
                "account_item",
                "detail",
                "amount",
                "receipt_type",
                "receipt_image_url",
                "created_at",
                "updated_at",
            ).joinToString(",", transform = ::escape),
        )
        entries.forEach { entry ->
            rows += listOf(
                report.id.toString(),
                report.bookName,
                report.fiscalYearStart.toString(),
                report.fiscalYearEnd.toString(),
                entry.id.toString(),
                entry.date.toString(),
                entry.entryType.wireValue,
                entry.accountItem,
                entry.detail,
                entry.amount.toPlainString(),
                entry.receiptType,
                entry.receiptImageUrl.orEmpty(),
                timestampFormatter.format(entry.createdAt.atZone(zoneId)),
                timestampFormatter.format(entry.updatedAt.atZone(zoneId)),
            ).joinToString(",", transform = ::escape)
        }
        return byteArrayOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte()) +
            (rows.joinToString("\r\n") + "\r\n").toByteArray(Charsets.UTF_8)
    }

    private fun escape(value: String) = "\"${value.replace("\"", "\"\"")}\""
}
