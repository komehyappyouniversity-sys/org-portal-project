import Foundation
import Model
import SwiftData

@Model
public final class BudgetSettlementReportRecord {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var fiscalYearStart: Date
    public var fiscalYearEnd: Date
    public var bookName: String
    public var incomeTotal: Decimal
    public var expenseTotal: Decimal
    public var balance: Decimal
    public var createdAt: Date
    public var updatedAt: Date

    public init(report: BudgetSettlementReport) {
        id = report.id
        userId = report.userId
        fiscalYearStart = report.fiscalYearStart
        fiscalYearEnd = report.fiscalYearEnd
        bookName = report.bookName
        incomeTotal = report.incomeTotal
        expenseTotal = report.expenseTotal
        balance = report.balance
        createdAt = report.createdAt
        updatedAt = report.updatedAt
    }

    public func update(from report: BudgetSettlementReport) {
        userId = report.userId
        fiscalYearStart = report.fiscalYearStart
        fiscalYearEnd = report.fiscalYearEnd
        bookName = report.bookName
        incomeTotal = report.incomeTotal
        expenseTotal = report.expenseTotal
        balance = report.balance
        createdAt = report.createdAt
        updatedAt = report.updatedAt
    }

    public func domainModel() -> BudgetSettlementReport {
        BudgetSettlementReport(
            id: id,
            userId: userId,
            fiscalYearStart: fiscalYearStart,
            fiscalYearEnd: fiscalYearEnd,
            bookName: bookName,
            incomeTotal: incomeTotal,
            expenseTotal: expenseTotal,
            balance: balance,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
public final class BudgetEntryRecord {
    @Attribute(.unique) public var id: UUID
    public var reportId: UUID
    public var date: Date
    public var entryTypeRaw: String
    public var accountItem: String
    public var detail: String
    public var amount: Decimal
    public var receiptType: String
    public var receiptImageUrl: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(entry: BudgetEntry) {
        id = entry.id
        reportId = entry.reportId
        date = entry.date
        entryTypeRaw = entry.entryType.rawValue
        accountItem = entry.accountItem
        detail = entry.detail
        amount = entry.amount
        receiptType = entry.receiptType
        receiptImageUrl = entry.receiptImageUrl
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
    }

    public func update(from entry: BudgetEntry) {
        reportId = entry.reportId
        date = entry.date
        entryTypeRaw = entry.entryType.rawValue
        accountItem = entry.accountItem
        detail = entry.detail
        amount = entry.amount
        receiptType = entry.receiptType
        receiptImageUrl = entry.receiptImageUrl
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
    }

    public func domainModel() -> BudgetEntry {
        BudgetEntry(
            id: id,
            reportId: reportId,
            date: date,
            entryType: BudgetEntryType(rawValue: entryTypeRaw) ?? .expense,
            accountItem: accountItem,
            detail: detail,
            amount: amount,
            receiptType: receiptType,
            receiptImageUrl: receiptImageUrl,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@MainActor
public final class SwiftDataBudgetSettlementRepository: BudgetSettlementRepository {
    private let context: ModelContext
    private let deleteReceipt: (String) throws -> Void

    public init(
        modelContainer: ModelContainer,
        deleteReceipt: @escaping (String) throws -> Void = { _ in }
    ) {
        context = modelContainer.mainContext
        self.deleteReceipt = deleteReceipt
    }

    public func fetchReports() async throws -> [BudgetSettlementReport] {
        let descriptor = FetchDescriptor<BudgetSettlementReportRecord>(
            sortBy: [
                SortDescriptor(\.fiscalYearStart, order: .reverse),
                SortDescriptor(\.bookName)
            ]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func fetchEntries(reportId: UUID) async throws -> [BudgetEntry] {
        try records(reportId: reportId).map { $0.domainModel() }
    }

    public func saveReport(_ report: BudgetSettlementReport) async throws {
        let entries = try records(reportId: report.id).map { $0.domainModel() }
        let validated = try report.validated(now: report.updatedAt)
            .recalculated(entries: entries, now: report.updatedAt)
        let id = validated.id
        let descriptor = FetchDescriptor<BudgetSettlementReportRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(BudgetSettlementReportRecord(report: validated))
        }
        try context.save()
    }

    public func saveEntry(_ entry: BudgetEntry) async throws {
        let reportId = entry.reportId
        let reportDescriptor = FetchDescriptor<BudgetSettlementReportRecord>(
            predicate: #Predicate { $0.id == reportId }
        )
        guard try context.fetch(reportDescriptor).first != nil else {
            throw BudgetSettlementRepositoryError.reportNotFound
        }
        let validated = try entry.validated(now: entry.updatedAt)
        let id = validated.id
        let descriptor = FetchDescriptor<BudgetEntryRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(BudgetEntryRecord(entry: validated))
        }
        try recalculate(reportId: reportId)
        try context.save()
    }

    public func deleteEntry(id: UUID) async throws {
        let descriptor = FetchDescriptor<BudgetEntryRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record = try context.fetch(descriptor).first else { return }
        let reportId = record.reportId
        let receipt = record.receiptImageUrl
        context.delete(record)
        try recalculate(reportId: reportId)
        try context.save()
        if let receipt { try deleteReceipt(receipt) }
    }

    public func deleteReport(id: UUID) async throws {
        let entryRecords = try records(reportId: id)
        let receipts = entryRecords.compactMap(\.receiptImageUrl)
        entryRecords.forEach(context.delete)
        let descriptor = FetchDescriptor<BudgetSettlementReportRecord>(
            predicate: #Predicate { $0.id == id }
        )
        try context.fetch(descriptor).forEach(context.delete)
        try context.save()
        for receipt in receipts { try deleteReceipt(receipt) }
    }

    private func records(reportId: UUID) throws -> [BudgetEntryRecord] {
        let descriptor = FetchDescriptor<BudgetEntryRecord>(
            predicate: #Predicate { $0.reportId == reportId },
            sortBy: [
                SortDescriptor(\.date, order: .reverse),
                SortDescriptor(\.updatedAt, order: .reverse)
            ]
        )
        return try context.fetch(descriptor)
    }

    private func recalculate(reportId: UUID) throws {
        let descriptor = FetchDescriptor<BudgetSettlementReportRecord>(
            predicate: #Predicate { $0.id == reportId }
        )
        guard let reportRecord = try context.fetch(descriptor).first else { return }
        let entries = try records(reportId: reportId).map { $0.domainModel() }
        reportRecord.update(
            from: try reportRecord.domainModel().recalculated(entries: entries, now: Date.now)
        )
    }
}

public enum BudgetSettlementRepositoryError: Error, Equatable {
    case reportNotFound
}
