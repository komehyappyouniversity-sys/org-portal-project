import DataLayer
import Foundation
import Model

@MainActor
public final class CashDistributionFeatureModel: ObservableObject {
    @Published public private(set) var distributions: [CashDistribution] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let repository: CashDistributionRepository
    private let backupService: CashDistributionBackupService

    public init(repository: CashDistributionRepository) {
        self.repository = repository
        backupService = CashDistributionBackupService(repository: repository)
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            distributions = try await repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func save(_ distribution: CashDistribution) async throws {
        var value = distribution
        value.updatedAt = .now
        try await repository.save(value)
        await load()
    }

    public func delete(_ distribution: CashDistribution) async {
        do {
            try await repository.delete(id: distribution.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func exportBackup() async throws -> Data {
        try await backupService.exportData()
    }

    @discardableResult
    public func importBackup(_ data: Data) async throws -> Int {
        let count = try await backupService.importData(data)
        await load()
        return count
    }
}
