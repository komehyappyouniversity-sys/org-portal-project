import Foundation
import XCTest
@testable import Model

final class BudgetSettlementTests: XCTestCase {
    func testRecalculatesIncomeExpenseAndBalanceFromEntries() throws {
        let report = makeReport()
        let entries = [
            makeEntry(reportId: report.id, type: .income, amount: 1_250.50),
            makeEntry(reportId: report.id, type: .income, amount: 49.50),
            makeEntry(reportId: report.id, type: .expense, amount: 325.25)
        ]

        let result = try report.recalculated(entries: entries)

        XCTAssertEqual(result.incomeTotal, 1_300)
        XCTAssertEqual(result.expenseTotal, 325.25)
        XCTAssertEqual(result.balance, 974.75)
    }

    func testRecalculationReturnsZeroAfterEntriesAreRemoved() throws {
        var report = makeReport()
        report.incomeTotal = 10
        report.expenseTotal = 1
        report.balance = 9

        let result = try report.recalculated(entries: [])

        XCTAssertEqual(result.incomeTotal, 0)
        XCTAssertEqual(result.expenseTotal, 0)
        XCTAssertEqual(result.balance, 0)
    }

    func testRejectsInvalidInput() {
        var report = makeReport()
        report.bookName = " "
        XCTAssertThrowsError(try report.validated())

        let invalidAmount = makeEntry(reportId: report.id, type: .expense, amount: -1)
        XCTAssertThrowsError(try invalidAmount.validated())

        var missingAccount = makeEntry(reportId: report.id, type: .expense, amount: 1)
        missingAccount.accountItem = ""
        XCTAssertThrowsError(try missingAccount.validated())
    }

    private func makeReport() -> BudgetSettlementReport {
        BudgetSettlementReport(
            userId: "guest",
            fiscalYearStart: Date(timeIntervalSince1970: 1_743_465_600),
            fiscalYearEnd: Date(timeIntervalSince1970: 1_774_915_200),
            bookName: "個人帳簿"
        )
    }

    private func makeEntry(
        reportId: UUID,
        type: BudgetEntryType,
        amount: Decimal
    ) -> BudgetEntry {
        BudgetEntry(
            reportId: reportId,
            date: .now,
            entryType: type,
            accountItem: "科目",
            amount: amount
        )
    }
}
