import XCTest

@testable import DataLayer

final class FirebaseEnvironmentGuardDistributedVideoParserTests: XCTestCase {
    func testParseDistributedVideoFallsBackForMissingFields() {
        let document: [String: Any] = [
            "name": "projects/test/databases/(default)/documents/organizations/org-1/videos/",
            "fields": [:],
        ]
        let video = parseDistributedVideo(
            document: document,
            fields: [:],
            communityId: "org-1",
        )

        XCTAssertFalse(video.id.isEmpty)
        XCTAssertEqual(video.videoTitle, "Vimeo動画")
        XCTAssertEqual(video.description, "")
        XCTAssertEqual(video.embedHtml, "")
        XCTAssertEqual(video.videoUrl, "")
        XCTAssertEqual(video.vimeoUrl, "")
        XCTAssertEqual(video.providerVideoId, "")
        XCTAssertEqual(video.videoType, "distributed_vimeo")
        XCTAssertEqual(video.thumbnailUrl, "")
        XCTAssertEqual(video.sortOrder, 0)
        XCTAssertEqual(video.primaryCategoryId, "")
        XCTAssertEqual(video.secondaryCategoryId, "")
        XCTAssertFalse(video.isPublished)
        XCTAssertFalse(video.isMembersOnly)
        XCTAssertFalse(video.isPremium)
        XCTAssertNil(video.createdAt)
        XCTAssertNil(video.updatedAt)
    }

    func testParseDistributedVideoHandlesUnknownFieldsAndFallbacks() {
        let document = [
            "name": "projects/test/databases/(default)/documents/organizations/org-1/videos/video-1",
            "fields": [
                "providerVideoId": ["stringValue": "v123"],
                "title": ["stringValue": "legacy title"],
                "description": ["stringValue": "desc"],
                "embedHtml": ["stringValue": "<iframe></iframe>"],
                "videoUrl": ["stringValue": "https://example.com/video"],
                "primaryCategoryId": ["stringValue": "cat-main"],
                "secondaryCategoryId": ["stringValue": "cat-sub"],
                "isMembersOnly": ["booleanValue": true],
                "sortOrder": ["integerValue": "42"],
                "futureField": ["stringValue": "future"],
            ],
        ] as [String: Any]

        let fields = document["fields"] as? [String: Any] ?? [:]
        let video = parseDistributedVideo(
            document: document,
            fields: fields,
            communityId: "org-1",
        )

        XCTAssertEqual(video.communityId, "org-1")
        XCTAssertEqual(video.id, "video-1")
        XCTAssertEqual(video.videoTitle, "legacy title")
        XCTAssertEqual(video.description, "desc")
        XCTAssertEqual(video.embedHtml, "<iframe></iframe>")
        XCTAssertEqual(video.videoUrl, "https://example.com/video")
        XCTAssertEqual(video.vimeoUrl, "https://vimeo.com/v123")
        XCTAssertEqual(video.providerVideoId, "v123")
        XCTAssertTrue(video.isMembersOnly)
        XCTAssertEqual(video.sortOrder, 42)
        XCTAssertEqual(video.primaryCategoryId, "cat-main")
        XCTAssertEqual(video.secondaryCategoryId, "cat-sub")
        XCTAssertTrue(video.title == "legacy title")
    }

    func testParseDistributedVideoFallsBackCategoryToLegacyField() {
        let document = [
            "name": "projects/test/databases/(default)/documents/organizations/org-1/videos/video-legacy",
            "fields": [
                "providerVideoId": ["stringValue": "v999"],
                "category": ["stringValue": "legacy-category"],
                "vimeoUrl": ["stringValue": "https://vimeo.com/existing"],
            ],
        ] as [String: Any]

        let fields = document["fields"] as? [String: Any] ?? [:]
        let video = parseDistributedVideo(
            document: document,
            fields: fields,
            communityId: "org-1",
        )

        XCTAssertEqual(video.primaryCategoryId, "legacy-category")
        XCTAssertEqual(video.secondaryCategoryId, "")
        XCTAssertEqual(video.vimeoUrl, "https://vimeo.com/v999")
        XCTAssertEqual(video.providerVideoId, "v999")
    }
}
