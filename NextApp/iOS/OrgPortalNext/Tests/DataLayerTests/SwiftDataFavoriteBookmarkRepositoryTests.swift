import Model
import SwiftData
import XCTest
@testable import DataLayer

@MainActor
final class SwiftDataFavoriteBookmarkRepositoryTests: XCTestCase {
    func testSaveUpdateFetchAndDelete() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FavoriteBookmarkRecord.self,
            configurations: configuration
        )
        let repository = SwiftDataFavoriteBookmarkRepository(modelContainer: container)
        var favorite = FavoriteBookmark(
            title: "公式ブログ",
            url: "https://example.com",
            category: "仕事"
        )

        try await repository.save(favorite)
        let saved = try await repository.fetchAll()
        XCTAssertEqual(saved.map(\.title), ["公式ブログ"])

        favorite.title = "公式サイト"
        favorite.note = "更新済み"
        favorite.updatedAt = Date().addingTimeInterval(1)
        try await repository.save(favorite)
        let updated = try await repository.fetchAll()
        XCTAssertEqual(updated.map(\.title), ["公式サイト"])
        XCTAssertEqual(updated.first?.note, "更新済み")

        try await repository.delete(id: favorite.id)
        let remaining = try await repository.fetchAll()
        XCTAssertTrue(remaining.isEmpty)
    }
}
