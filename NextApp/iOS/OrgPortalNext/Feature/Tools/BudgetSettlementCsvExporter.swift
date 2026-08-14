import Foundation
import Model

public enum BudgetSettlementCsvExporter {
    public static func data(
        report: BudgetSettlementReport,
        entries: [BudgetEntry]
    ) -> Data {
        let timestamp = ISO8601DateFormatter()
        let date = DateFormatter()
        date.calendar = Calendar(identifier: .gregorian)
        date.locale = Locale(identifier: "en_US_POSIX")
        date.timeZone = .current
        date.dateFormat = "yyyy-MM-dd"
        let header = [
            "report_id", "book_name", "fiscal_year_start", "fiscal_year_end",
            "entry_id", "date", "entry_type", "account_item", "detail", "amount",
            "receipt_type", "receipt_image_url", "created_at", "updated_at"
        ].map(escape).joined(separator: ",")
        let rows = entries.map { entry in
            [
                report.id.uuidString,
                report.bookName,
                date.string(from: report.fiscalYearStart),
                date.string(from: report.fiscalYearEnd),
                entry.id.uuidString,
                date.string(from: entry.date),
                entry.entryType.rawValue,
                entry.accountItem,
                entry.detail,
                NSDecimalNumber(decimal: entry.amount).stringValue,
                entry.receiptType,
                entry.receiptImageUrl ?? "",
                timestamp.string(from: entry.createdAt),
                timestamp.string(from: entry.updatedAt)
            ].map(escape).joined(separator: ",")
        }
        let csv = (["schema_version=1", header] + rows).joined(separator: "\r\n") + "\r\n"
        return Data([0xEF, 0xBB, 0xBF]) + Data(csv.utf8)
    }

    private static func escape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
