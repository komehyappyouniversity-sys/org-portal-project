import Foundation
import Model
import SwiftData

@Model
public final class CashDistributionRecord {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var distributionDate: Date
    public var title: String
    public var entriesData: Data
    public var createdAt: Date
    public var updatedAt: Date

    public init(distribution: CashDistribution) {
        id = distribution.id
        userId = distribution.userId
        distributionDate = distribution.distributionDate
        title = distribution.title
        entriesData = Self.encode(distribution.entries)
        createdAt = distribution.createdAt
        updatedAt = distribution.updatedAt
    }

    public func update(from distribution: CashDistribution) {
        userId = distribution.userId
        distributionDate = distribution.distributionDate
        title = distribution.title
        entriesData = Self.encode(distribution.entries)
        updatedAt = distribution.updatedAt
    }

    public func domainModel() -> CashDistribution {
        CashDistribution(
            id: id,
            userId: userId,
            distributionDate: distributionDate,
            title: title,
            entries: Self.decode(entriesData),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func encode(_ entries: [CashDistributionEntry]) -> Data {
        (try? JSONEncoder().encode(entries)) ?? Data("[]".utf8)
    }

    private static func decode(_ data: Data) -> [CashDistributionEntry] {
        (try? JSONDecoder().decode([CashDistributionEntry].self, from: data)) ?? []
    }
}

@MainActor
public final class SwiftDataCashDistributionRepository: CashDistributionRepository {
    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        context = modelContainer.mainContext
    }

    public func fetchAll() async throws -> [CashDistribution] {
        let descriptor = FetchDescriptor<CashDistributionRecord>(
            sortBy: [
                SortDescriptor(\.distributionDate, order: .reverse),
                SortDescriptor(\.updatedAt, order: .reverse)
            ]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func save(_ distribution: CashDistribution) async throws {
        let validated = try distribution.validated(now: distribution.updatedAt)
        let id = validated.id
        let descriptor = FetchDescriptor<CashDistributionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(CashDistributionRecord(distribution: validated))
        }
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<CashDistributionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }
}
