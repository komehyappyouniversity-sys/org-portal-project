import Foundation
import Model
import SwiftData

@Model
public final class FavoriteBookmarkRecord {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var title: String
    public var url: String
    public var note: String
    public var category: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(favorite: FavoriteBookmark) {
        id = favorite.id
        userId = favorite.userId
        title = favorite.title
        url = favorite.url
        note = favorite.note
        category = favorite.category
        createdAt = favorite.createdAt
        updatedAt = favorite.updatedAt
    }

    public func update(from favorite: FavoriteBookmark) {
        userId = favorite.userId
        title = favorite.title
        url = favorite.url
        note = favorite.note
        category = favorite.category
        createdAt = favorite.createdAt
        updatedAt = favorite.updatedAt
    }

    public func domainModel() -> FavoriteBookmark {
        FavoriteBookmark(
            id: id,
            userId: userId,
            title: title,
            url: url,
            note: note,
            category: category,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@MainActor
public final class SwiftDataFavoriteBookmarkRepository: FavoriteBookmarkRepository {
    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        context = modelContainer.mainContext
    }

    public func fetchAll() async throws -> [FavoriteBookmark] {
        let descriptor = FetchDescriptor<FavoriteBookmarkRecord>(
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.title),
            ]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func save(_ favorite: FavoriteBookmark) async throws {
        let validated = try favorite.validated()
        let id = validated.id
        let descriptor = FetchDescriptor<FavoriteBookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(FavoriteBookmarkRecord(favorite: validated))
        }
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<FavoriteBookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }
}
