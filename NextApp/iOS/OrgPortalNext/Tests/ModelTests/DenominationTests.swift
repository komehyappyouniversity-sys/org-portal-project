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

    func testCashDistributionDecomposesEachRecipientSeparately() throws {
        let entries = [
            CashDistributionEntry(
                recipientName1: "A",
                amount1: 6_000,
                recipientName2: "B",
                amount2: 6_000
            )
        ]

        let counts = try CashDistributionCalculator.requiredCounts(for: entries)

        XCTAssertEqual(counts[.fiveThousand], 2)
        XCTAssertEqual(counts[.oneThousand], 2)
        XCTAssertEqual(counts[.tenThousand], 0)
        XCTAssertEqual(counts[.twoThousand], 0)
    }

    func testCashDistributionUsesTwoThousandYenBanknote() throws {
        let counts = try CashDistributionCalculator.requiredCounts(for: 12_000)

        XCTAssertEqual(counts[.tenThousand], 1)
        XCTAssertEqual(counts[.twoThousand], 1)
    }

    func testCashDistributionRequiresTitleAndRecipientName() {
        XCTAssertThrowsError(
            try CashDistribution(
                title: "",
                entries: [
                    CashDistributionEntry(recipientName1: "A", amount1: 1_000)
                ]
            ).validated()
        ) { error in
            XCTAssertEqual(error as? CashDistributionValidationError, .titleRequired)
        }

        XCTAssertThrowsError(
            try CashDistribution(
                title: "配布",
                entries: [
                    CashDistributionEntry(recipientName1: "", amount1: 1_000)
                ]
            ).validated()
        ) { error in
            XCTAssertEqual(
                error as? CashDistributionValidationError,
                .recipientNameRequired
            )
        }
    }
}
