import Foundation
import Model

@MainActor
public protocol FriendExchangeRepository: AnyObject {
    func fetchContacts() async throws -> [FriendContact]
    func fetchHistories(friendId: UUID) async throws -> [FriendInteractionHistory]
    func save(_ contact: FriendContact) async throws
    func save(_ history: FriendInteractionHistory) async throws
    func deleteContact(id: UUID) async throws
    func deleteHistory(id: UUID) async throws
}
