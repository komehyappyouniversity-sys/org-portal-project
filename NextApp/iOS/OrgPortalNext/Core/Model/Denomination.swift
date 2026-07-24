public enum Denomination: Int64, CaseIterable, Identifiable, Sendable {
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
