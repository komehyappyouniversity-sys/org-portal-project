import XCTest
@testable import Model

final class ManualTests: XCTestCase {
    func testListIdentitySeparatesSharedAndCommunityDocumentsWithSameId() {
        let shared = manual(communityId: nil)
        let community = manual(communityId: "org-1")

        XCTAssertEqual(shared.listIdentity, "shared:guide")
        XCTAssertEqual(community.listIdentity, "org-1:guide")
        XCTAssertNotEqual(shared.listIdentity, community.listIdentity)
    }

    private func manual(communityId: String?) -> Manual {
        Manual(
            id: "guide",
            communityId: communityId,
            title: "タイトル",
            body: "本文",
            sortOrder: 1,
            isPublished: true
        )
    }
}
