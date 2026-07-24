import Foundation
import Model
import SwiftData

@Model
public final class SnsCustomLinkRecord {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var title: String
    public var url: String
    public var sortOrder: Int

    public init(link: SnsCustomLink) {
        id = link.id
        userId = link.userId
        title = link.title
        url = link.url
        sortOrder = link.sortOrder
    }

    public func update(from link: SnsCustomLink) {
        userId = link.userId
        title = link.title
        url = link.url
        sortOrder = link.sortOrder
    }

    public func domainModel() -> SnsCustomLink {
        SnsCustomLink(
            id: id,
            userId: userId,
            title: title,
            url: url,
            sortOrder: sortOrder
        )
    }
}

@MainActor
public final class SwiftDataSnsCustomLinkRepository: SnsCustomLinkRepository {
    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        context = modelContainer.mainContext
    }

    public func fetchAll() async throws -> [SnsCustomLink] {
        let descriptor = FetchDescriptor<SnsCustomLinkRecord>(
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.title),
            ]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func save(_ link: SnsCustomLink) async throws {
        let validated = try link.validated()
        let id = validated.id
        let descriptor = FetchDescriptor<SnsCustomLinkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(SnsCustomLinkRecord(link: validated))
        }
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<SnsCustomLinkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }
}
