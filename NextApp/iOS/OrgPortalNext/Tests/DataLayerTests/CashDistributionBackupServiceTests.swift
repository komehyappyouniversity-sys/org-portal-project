import Foundation
import XCTest
@testable import DataLayer
import Model

@MainActor
final class CashDistributionBackupServiceTests: XCTestCase {
    func testBackupRestoresDistributionAndKeepsExistingRecord() async throws {
        let source = StubCashDistributionRepository()
        let sourceItem = CashDistribution(
            title: "講師謝礼",
            entries: [
                CashDistributionEntry(
                    recipientName1: "講師A",
                    amount1: 12_000,
                    receivedDate: Date(timeIntervalSince1970: 100),
                    receiverName: "担当者"
                )
            ],
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        try await source.save(sourceItem)
        let data = try await CashDistributionBackupService(
            repository: source
        ).exportData(now: Date(timeIntervalSince1970: 400))
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(
            json["format"] as? String,
            "org-portal-cash-distribution-backup"
        )
        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertEqual(json["exportedAtEpochMillis"] as? Int, 400_000)
        let exportedDistributions = try XCTUnwrap(
            json["distributions"] as? [[String: Any]]
        )
        XCTAssertEqual(
            exportedDistributions.first?["distributionDateEpochMillis"] as? Int,
            Int((sourceItem.distributionDate.timeIntervalSince1970 * 1_000).rounded())
        )
        XCTAssertEqual(
            exportedDistributions.first?["createdAtEpochMillis"] as? Int,
            200_000
        )

        let destination = StubCashDistributionRepository()
        try await destination.save(
            CashDistribution(
                title: "端末に残す記録",
                entries: [
                    CashDistributionEntry(
                        recipientName1: "既存",
                        amount1: 1_000
                    )
                ]
            )
        )
        let restoredCount = try await CashDistributionBackupService(
            repository: destination
        ).importData(data)

        XCTAssertEqual(restoredCount, 1)
        let restored = try await destination.fetchAll()
        XCTAssertEqual(
            Set(restored.map(\.title)),
            ["講師謝礼", "端末に残す記録"]
        )
        let restoredItem = try XCTUnwrap(
            restored.first(where: { $0.id == sourceItem.id })
        )
        XCTAssertEqual(restoredItem.entries.first?.amount1, 12_000)
        XCTAssertEqual(restoredItem.entries.first?.receiverName, "担当者")
    }

    func testInvalidBackupFormatIsRejected() async {
        let service = CashDistributionBackupService(
            repository: StubCashDistributionRepository()
        )

        do {
            _ = try await service.importData(Data("{}".utf8))
            XCTFail("Invalid format must be rejected")
        } catch {
            XCTAssertEqual(
                error as? CashDistributionBackupError,
                .invalidFormat
            )
        }
    }
}

@MainActor
private final class StubCashDistributionRepository: CashDistributionRepository {
    private var values: [CashDistribution] = []

    func fetchAll() async throws -> [CashDistribution] {
        values.sorted { $0.distributionDate > $1.distributionDate }
    }

    func save(_ distribution: CashDistribution) async throws {
        values.removeAll { $0.id == distribution.id }
        values.append(distribution)
    }

    func delete(id: UUID) async throws {
        values.removeAll { $0.id == id }
    }
}
