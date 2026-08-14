import Foundation
import Model

@MainActor
public protocol BudgetSettlementRepository: AnyObject {
    func fetchReports() async throws -> [BudgetSettlementReport]
    func fetchEntries(reportId: UUID) async throws -> [BudgetEntry]
    func saveReport(_ report: BudgetSettlementReport) async throws
    func saveEntry(_ entry: BudgetEntry) async throws
    func deleteEntry(id: UUID) async throws
    func deleteReport(id: UUID) async throws
}
