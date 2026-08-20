import XCTest
@testable import Notifications

final class NotificationRouteParserTests: XCTestCase {
    func testParsesAllNotificationDeepLinks() throws {
        let cases: [(String, NotificationRoute)] = [
            (
                "orgportalnext://announcements/announcement-1?communityId=community-a",
                NotificationRoute(type: .announcement, targetId: "announcement-1", communityId: "community-a")
            ),
            (
                "orgportalnext://posts/post-1?communityId=community-b",
                NotificationRoute(type: .adminReply, targetId: "post-1", communityId: "community-b")
            ),
            (
                "orgportalnext://video-questions/question-1?communityId=community-c",
                NotificationRoute(
                    type: .videoQuestionAnswer,
                    targetId: "question-1",
                    communityId: "community-c"
                )
            ),
            (
                "orgportalnext://events/event-1?communityId=community-d",
                NotificationRoute(type: .event, targetId: "event-1", communityId: "community-d")
            )
        ]

        for (value, expected) in cases {
            XCTAssertEqual(NotificationRouteParser.route(url: try XCTUnwrap(URL(string: value))), expected)
        }
    }

    func testParsesPayloadAndPreservesSupportRoute() throws {
        XCTAssertEqual(
            NotificationRouteParser.route(userInfo: [
                "notificationType": "admin_reply",
                "postId": "post-2",
                "communityId": "community-a"
            ]),
            NotificationRoute(type: .adminReply, targetId: "post-2", communityId: "community-a")
        )
        XCTAssertEqual(
            SupportNotificationRouter.messageId(userInfo: ["supportMessageId": "message-0"]),
            "message-0"
        )
        XCTAssertEqual(
            SupportNotificationRouter.messageId(
                url: try XCTUnwrap(URL(string: "orgportalnext://support/messages/message-1"))
            ),
            "message-1"
        )
    }

    func testCommunitySwitchDecision() {
        let route = NotificationRoute(type: .event, targetId: "event-1", communityId: "community-b")
        XCTAssertEqual(
            NotificationNavigationDecision.resolve(
                route: route,
                selectedCommunityId: "community-a"
            ).communityIdToSelect,
            "community-b"
        )
        XCTAssertNil(
            NotificationNavigationDecision.resolve(
                route: route,
                selectedCommunityId: "community-b"
            ).communityIdToSelect
        )
    }
}
