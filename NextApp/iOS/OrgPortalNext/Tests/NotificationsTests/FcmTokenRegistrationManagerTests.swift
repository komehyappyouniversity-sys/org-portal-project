import Foundation
import XCTest
@testable import Notifications

final class FcmTokenRegistrationManagerTests: XCTestCase {
    func testRegistersRefreshesAndDeletesToken() async throws {
        let store = RecordingFcmTokenStore()
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-15T00:00:00Z"))
        let manager = FcmTokenRegistrationManager(
            store: store,
            tokenProvider: FixedFcmTokenProvider(token: "token-1"),
            environment: .development,
            now: { date }
        )

        try await manager.synchronize(userId: "user-1", idToken: "id-token")
        let savedAfterLogin = await store.saved()
        let first = try XCTUnwrap(savedAfterLogin.first)
        XCTAssertEqual(first.userId, "user-1")
        XCTAssertEqual(first.appVariant, "next")
        XCTAssertEqual(first.os, .iOS)
        XCTAssertEqual(first.environment, .development)
        XCTAssertEqual(first.id, FcmToken.id(for: "token-1"))

        try await manager.tokenRefreshed("token-2")
        let savedAfterRefresh = await store.saved()
        let deletedAfterRefresh = await store.deleted()
        XCTAssertEqual(savedAfterRefresh.count, 2)
        XCTAssertEqual(deletedAfterRefresh, ["user-1:\(first.id)"])

        try await manager.synchronize(userId: nil, idToken: nil)
        let deletedAfterLogout = await store.deleted()
        XCTAssertEqual(
            deletedAfterLogout,
            ["user-1:\(first.id)", "user-1:\(FcmToken.id(for: "token-2"))"]
        )
    }
}

private struct FixedFcmTokenProvider: FcmRegistrationTokenProviding {
    let token: String
    func currentToken() async throws -> String { token }
}

private actor RecordingFcmTokenStore: FcmTokenStoring {
    private var savedTokens: [FcmToken] = []
    private var deletedTokenIds: [String] = []

    func save(_ token: FcmToken, idToken: String) async throws {
        savedTokens.append(token)
    }

    func delete(userId: String, tokenId: String, idToken: String) async throws {
        deletedTokenIds.append("\(userId):\(tokenId)")
    }

    func saved() -> [FcmToken] { savedTokens }
    func deleted() -> [String] { deletedTokenIds }
}
