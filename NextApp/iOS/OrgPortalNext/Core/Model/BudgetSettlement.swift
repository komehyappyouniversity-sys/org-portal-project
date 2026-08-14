import Foundation

public enum BudgetEntryType: String, CaseIterable, Codable, Sendable {
    case income
    case expense
}

public struct BudgetEntry: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var reportId: UUID
    public var date: Date
    public var entryType: BudgetEntryType
    public var accountItem: String
    public var detail: String
    public var amount: Decimal
    public var receiptType: String
    public var receiptImageUrl: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        reportId: UUID,
        date: Date,
        entryType: BudgetEntryType,
        accountItem: String,
        detail: String = "",
        amount: Decimal,
        receiptType: String = "",
        receiptImageUrl: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.reportId = reportId
        self.date = date
        self.entryType = entryType
        self.accountItem = accountItem
        self.detail = detail
        self.amount = amount
        self.receiptType = receiptType
        self.receiptImageUrl = receiptImageUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validated(now: Date = .now) throws -> BudgetEntry {
        var result = self
        result.accountItem = accountItem.trimmingCharacters(in: .whitespacesAndNewlines)
        result.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        result.receiptType = receiptType.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReceiptURL = receiptImageUrl?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result.receiptImageUrl = trimmedReceiptURL?.isEmpty == false ? trimmedReceiptURL : nil
        result.updatedAt = now
        guard !result.accountItem.isEmpty else {
            throw BudgetSettlementValidationError.accountItemRequired
        }
        guard result.amount > 0 else {
            throw BudgetSettlementValidationError.amountMustBePositive
        }
        return result
    }
}

public struct BudgetSettlementReport: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var userId: String
    public var fiscalYearStart: Date
    public var fiscalYearEnd: Date
    public var bookName: String
    public var incomeTotal: Decimal
    public var expenseTotal: Decimal
    public var balance: Decimal
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: String,
        fiscalYearStart: Date,
        fiscalYearEnd: Date,
        bookName: String,
        incomeTotal: Decimal = 0,
        expenseTotal: Decimal = 0,
        balance: Decimal = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.fiscalYearStart = fiscalYearStart
        self.fiscalYearEnd = fiscalYearEnd
        self.bookName = bookName
        self.incomeTotal = incomeTotal
        self.expenseTotal = expenseTotal
        self.balance = balance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validated(now: Date = .now) throws -> BudgetSettlementReport {
        var result = self
        result.bookName = bookName.trimmingCharacters(in: .whitespacesAndNewlines)
        result.updatedAt = now
        guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BudgetSettlementValidationError.userIdRequired
        }
        guard !result.bookName.isEmpty else {
            throw BudgetSettlementValidationError.bookNameRequired
        }
        guard fiscalYearEnd >= fiscalYearStart else {
            throw BudgetSettlementValidationError.fiscalYearOrder
        }
        return result
    }

    public func recalculated(
        entries: [BudgetEntry],
        now: Date? = nil
    ) throws -> BudgetSettlementReport {
        guard entries.allSatisfy({ $0.reportId == id }) else {
            throw BudgetSettlementValidationError.entryReportMismatch
        }
        var result = self
        result.incomeTotal = entries
            .filter { $0.entryType == .income }
            .reduce(0) { $0 + $1.amount }
        result.expenseTotal = entries
            .filter { $0.entryType == .expense }
            .reduce(0) { $0 + $1.amount }
        result.balance = result.incomeTotal - result.expenseTotal
        if let now { result.updatedAt = now }
        return result
    }
}

public enum BudgetSettlementValidationError: Error, Equatable, Sendable {
    case userIdRequired
    case bookNameRequired
    case fiscalYearOrder
    case accountItemRequired
    case amountMustBePositive
    case entryReportMismatch

    public var message: String {
        switch self {
        case .userIdRequired: "利用者IDが必要です。"
        case .bookNameRequired: "帳簿名を入力してください。"
        case .fiscalYearOrder: "会計年度の終了日は開始日以降にしてください。"
        case .accountItemRequired: "科目を入力してください。"
        case .amountMustBePositive: "金額は0より大きい値を入力してください。"
        case .entryReportMismatch: "別の帳簿の明細は集計できません。"
        }
    }
}
