import SwiftData
import XCTest
@testable import DataLayer
import Model

@MainActor
final class SwiftDataDiaryRepositoryTests: XCTestCase {
    func testSaveFetchAndDelete() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DiaryRecord.self,
            configurations: configuration
        )
        let repository = SwiftDataDiaryRepository(modelContainer: container)
        let diary = Diary(
            userId: "guest",
            title: "保存テスト",
            body: "端末内に保存します",
            mood: .good
        )

        try await repository.save(diary)
        let saved = try await repository.fetchAll()
        XCTAssertEqual(saved.map(\.title), ["保存テスト"])
        XCTAssertEqual(saved.first?.mood, .good)

        try await repository.delete(id: diary.id)
        let remaining = try await repository.fetchAll()
        XCTAssertTrue(remaining.isEmpty)
    }
}
