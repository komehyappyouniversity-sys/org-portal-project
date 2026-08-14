import Foundation
import Model
import SwiftData
import XCTest
@testable import DataLayer

@MainActor
final class SwiftDataBudgetSettlementRepositoryTests: XCTestCase {
    func testSavesFetchesAndRecalculatesWhenEntriesChange() async throws {
        let container = try ModelContainer(
            for: BudgetSettlementReportRecord.self,
            BudgetEntryRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        var deletedReceipts: [String] = []
        let repository = SwiftDataBudgetSettlementRepository(
            modelContainer: container,
            deleteReceipt: { deletedReceipts.append($0) }
        )
        let report = BudgetSettlementReport(
            userId: "guest",
            fiscalYearStart: .now,
            fiscalYearEnd: .now.addingTimeInterval(86_400),
            bookName: "家計簿"
        )
        try await repository.saveReport(report)
        let income = BudgetEntry(
            reportId: report.id,
            date: .now,
            entryType: .income,
            accountItem: "給与",
            amount: 1_000.50
        )
        let expense = BudgetEntry(
            reportId: report.id,
            date: .now,
            entryType: .expense,
            accountItem: "消耗品",
            amount: 200.25,
            receiptImageUrl: "receipts/item.jpg"
        )

        try await repository.saveEntry(income)
        try await repository.saveEntry(expense)

        let saved = try await repository.fetchReports().first
        XCTAssertEqual(saved?.incomeTotal, 1_000.50)
        XCTAssertEqual(saved?.expenseTotal, 200.25)
        XCTAssertEqual(saved?.balance, 800.25)
        XCTAssertEqual(try await repository.fetchEntries(reportId: report.id).count, 2)

        try await repository.deleteEntry(id: expense.id)

        let afterDelete = try await repository.fetchReports().first
        XCTAssertEqual(afterDelete?.expenseTotal, 0)
        XCTAssertEqual(afterDelete?.balance, 1_000.50)
        XCTAssertEqual(deletedReceipts, ["receipts/item.jpg"])
    }

    func testDeletingReportCascadesEntriesAndReceipts() async throws {
        let container = try ModelContainer(
            for: BudgetSettlementReportRecord.self,
            BudgetEntryRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        var deletedReceipts: [String] = []
        let repository = SwiftDataBudgetSettlementRepository(
            modelContainer: container,
            deleteReceipt: { deletedReceipts.append($0) }
        )
        let report = BudgetSettlementReport(
            userId: "guest",
            fiscalYearStart: .now,
            fiscalYearEnd: .now.addingTimeInterval(86_400),
            bookName: "家計簿"
        )
        try await repository.saveReport(report)
        try await repository.saveEntry(
            BudgetEntry(
                reportId: report.id,
                date: .now,
                entryType: .expense,
                accountItem: "交通費",
                amount: 500,
                receiptImageUrl: "receipts/train.jpg"
            )
        )

        try await repository.deleteReport(id: report.id)

        XCTAssertTrue(try await repository.fetchReports().isEmpty)
        XCTAssertTrue(try await repository.fetchEntries(reportId: report.id).isEmpty)
        XCTAssertEqual(deletedReceipts, ["receipts/train.jpg"])
    }
}
