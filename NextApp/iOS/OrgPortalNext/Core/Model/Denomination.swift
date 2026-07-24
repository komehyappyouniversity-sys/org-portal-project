import Foundation

public enum Denomination: Int64, CaseIterable, Codable, Identifiable, Sendable {
    case one = 1
    case five = 5
    case ten = 10
    case fifty = 50
    case oneHundred = 100
    case fiveHundred = 500
    case oneThousand = 1_000
    case twoThousand = 2_000
    case fiveThousand = 5_000
    case tenThousand = 10_000

    public var id: Int64 { rawValue }

    public var isCoin: Bool {
        rawValue < 1_000
    }
}

public struct CashDistributionEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var recipientName1: String
    public var amount1: Int64
    public var recipientName2: String
    public var amount2: Int64
    public var recipientName3: String
    public var amount3: Int64
    public var receivedDate: Date?
    public var receiverName: String

    public init(
        id: UUID = UUID(),
        recipientName1: String = "",
        amount1: Int64 = 0,
        recipientName2: String = "",
        amount2: Int64 = 0,
        recipientName3: String = "",
        amount3: Int64 = 0,
        receivedDate: Date? = nil,
        receiverName: String = ""
    ) {
        self.id = id
        self.recipientName1 = recipientName1
        self.amount1 = amount1
        self.recipientName2 = recipientName2
        self.amount2 = amount2
        self.recipientName3 = recipientName3
        self.amount3 = amount3
        self.receivedDate = receivedDate
        self.receiverName = receiverName
    }

    public var recipientAmounts: [(name: String, amount: Int64)] {
        [
            (recipientName1, amount1),
            (recipientName2, amount2),
            (recipientName3, amount3)
        ]
    }

    public var totalAmount: Int64 {
        recipientAmounts.reduce(0) { $0 + $1.amount }
    }
}

public struct CashDistribution: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var userId: String
    public var distributionDate: Date
    public var title: String
    public var entries: [CashDistributionEntry]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: String = "guest",
        distributionDate: Date = .now,
        title: String = "",
        entries: [CashDistributionEntry] = [CashDistributionEntry()],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.distributionDate = distributionDate
        self.title = title
        self.entries = entries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var totalAmount: Int64 {
        entries.reduce(0) { $0 + $1.totalAmount }
    }

    public func validated(now: Date = .now) throws -> CashDistribution {
        var value = self
        value.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.title.isEmpty else {
            throw CashDistributionValidationError.titleRequired
        }
        var hasAmount = false
        value.entries = try entries.map { entry in
            var cleaned = entry
            cleaned.recipientName1 = entry.recipientName1.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned.recipientName2 = entry.recipientName2.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned.recipientName3 = entry.recipientName3.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned.receiverName = entry.receiverName.trimmingCharacters(in: .whitespacesAndNewlines)
            for pair in cleaned.recipientAmounts {
                guard pair.amount >= 0 else {
                    throw CashDistributionValidationError.negativeAmount
                }
                if pair.amount > 0 {
                    hasAmount = true
                    guard !pair.name.isEmpty else {
                        throw CashDistributionValidationError.recipientNameRequired
                    }
                }
            }
            return cleaned
        }
        guard hasAmount else {
            throw CashDistributionValidationError.amountRequired
        }
        _ = try CashDistributionCalculator.requiredCounts(for: value.entries)
        var checkedTotal: Int64 = 0
        for entry in value.entries {
            for pair in entry.recipientAmounts {
                let (newTotal, overflow) = checkedTotal.addingReportingOverflow(pair.amount)
                guard !overflow else {
                    throw CashDistributionValidationError.overflow
                }
                checkedTotal = newTotal
            }
        }
        value.updatedAt = now
        return value
    }
}

public enum CashDistributionValidationError: Error, Equatable {
    case titleRequired
    case amountRequired
    case recipientNameRequired
    case negativeAmount
    case overflow
}

public enum CashDistributionCalculator {
    public static func requiredCounts(
        for amount: Int64
    ) throws -> [Denomination: Int64] {
        guard amount >= 0 else {
            throw CashDistributionValidationError.negativeAmount
        }
        var remainder = amount
        var counts: [Denomination: Int64] = [:]
        for denomination in Denomination.allCases.sorted(by: { $0.rawValue > $1.rawValue }) {
            counts[denomination] = remainder / denomination.rawValue
            remainder %= denomination.rawValue
        }
        return counts
    }

    public static func requiredCounts(
        for entries: [CashDistributionEntry]
    ) throws -> [Denomination: Int64] {
        var result: [Denomination: Int64] = [:]
        for entry in entries {
            for pair in entry.recipientAmounts where pair.amount > 0 {
                let counts = try requiredCounts(for: pair.amount)
                for denomination in Denomination.allCases {
                    let (newValue, overflow) = result[
                        denomination,
                        default: 0
                    ].addingReportingOverflow(counts[denomination, default: 0])
                    guard !overflow else {
                        throw CashDistributionValidationError.overflow
                    }
                    result[denomination] = newValue
                }
            }
        }
        return result
    }
}

public enum DenominationCalculationError: Error, Equatable {
    case negativeCount
    case overflow
}

public enum DenominationCalculator {
    public static func total(
        counts: [Denomination: Int64]
    ) throws -> Int64 {
        try Denomination.allCases.reduce(into: 0) { total, denomination in
            let count = counts[denomination, default: 0]
            guard count >= 0 else {
                throw DenominationCalculationError.negativeCount
            }
            let (lineTotal, multiplyOverflow) =
                denomination.rawValue.multipliedReportingOverflow(by: count)
            guard !multiplyOverflow else {
                throw DenominationCalculationError.overflow
            }
            let (newTotal, addOverflow) = total.addingReportingOverflow(lineTotal)
            guard !addOverflow else {
                throw DenominationCalculationError.overflow
            }
            total = newTotal
        }
    }
}
