import Model
import SwiftData
import XCTest
@testable import DataLayer

@MainActor
final class SwiftDataFriendExchangeRepositoryTests: XCTestCase {
    func testSaveUpdateFetchAndCascadeDelete() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FriendContactRecord.self,
            FriendInteractionHistoryRecord.self,
            configurations: configuration
        )
        let repository = SwiftDataFriendExchangeRepository(modelContainer: container)
        var contact = FriendContact(
            userId: "guest",
            name: "山田 花子",
            phoneNumber: "090-1234-5678"
        )

        try await repository.save(contact)
        let savedContacts = try await repository.fetchContacts()
        XCTAssertEqual(savedContacts.map(\.name), ["山田 花子"])

        contact.name = "山田 花子（更新）"
        contact.updatedAt = Date().addingTimeInterval(1)
        try await repository.save(contact)
        let updatedContacts = try await repository.fetchContacts()
        XCTAssertEqual(updatedContacts.first?.name, "山田 花子（更新）")

        let history = FriendInteractionHistory(
            friendId: contact.id,
            memo: "喫茶店で交流",
            photoUrls: ["file:///photo.jpg"]
        )
        try await repository.save(history)
        let savedHistories = try await repository.fetchHistories(friendId: contact.id)
        XCTAssertEqual(savedHistories.first?.memo, "喫茶店で交流")

        try await repository.deleteContact(id: contact.id)
        let remainingContacts = try await repository.fetchContacts()
        let remainingHistories = try await repository.fetchHistories(friendId: contact.id)
        XCTAssertTrue(remainingContacts.isEmpty)
        XCTAssertTrue(remainingHistories.isEmpty)
    }
}
