import XCTest
@testable import Model

final class DenominationTests: XCTestCase {
    func testAllJapaneseYenDenominationsHaveTheSharedOrder() {
        XCTAssertEqual(
            Denomination.allCases.map(\.rawValue),
            [1, 5, 10, 50, 100, 500, 1_000, 2_000, 5_000, 10_000]
        )
    }

    func testCalculatorTotalsCoinsAndBanknotes() throws {
        let total = try DenominationCalculator.total(
            counts: [
                .one: 3,
                .fiveHundred: 2,
                .twoThousand: 1,
                .tenThousand: 4
            ]
        )
        XCTAssertEqual(total, 43_003)
    }

    func testMissingCountsAreTreatedAsZero() throws {
        XCTAssertEqual(
            try DenominationCalculator.total(counts: [:]),
            0
        )
    }

    func testNegativeCountIsRejected() {
        XCTAssertThrowsError(
            try DenominationCalculator.total(counts: [.one: -1])
        ) { error in
            XCTAssertEqual(
                error as? DenominationCalculationError,
                .negativeCount
            )
        }
    }

    func testOverflowIsRejected() {
        XCTAssertThrowsError(
            try DenominationCalculator.total(
                counts: [.tenThousand: Int64.max]
            )
        ) { error in
            XCTAssertEqual(
                error as? DenominationCalculationError,
                .overflow
            )
        }
    }
}
