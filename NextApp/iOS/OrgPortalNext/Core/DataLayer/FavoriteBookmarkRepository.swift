import Foundation
import Model

@MainActor
public protocol FavoriteBookmarkRepository {
    func fetchAll() async throws -> [FavoriteBookmark]
    func save(_ favorite: FavoriteBookmark) async throws
    func delete(id: UUID) async throws
}
