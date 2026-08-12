import Foundation
import Model
import Session
import XCTest
@testable import FeatureTools

@MainActor
final class DistributedVideoFeatureModelTests: XCTestCase {
    func testFiltersOutMembersOnlyAndPremiumVideosForUnapprovedCommunity() {
        let sourceVideos = [
            distributedVideo(id: "public", title: "公開動画", sortOrder: 1),
            distributedVideo(id: "member", title: "限定動画", sortOrder: 0, isMembersOnly: true),
            distributedVideo(id: "premium", title: "有料動画", sortOrder: 2, isPremium: true),
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
            distributedVideo(id: "member", title: "限定動画", sortOrder: 0, isMembersOnly: true),
            distributedVideo(id: "premium", title: "有料動画", sortOrder: 2, isPremium: true),
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

    func testLoadFiltersVideosAndSortsQuestionsByLatestDate() async {
        let (memoStore, defaults, suiteName) = makeMemoStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let session = AppSession()
        session.selectCommunity("org-1")
        session.updateAuthenticatedUser(userId: "member", idToken: "token")

        let repository = FakeDistributedVideoRepository(
            videos: [
                distributedVideo(
                    id: "public",
                    title: "公開動画",
                    sortOrder: 1,
                ),
                distributedVideo(
                    id: "member",
                    title: "限定動画",
                    sortOrder: 0,
                    isMembersOnly: true,
                ),
                distributedVideo(
                    id: "premium",
                    title: "有料動画",
                    sortOrder: 2,
                    isPremium: true,
                ),
            ],
            questions: [
                sampleVideoQuestion(
                    id: "old",
                    videoId: "public",
                    questionText: "古い質問",
                    createdAt: Date(timeIntervalSince1970: 10),
                ),
                sampleVideoQuestion(
                    id: "new",
                    videoId: "public",
                    questionText: "新しい質問",
                    createdAt: Date(timeIntervalSince1970: 20),
                ),
                sampleVideoQuestion(
                    id: "other",
                    videoId: "member",
                    questionText: "他動画の質問",
                    createdAt: Date(timeIntervalSince1970: 30),
                ),
            ]
        )
        let model = DistributedVideoFeatureModel(
            repository: repository,
            session: session,
            canViewMembersOnlyVideo: { _ in false },
            memoStore: memoStore,
        )

        await model.load()

        XCTAssertEqual(["public"], model.videos.map(\.id))
        let questions = model.questionsFor(distributedVideo(id: "public", title: "公開動画", sortOrder: 1))
        XCTAssertEqual(["new", "old"], questions.map(\.id))
    }

    func testAddUpdateAndDeleteVideoMemoByVideo() {
        let (memoStore, defaults, suiteName) = makeMemoStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let session = AppSession()
        session.selectCommunity("org-1")
        session.updateAuthenticatedUser(userId: "member", idToken: "token")
        let model = DistributedVideoFeatureModel(
            repository: FakeDistributedVideoRepository(videos: [], questions: []),
            session: session,
            canViewMembersOnlyVideo: { _ in true },
            memoStore: memoStore,
        )
        let video = distributedVideo(id: "video-1", title: "動画", sortOrder: 0)

        model.addVideoMemo(video, memo: "", playbackSeconds: 0)
        XCTAssertEqual("メモを入力してください。", model.errorMessage)

        model.addVideoMemo(video, memo: "最初のメモ", playbackSeconds: 10)
        model.addVideoMemo(video, memo: "2番目のメモ", playbackSeconds: 20)

        let memos = model.videoMemosFor(video)
        XCTAssertEqual(2, memos.count)

        guard let target = memos.first(where: { $0.text == "最初のメモ" }) else {
            XCTFail("追加したメモが見つかりません")
            return
        }
        model.updateVideoMemo(video, memo: target, text: "更新後")

        let updated = model.videoMemosFor(video).first(where: { $0.id == target.id })
        XCTAssertEqual("更新後", updated?.text)

        guard let toDelete = model.videoMemosFor(video).first(where: { $0.text == "2番目のメモ" }) else {
            XCTFail("削除対象メモが見つかりません")
            return
        }
        model.deleteVideoMemo(video, memo: toDelete)
        XCTAssertEqual(1, model.videoMemosFor(video).count)
    }

    func testSubmitVideoQuestionRejectsBlankThenSavesValidQuestion() async {
        let (memoStore, defaults, suiteName) = makeMemoStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = FakeDistributedVideoRepository(videos: [], questions: [])
        let session = AppSession()
        session.selectCommunity("org-1")
        session.updateAuthenticatedUser(userId: "member", idToken: "token")
        let model = DistributedVideoFeatureModel(
            repository: repository,
            session: session,
            canViewMembersOnlyVideo: { _ in true },
            memoStore: memoStore,
        )
        let video = distributedVideo(id: "video-1", title: "動画", sortOrder: 0)

        await model.submitVideoQuestion(video, memo: "", question: "   ", playbackSeconds: 10)
        XCTAssertEqual("質問を入力してください。", model.errorMessage)
        XCTAssertEqual(0, repository.saveVideoQuestionCallCount)

        await model.submitVideoQuestion(
            video,
            memo: "再生中のメモ",
            question: "質問内容",
            playbackSeconds: 15,
        )
        XCTAssertEqual("質問を送信しました。", model.errorMessage)
        XCTAssertEqual(1, repository.saveVideoQuestionCallCount)
        XCTAssertEqual("質問内容", repository.savedQuestion?.questionText)
    }
}

final class VimeoMemoStoreTests: XCTestCase {
    func testMemoStoreSortsByCreatedAtAndSerializes() {
        let (memoStore, defaults, suiteName) = makeMemoStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let older = VimeoVideoMemo(
            id: "old",
            text: "古いメモ",
            playbackSeconds: 12,
            createdAtMillis: 1,
            updatedAtMillis: 1,
        )
        let newer = VimeoVideoMemo(
            id: "new",
            text: "新しいメモ",
            playbackSeconds: 34,
            createdAtMillis: 2,
            updatedAtMillis: 2,
        )

        memoStore.save(communityId: "org-1", videoId: "video-1", entries: [older, newer])

        XCTAssertEqual(["new", "old"], memoStore.entries(communityId: "org-1", videoId: "video-1").map(\.id))
        XCTAssertTrue(memoStore.serialized(entries: [older, newer]).contains("\"new\""))
        XCTAssertTrue(memoStore.serialized(entries: []).isEmpty)
    }

    func testMemoStoreFallsBackToLegacyTextValue() {
        let (memoStore, defaults, suiteName) = makeMemoStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("{\"org-1:video-1\":\"旧メモ\"}", forKey: "memo_values")

        let entries = memoStore.entries(communityId: "org-1", videoId: "video-1")
        XCTAssertEqual(1, entries.count)
        XCTAssertEqual("legacy", entries[0].id)
        XCTAssertEqual("旧メモ", entries[0].text)
    }
}

private func makeMemoStore(
    name: String = "com.orgportal.distributed-video-tests"
) -> (VimeoMemoStore, UserDefaults, String) {
    let suiteName = "\(name).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    return (VimeoMemoStore(userDefaults: defaults), defaults, suiteName)
}

private final class FakeDistributedVideoRepository: DistributedVideoRepository, @unchecked Sendable {
    let videos: [DistributedVideo]
    let questions: [VideoQuestion]
    private(set) var saveVideoQuestionCallCount = 0
    private(set) var savedQuestion: VideoQuestion?

    init(videos: [DistributedVideo], questions: [VideoQuestion]) {
        self.videos = videos
        self.questions = questions
    }

    func communityVideos(
        communityId: String,
        idToken: String
    ) async throws -> [DistributedVideo] {
        videos
    }

    func videoQuestions(
        communityId: String,
        memberUid: String,
        idToken: String
    ) async throws -> [VideoQuestion] {
        questions
    }

    func saveVideoQuestion(
        communityId: String,
        memberUid: String,
        video: DistributedVideo,
        memoText: String,
        questionText: String,
        playbackSeconds: Double,
        idToken: String
    ) async throws {
        saveVideoQuestionCallCount += 1
        savedQuestion = VideoQuestion(
            id: UUID().uuidString,
            communityId: communityId,
            memberUid: memberUid,
            videoId: video.id,
            videoTitle: video.title,
            playbackSeconds: playbackSeconds,
            memoText: memoText,
            questionText: questionText,
            answerText: "",
            createdAt: Date(),
        )
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

private func sampleVideoQuestion(
    id: String,
    videoId: String,
    questionText: String,
    createdAt: Date
) -> VideoQuestion {
    VideoQuestion(
        id: id,
        communityId: "org-1",
        memberUid: "member",
        videoId: videoId,
        videoTitle: "",
        playbackSeconds: 0,
        memoText: "",
        questionText: questionText,
        answerText: "",
        createdAt: createdAt,
    )
}
