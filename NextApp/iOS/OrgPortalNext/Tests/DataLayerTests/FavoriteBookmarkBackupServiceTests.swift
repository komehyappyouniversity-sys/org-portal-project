import Foundation
import Model
import SwiftData
import XCTest
@testable import DataLayer

@MainActor
final class FavoriteBookmarkBackupServiceTests: XCTestCase {
    func testBackupRestoresAllUserContentAndKeepsExistingFavorite() async throws {
        let sourceContainer = try inMemoryContainer()
        let sourceRepository = SwiftDataFavoriteBookmarkRepository(
            modelContainer: sourceContainer
        )
        let sourceFavorite = FavoriteBookmark(
            userId: "guest-local",
            title: "公式サイト",
            url: "https://example.com/article",
            note: "後で読み返すメモ",
            category: "学習",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        try await sourceRepository.save(sourceFavorite)
        let backup = try await FavoriteBookmarkBackupService(
            repository: sourceRepository
        ).exportData(now: Date(timeIntervalSince1970: 300))

        let destinationContainer = try inMemoryContainer()
        let destinationRepository = SwiftDataFavoriteBookmarkRepository(
            modelContainer: destinationContainer
        )
        try await destinationRepository.save(
            FavoriteBookmark(
                title: "端末に残すお気に入り",
                url: "https://example.org"
            )
        )
        let restoredCount = try await FavoriteBookmarkBackupService(
            repository: destinationRepository
        ).importData(backup)

        XCTAssertEqual(restoredCount, 1)
        let restored = try await destinationRepository.fetchAll()
        XCTAssertEqual(Set(restored.map(\.title)), ["公式サイト", "端末に残すお気に入り"])
        let restoredFavorite = try XCTUnwrap(
            restored.first { $0.id == sourceFavorite.id }
        )
        XCTAssertEqual(restoredFavorite.url, "https://example.com/article")
        XCTAssertEqual(restoredFavorite.note, "後で読み返すメモ")
        XCTAssertEqual(restoredFavorite.category, "学習")
    }

    func testInvalidBackupFormatIsRejected() async throws {
        let container = try inMemoryContainer()
        let service = FavoriteBookmarkBackupService(
            repository: SwiftDataFavoriteBookmarkRepository(
                modelContainer: container
            )
        )

        do {
            _ = try await service.importData(Data("{}".utf8))
            XCTFail("Invalid format must be rejected")
        } catch {
            XCTAssertEqual(error as? FavoriteBookmarkBackupError, .invalidFormat)
        }
    }

    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: FavoriteBookmarkRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
