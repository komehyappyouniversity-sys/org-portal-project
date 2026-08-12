import Model
import Session
import XCTest
@testable import FeatureTools

final class DistributedVideoFeatureModelTests: XCTestCase {
    func testFiltersOutMembersOnlyAndPremiumVideosForUnapprovedCommunity() {
        let sourceVideos = [
            distributedVideo(id: "public", title: "公開動画", sortOrder: 1),
            distributedVideo(id: "member", title: "限定動画", isMembersOnly: true, sortOrder: 0),
            distributedVideo(id: "premium", title: "有料動画", isPremium: true, sortOrder: 2),
            distributedVideo(id: "another", title: "別公開動画", sortOrder: 3),
        ]

        let filtered = filterDistributedVideos(
            sourceVideos,
            canViewMembersOnlyVideo: false,
        )

        XCTAssertEqual(["public", "another"], filtered.map(\.id))
    }

    func testAllowsMembersOnlyVideoWhenCommunityIsApproved() {
        let sourceVideos = [
            distributedVideo(id: "public", title: "公開動画", sortOrder: 1),
            distributedVideo(id: "member", title: "限定動画", isMembersOnly: true, sortOrder: 0),
            distributedVideo(id: "premium", title: "有料動画", isPremium: true, sortOrder: 2),
            distributedVideo(id: "another", title: "別公開動画", sortOrder: 3),
        ]

        let filtered = filterDistributedVideos(
            sourceVideos,
            canViewMembersOnlyVideo: true,
        )

        XCTAssertEqual(["member", "public", "another"], filtered.map(\.id))
    }

    func testResolvesDistributedVideoSourceByEmbedThenVimeoThenVideoUrl() {
        let embedVideo = distributedVideo(
            id: "a",
            title: "embed",
            sortOrder: 0,
            embedHtml: "<iframe />",
            vimeoUrl: "https://example.com/vimeo",
            videoUrl: "https://example.com/video",
        )
        let vimeoOnlyVideo = distributedVideo(
            id: "b",
            title: "vimeo",
            sortOrder: 1,
            embedHtml: "",
            vimeoUrl: "https://example.com/vimeo",
            videoUrl: "https://example.com/video",
        )
        let urlOnlyVideo = distributedVideo(
            id: "c",
            title: "url",
            sortOrder: 2,
            embedHtml: "",
            vimeoUrl: "",
            videoUrl: "https://example.com/video",
        )
        let spaceVideo = distributedVideo(
            id: "d",
            title: "space",
            sortOrder: 3,
            embedHtml: "   ",
            vimeoUrl: "\n\t",
            videoUrl: "https://example.com/video",
        )

        XCTAssertEqual(.embedHtml("<iframe />"), distributedVideoSource(for: embedVideo))
        XCTAssertEqual(.url("https://example.com/vimeo"), distributedVideoSource(for: vimeoOnlyVideo))
        XCTAssertEqual(.url("https://example.com/video"), distributedVideoSource(for: urlOnlyVideo))
        XCTAssertEqual(.url("https://example.com/video"), distributedVideoSource(for: spaceVideo))
    }
}

private func distributedVideo(
    id: String,
    title: String,
    sortOrder: Int,
    embedHtml: String = "",
    vimeoUrl: String = "",
    videoUrl: String = "",
    isMembersOnly: Bool = false,
    isPremium: Bool = false,
) -> DistributedVideo {
    DistributedVideo(
        id: id,
        communityId: "org-1",
        videoTitle: title,
        description: "",
        embedHtml: embedHtml,
        videoUrl: videoUrl,
        vimeoUrl: vimeoUrl,
        providerVideoId: "",
        videoType: "distributed_vimeo",
        thumbnailUrl: "",
        isPremium: isPremium,
        createdAt: nil,
        updatedAt: nil,
        isPublished: true,
        isMembersOnly: isMembersOnly,
        sortOrder: sortOrder,
    )
}
