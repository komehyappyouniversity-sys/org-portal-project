import Foundation
import Model

@MainActor
public protocol CashDistributionRepository {
    func fetchAll() async throws -> [CashDistribution]
    func save(_ distribution: CashDistribution) async throws
    func delete(id: UUID) async throws
}
