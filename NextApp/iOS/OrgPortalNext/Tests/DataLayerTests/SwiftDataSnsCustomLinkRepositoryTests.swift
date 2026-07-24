import Model
import SwiftData
import XCTest
@testable import DataLayer

@MainActor
final class SwiftDataSnsCustomLinkRepositoryTests: XCTestCase {
    func testSaveUpdateFetchAndDelete() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SnsCustomLinkRecord.self,
            configurations: configuration
        )
        let repository = SwiftDataSnsCustomLinkRepository(modelContainer: container)
        var link = SnsCustomLink(
            title: "公式ブログ",
            url: "https://example.com",
            sortOrder: 0
        )

        try await repository.save(link)
        let savedLinks = try await repository.fetchAll()
        XCTAssertEqual(savedLinks.map(\.title), ["公式ブログ"])

        link.title = "公式サイト"
        try await repository.save(link)
        let updatedLinks = try await repository.fetchAll()
        XCTAssertEqual(updatedLinks.map(\.title), ["公式サイト"])

        try await repository.delete(id: link.id)
        let remainingLinks = try await repository.fetchAll()
        XCTAssertTrue(remainingLinks.isEmpty)
    }
}
