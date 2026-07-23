import XCTest
@testable import FeatureTools
import Model

final class ScheduleCsvExporterTests: XCTestCase {
    func testCsvUsesBomAndCrlf() throws {
        let start = Date(timeIntervalSince1970: 0)
        let schedule = Schedule(
            userId: "guest",
            title: "引用符\"を含む予定",
            startDateTime: start,
            endDateTime: start.addingTimeInterval(60)
        )
        let data = ScheduleCsvExporter.data(for: [schedule])
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
        let text = try XCTUnwrap(String(data: data.dropFirst(3), encoding: .utf8))
        XCTAssertTrue(text.contains("\r\n"))
        XCTAssertTrue(text.contains("\"引用符\"\"を含む予定\""))
    }
}
