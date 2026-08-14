import Foundation
import Model
import XCTest
@testable import FeatureTools

final class BudgetSettlementCsvExporterTests: XCTestCase {
    func testExportsBOMCRLFRFC4180AndISO8601Timestamps() throws {
        let report = BudgetSettlementReport(
            userId: "guest",
            fiscalYearStart: Date(timeIntervalSince1970: 1_743_465_600),
            fiscalYearEnd: Date(timeIntervalSince1970: 1_774_915_200),
            bookName: "家計,帳簿"
        )
        let entry = BudgetEntry(
            reportId: report.id,
            date: Date(timeIntervalSince1970: 1_746_057_600),
            entryType: .expense,
            accountItem: "備品\"費",
            detail: "机\n椅子",
            amount: 100.50,
            receiptType: "領収書",
            createdAt: Date(timeIntervalSince1970: 1_746_061_323),
            updatedAt: Date(timeIntervalSince1970: 1_746_064_984)
        )

        let data = BudgetSettlementCsvExporter.data(report: report, entries: [entry])
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
        let csv = try XCTUnwrap(String(data: data.dropFirst(3), encoding: .utf8))
        XCTAssertTrue(csv.hasPrefix("schema_version=1\r\n"))
        XCTAssertTrue(csv.contains("\"家計,帳簿\""))
        XCTAssertTrue(csv.contains("\"備品\"\"費\""))
        XCTAssertTrue(csv.contains("\"机\n椅子\""))
        XCTAssertTrue(csv.contains("T"))
        XCTAssertTrue(csv.hasSuffix("\r\n"))
    }
}
