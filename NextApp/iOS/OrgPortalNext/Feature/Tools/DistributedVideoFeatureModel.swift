import Foundation
import DataLayer
import Model
import Session

public protocol DistributedVideoRepository: Sendable {
    func communityVideos(communityId: String, idToken: String) async throws -> [DistributedVideo]
    func videoQuestions(
        communityId: String,
        memberUid: String,
        idToken: String
    ) async throws -> [VideoQuestion]
    func saveVideoQuestion(
        communityId: String,
        memberUid: String,
        video: DistributedVideo,
        memoText: String,
        questionText: String,
        playbackSeconds: Double,
        idToken: String
    ) async throws
}

extension FirebaseRESTCommunityRepository: DistributedVideoRepository {}

@MainActor
public final class DistributedVideoFeatureModel: ObservableObject {
    @Published public private(set) var videos: [DistributedVideo] = []
    @Published public private(set) var videoQuestions: [VideoQuestion] = []
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?

    private let repository: any DistributedVideoRepository
    private let session: AppSession
    private let canViewMembersOnlyVideo: (String) -> Bool
    private let memoStore: VimeoMemoStore

    public init(
        repository: any DistributedVideoRepository,
        session: AppSession,
        canViewMembersOnlyVideo: @escaping (String) -> Bool,
        memoStore: VimeoMemoStore = VimeoMemoStore()
    ) {
        self.repository = repository
        self.session = session
        self.canViewMembersOnlyVideo = canViewMembersOnlyVideo
        self.memoStore = memoStore
    }

    public func load() async {
        guard let communityId = session.selectedCommunityId,
              let token = session.authenticationToken else {
            videos = []
            videoQuestions = []
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let allowed = canViewMembersOnlyVideo(communityId)
            let videosResult = try await repository.communityVideos(
                communityId: communityId,
                idToken: token
            )
            let questionsResult = try await repository.videoQuestions(
                communityId: communityId,
                memberUid: session.authenticatedUserId ?? "",
                idToken: token
            )
            videos = filterDistributedVideos(
                videosResult,
                canViewMembersOnlyVideo: allowed
            )
            videoQuestions = questionsResult
        } catch {
            errorMessage = "動画を取得できませんでした。"
        }
        isLoading = false
    }

    public func videoMemosFor(_ video: DistributedVideo) -> [VimeoVideoMemo] {
        memoStore.entries(communityId: video.communityId, videoId: video.id)
    }

    public func addVideoMemo(
        _ video: DistributedVideo,
        memo: String,
        playbackSeconds: Double
    ) {
        let normalized = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            errorMessage = "メモを入力してください。"
            return
        }
        let now = Date().timeIntervalSince1970 * 1000
        let entries = videoMemosFor(video) + [
            VimeoVideoMemo(
                id: UUID().uuidString,
                text: normalized,
                playbackSeconds: playbackSeconds,
                createdAtMillis: Int64(now),
                updatedAtMillis: Int64(now),
            )
        ]
        persistVideoMemos(
            video: video,
            entries: entries,
            successMessage: "動画メモを追加しました。",
        )
    }

    public func updateVideoMemo(
        _ video: DistributedVideo,
        memo: VimeoVideoMemo,
        text: String
    ) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            errorMessage = "メモを入力してください。"
            return
        }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let updated = videoMemosFor(video).map { entry in
            if entry.id == memo.id {
                return VimeoVideoMemo(
                    id: entry.id,
                    text: normalized,
                    playbackSeconds: entry.playbackSeconds,
                    createdAtMillis: entry.createdAtMillis,
                    updatedAtMillis: now,
                )
            }
            return entry
        }
        persistVideoMemos(
            video: video,
            entries: updated,
            successMessage: "動画メモを更新しました。",
        )
    }

    public func deleteVideoMemo(_ video: DistributedVideo, memo: VimeoVideoMemo) {
        let remaining = videoMemosFor(video).filter { $0.id != memo.id }
        persistVideoMemos(
            video: video,
            entries: remaining,
            successMessage: "動画メモを削除しました。",
        )
    }

    private func persistVideoMemos(
        video: DistributedVideo,
        entries: [VimeoVideoMemo],
        successMessage: String
    ) {
        memoStore.save(communityId: video.communityId, videoId: video.id, entries: entries)
        errorMessage = successMessage
    }

    public func questionsFor(_ video: DistributedVideo) -> [VideoQuestion] {
        videoQuestions
            .filter { $0.videoId == video.id }
            .sorted {
                ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
    }

    public func submitVideoQuestion(
        _ video: DistributedVideo,
        memo: String,
        question: String,
        playbackSeconds: Double
    ) async {
        let normalizedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuestion.isEmpty else {
            errorMessage = "質問を入力してください。"
            return
        }
        guard
            let token = session.authenticationToken,
            let memberUid = session.authenticatedUserId,
            let communityId = session.selectedCommunityId
        else {
            return
        }
        do {
            try await repository.saveVideoQuestion(
                communityId: communityId,
                memberUid: memberUid,
                video: video,
                memoText: memo,
                questionText: normalizedQuestion,
                playbackSeconds: playbackSeconds,
                idToken: token,
            )
            await load()
            errorMessage = "質問を送信しました。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearError() {
        errorMessage = nil
    }
}

internal func filterDistributedVideos(
    _ videos: [DistributedVideo],
    canViewMembersOnlyVideo: Bool,
) -> [DistributedVideo] {
    videos
        .filter { video in
            !video.isPremium && (!video.isMembersOnly || canViewMembersOnlyVideo)
        }
        .sorted {
            $0.sortOrder == $1.sortOrder
                ? $0.title < $1.title
                : $0.sortOrder < $1.sortOrder
        }
}
