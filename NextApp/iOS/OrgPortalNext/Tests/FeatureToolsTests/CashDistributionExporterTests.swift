import Foundation
import XCTest
@testable import FeatureTools
import Model

final class CashDistributionExporterTests: XCTestCase {
    func testCsvContainsReceiptFieldsAndUsesBomAndCrlf() throws {
        let distribution = CashDistribution(
            distributionDate: Date(timeIntervalSince1970: 0),
            title: "謝礼, \"夏\"",
            entries: [
                CashDistributionEntry(
                    recipientName1: "講師A",
                    amount1: 12_000,
                    receivedDate: Date(timeIntervalSince1970: 86_400),
                    receiverName: "担当者"
                )
            ]
        )

        let data = CashDistributionExporter.csvData(distribution)

        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
        let text = try XCTUnwrap(
            String(data: data.dropFirst(3), encoding: .utf8)
        )
        XCTAssertTrue(text.contains("\r\n"))
        XCTAssertTrue(text.contains("\"謝礼, \"\"夏\"\"\""))
        XCTAssertTrue(text.contains("\"講師A\""))
        XCTAssertTrue(text.contains("\"12000\""))
        XCTAssertTrue(text.contains("\"担当者\""))
    }

    func testPdfFileIsGenerated() throws {
        let distribution = CashDistribution(
            title: "PDF確認",
            entries: [
                CashDistributionEntry(
                    recipientName1: "講師A",
                    amount1: 12_000
                )
            ]
        )

        let url = try CashDistributionExporter.pdfFile(distribution)
        let data = try Data(contentsOf: url)

        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 100)
    }
}
