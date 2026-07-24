import Foundation
import Model

@MainActor
public protocol SnsCustomLinkRepository {
    func fetchAll() async throws -> [SnsCustomLink]
    func save(_ link: SnsCustomLink) async throws
    func delete(id: UUID) async throws
}
