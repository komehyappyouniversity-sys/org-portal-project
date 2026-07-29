import XCTest
@testable import Model

final class FriendExchangeTests: XCTestCase {
    func testContactValidationTrimsTextAndRequiresName() throws {
        let now = Date(timeIntervalSince1970: 1_785_283_200)
        let contact = try FriendContact(
            userId: "guest",
            name: " 山田 花子 ",
            postalCode: " 100-0001 ",
            phoneNumber: " 090-1234-5678 ",
            email: " hanako@example.com "
        ).validated(now: now)

        XCTAssertEqual(contact.name, "山田 花子")
        XCTAssertEqual(contact.postalCode, "100-0001")
        XCTAssertEqual(contact.phoneNumber, "090-1234-5678")
        XCTAssertEqual(contact.email, "hanako@example.com")
        XCTAssertEqual(contact.updatedAt, now)

        XCTAssertThrowsError(
            try FriendContact(userId: "guest", name: "  ").validated()
        ) { error in
            XCTAssertEqual(error as? FriendExchangeValidationError, .nameRequired)
        }
    }

    func testHistoryRequiresContentAndLimitsPhotos() throws {
        let friendID = UUID()

        XCTAssertThrowsError(
            try FriendInteractionHistory(friendId: friendID).validated()
        ) { error in
            XCTAssertEqual(
                error as? FriendExchangeValidationError,
                .historyContentRequired
            )
        }
        XCTAssertThrowsError(
            try FriendInteractionHistory(
                friendId: friendID,
                photoUrls: ["one", "two", "three"]
            ).validated()
        ) { error in
            XCTAssertEqual(error as? FriendExchangeValidationError, .tooManyPhotos)
        }

        let history = try FriendInteractionHistory(
            friendId: friendID,
            memo: " 電話で近況確認 ",
            isPhoneCall: true,
            phoneNumber: " 090-0000-0000 "
        ).validated()
        XCTAssertEqual(history.memo, "電話で近況確認")
        XCTAssertEqual(history.phoneNumber, "090-0000-0000")
    }
}
