import Foundation
import Model

public enum CashDistributionBackupError: Error, Equatable {
    case invalidFormat
    case unsupportedVersion
}

private struct CashDistributionBackupEnvelope: Codable {
    let format: String
    let version: Int
    let exportedAtEpochMillis: Int64
    let distributions: [CashDistributionBackupRecord]
}

private struct CashDistributionBackupRecord: Codable {
    let id: String
    let userId: String
    let distributionDateEpochMillis: Int64
    let title: String
    let entries: [CashDistributionEntryBackupRecord]
    let createdAtEpochMillis: Int64
    let updatedAtEpochMillis: Int64

    init(_ distribution: CashDistribution) {
        id = distribution.id.uuidString
        userId = distribution.userId
        distributionDateEpochMillis = distribution.distributionDate.epochMilliseconds
        title = distribution.title
        entries = distribution.entries.map(CashDistributionEntryBackupRecord.init)
        createdAtEpochMillis = distribution.createdAt.epochMilliseconds
        updatedAtEpochMillis = distribution.updatedAt.epochMilliseconds
    }

    var domainModel: CashDistribution? {
        guard let id = UUID(uuidString: id) else { return nil }
        let restoredEntries = entries.compactMap(\.domainModel)
        guard restoredEntries.count == entries.count else { return nil }
        return CashDistribution(
            id: id,
            userId: userId,
            distributionDate: Date(epochMilliseconds: distributionDateEpochMillis),
            title: title,
            entries: restoredEntries,
            createdAt: Date(epochMilliseconds: createdAtEpochMillis),
            updatedAt: Date(epochMilliseconds: updatedAtEpochMillis)
        )
    }
}

private struct CashDistributionEntryBackupRecord: Codable {
    let id: String
    let recipientName1: String
    let amount1: Int64
    let recipientName2: String
    let amount2: Int64
    let recipientName3: String
    let amount3: Int64
    let receivedDateEpochMillis: Int64?
    let receiverName: String

    init(_ entry: CashDistributionEntry) {
        id = entry.id.uuidString
        recipientName1 = entry.recipientName1
        amount1 = entry.amount1
        recipientName2 = entry.recipientName2
        amount2 = entry.amount2
        recipientName3 = entry.recipientName3
        amount3 = entry.amount3
        receivedDateEpochMillis = entry.receivedDate?.epochMilliseconds
        receiverName = entry.receiverName
    }

    var domainModel: CashDistributionEntry? {
        guard let id = UUID(uuidString: id) else { return nil }
        return CashDistributionEntry(
            id: id,
            recipientName1: recipientName1,
            amount1: amount1,
            recipientName2: recipientName2,
            amount2: amount2,
            recipientName3: recipientName3,
            amount3: amount3,
            receivedDate: receivedDateEpochMillis.map(Date.init(epochMilliseconds:)),
            receiverName: receiverName
        )
    }
}

@MainActor
public final class CashDistributionBackupService {
    public static let formatIdentifier = "org-portal-cash-distribution-backup"
    public static let currentVersion = 1

    private let repository: CashDistributionRepository

    public init(repository: CashDistributionRepository) {
        self.repository = repository
    }

    public func exportData(now: Date = .now) async throws -> Data {
        let envelope = CashDistributionBackupEnvelope(
            format: Self.formatIdentifier,
            version: Self.currentVersion,
            exportedAtEpochMillis: now.epochMilliseconds,
            distributions: try await repository.fetchAll().map(
                CashDistributionBackupRecord.init
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    @discardableResult
    public func importData(_ data: Data) async throws -> Int {
        guard let envelope = try? JSONDecoder().decode(
            CashDistributionBackupEnvelope.self,
            from: data
        ) else {
            throw CashDistributionBackupError.invalidFormat
        }
        guard envelope.format == Self.formatIdentifier else {
            throw CashDistributionBackupError.invalidFormat
        }
        guard envelope.version == Self.currentVersion else {
            throw CashDistributionBackupError.unsupportedVersion
        }

        for backupRecord in envelope.distributions {
            guard let distribution = backupRecord.domainModel else {
                throw CashDistributionBackupError.invalidFormat
            }
            try await repository.save(
                try distribution.validated(now: distribution.updatedAt)
            )
        }
        return envelope.distributions.count
    }
}

private extension Date {
    var epochMilliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1_000).rounded())
    }

    init(epochMilliseconds: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(epochMilliseconds) / 1_000)
    }
}
