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
    func videoMemos(userId: String, idToken: String) async throws -> [String: String]
    func saveVideoMemo(
        userId: String,
        communityId: String,
        videoId: String,
        memo: String,
        idToken: String
    ) async throws
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
    @Published public private(set) var hasPendingVideoMemoSync = false
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
            hasPendingVideoMemoSync = false
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
            if let userId = session.authenticatedUserId {
                let remoteMemos = try await repository.videoMemos(userId: userId, idToken: token)
                memoStore.saveAllEntries(
                    mergeMemoEntries(
                        local: memoStore.allEntries(),
                        remote: remoteMemos,
                    )
                )
                await synchronizePendingVideoMemos(userId: userId, token: token)
            }
            videos = filterDistributedVideos(
                videosResult,
                canViewMembersOnlyVideo: allowed
            )
            videoQuestions = questionsResult
        } catch {
            errorMessage = "動画を取得できませんでした。"
        }
        updatePendingVideoMemoSyncState()
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
                syncStatus: .synced,
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
                    syncStatus: .synced,
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
        updatePendingVideoMemoSyncState()
        guard let userId = session.authenticatedUserId,
              let token = session.authenticationToken else {
            errorMessage = successMessage
            return
        }
        Task {
            await syncVideoMemos(
                video: video,
                entries: entries,
                userId: userId,
                token: token,
                successMessage: successMessage,
                reportSuccess: true,
            )
        }
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

    private func syncVideoMemos(
        video: DistributedVideo,
        entries: [VimeoVideoMemo],
        userId: String,
        token: String,
        successMessage: String,
        reportSuccess: Bool,
    ) async {
        do {
            let payload = memoStore.serialized(entries: entries)
            try await repository.saveVideoMemo(
                userId: userId,
                communityId: video.communityId,
                videoId: video.id,
                memo: payload,
                idToken: token
            )
            memoStore.save(
                communityId: video.communityId,
                videoId: video.id,
                entries: entries.map {
                    VimeoVideoMemo(
                        id: $0.id,
                        text: $0.text,
                        playbackSeconds: $0.playbackSeconds,
                        createdAtMillis: $0.createdAtMillis,
                        updatedAtMillis: $0.updatedAtMillis,
                        syncStatus: .synced,
                    )
                },
            )
            if reportSuccess {
                await MainActor.run { errorMessage = successMessage }
            }
        } catch {
            memoStore.save(
                communityId: video.communityId,
                videoId: video.id,
                entries: entries.map {
                    VimeoVideoMemo(
                        id: $0.id,
                        text: $0.text,
                        playbackSeconds: $0.playbackSeconds,
                        createdAtMillis: $0.createdAtMillis,
                        updatedAtMillis: $0.updatedAtMillis,
                        syncStatus: .pendingSync,
                    )
                },
            )
            await MainActor.run { errorMessage = "オフライン時は動画メモを保留しました。" }
        }
        await MainActor.run { updatePendingVideoMemoSyncState() }
    }

    private func synchronizePendingVideoMemos(userId: String, token: String) async {
        let pending = memoStore.pendingEntries()
        guard !pending.isEmpty else { return }
        let allEntries = memoStore.allEntries()
        for (key, pendingEntries) in pending where !pendingEntries.isEmpty {
            let components = key.split(separator: ":", maxSplits: 1).map(String.init)
            guard components.count == 2 else { continue }
            let memoVideo = videoEntriesKeyToVideo(
                communityId: components[0],
                videoId: components[1],
            )
            // Sync the full entry list for this video, not just the pending subset —
            // syncVideoMemos overwrites the store for this key, so passing only the
            // pending entries would silently drop any already-synced memos.
            await syncVideoMemos(
                video: memoVideo,
                entries: allEntries[key] ?? pendingEntries,
                userId: userId,
                token: token,
                successMessage: "",
                reportSuccess: false,
            )
        }
    }

    private func videoEntriesKeyToVideo(communityId: String, videoId: String) -> DistributedVideo {
        DistributedVideo(
            id: videoId,
            communityId: communityId,
            videoTitle: "",
            description: "",
            embedHtml: "",
            videoUrl: "",
            vimeoUrl: "",
            providerVideoId: "",
            videoType: "distributed_vimeo",
            thumbnailUrl: "",
            isPremium: false,
            createdAt: nil,
            updatedAt: nil,
            isPublished: true,
            isMembersOnly: false,
            sortOrder: 0,
        )
    }

    private func mergeMemoEntries(
        local: [String: [VimeoVideoMemo]],
        remote: [String: String],
    ) -> [String: [VimeoVideoMemo]] {
        var merged = local
        for (key, rawPayload) in remote {
            let remoteEntries = memoStore.entries(fromRaw: rawPayload)
            let localEntries = local[key] ?? []
            merged[key] = mergedMemoEntries(localEntries: localEntries, remoteEntries: remoteEntries)
        }
        return merged
    }

    private func mergedMemoEntries(
        localEntries: [VimeoVideoMemo],
        remoteEntries: [VimeoVideoMemo],
    ) -> [VimeoVideoMemo] {
        let localById = Dictionary(uniqueKeysWithValues: localEntries.map { ($0.id, $0) })
        let remoteIds = Set(remoteEntries.map(\.id))
        var result = remoteEntries.compactMap { remoteMemo in
            if let localMemo = localById[remoteMemo.id], localMemo.syncStatus == .pendingSync {
                return localMemo
            }
            return remoteMemo
        }
        localEntries.filter({ $0.syncStatus == .pendingSync && !remoteIds.contains($0.id) }).forEach {
            result.append($0)
        }
        return result.sorted { $0.createdAtMillis > $1.createdAtMillis }
    }

    private func updatePendingVideoMemoSyncState() {
        hasPendingVideoMemoSync = !memoStore.pendingEntries().isEmpty
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
