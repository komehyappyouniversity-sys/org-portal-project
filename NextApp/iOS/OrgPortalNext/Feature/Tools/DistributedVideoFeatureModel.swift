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
        clientRequestId: String,
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
    @Published public private(set) var hasPendingVideoQuestionSync = false
    @Published public private(set) var videoRepeatSettings: [String: VideoRepeatSetting] = [:]
    @Published public var errorMessage: String?

    private let repository: any DistributedVideoRepository
    private let session: AppSession
    private let canViewMembersOnlyVideo: (String) -> Bool
    private let memoStore: VimeoMemoStore
    private let questionStore: VideoQuestionDraftStore
    private let repeatSettingRepository: (any VideoRepeatSettingRepository)?
    private let guestUserIdProvider: (any GuestUserIdProvider)?
    private let usageLogRecorder: UsageLogRecorder?
    private var syncingVideoQuestionRequestIds: Set<String> = []
    private var lastRecordedPositionBucket: [String: Int] = [:]

    public init(
        repository: any DistributedVideoRepository,
        session: AppSession,
        canViewMembersOnlyVideo: @escaping (String) -> Bool,
        memoStore: VimeoMemoStore = VimeoMemoStore(),
        questionStore: VideoQuestionDraftStore = VideoQuestionDraftStore(),
        repeatSettingRepository: (any VideoRepeatSettingRepository)? = nil,
        guestUserIdProvider: (any GuestUserIdProvider)? = nil,
        usageLogRecorder: UsageLogRecorder? = nil
    ) {
        self.repository = repository
        self.session = session
        self.canViewMembersOnlyVideo = canViewMembersOnlyVideo
        self.memoStore = memoStore
        self.questionStore = questionStore
        self.repeatSettingRepository = repeatSettingRepository
        self.guestUserIdProvider = guestUserIdProvider
        self.usageLogRecorder = usageLogRecorder
    }

    public func recordVideoDetailOpened(_ video: DistributedVideo) {
        recordUsage(.videoDetailOpened, targetId: video.id)
    }

    public func recordVideoPlaybackStarted(_ video: DistributedVideo, positionSeconds: Double) {
        recordUsage(
            .videoPlaybackStarted,
            targetId: video.id,
            positionSeconds: positionSeconds
        )
    }

    public func recordVideoPosition(_ video: DistributedVideo, positionSeconds: Double) {
        guard positionSeconds.isFinite, positionSeconds >= 30 else { return }
        let bucket = Int(positionSeconds / 30)
        guard bucket > 0, lastRecordedPositionBucket[video.id] != bucket else { return }
        lastRecordedPositionBucket[video.id] = bucket
        recordUsage(
            .videoPosition,
            targetId: video.id,
            positionSeconds: positionSeconds
        )
    }

    public func recordVideoCompleted(_ video: DistributedVideo, positionSeconds: Double) {
        lastRecordedPositionBucket[video.id] = nil
        recordUsage(
            .videoCompleted,
            targetId: video.id,
            positionSeconds: positionSeconds
        )
    }

    private func recordUsage(
        _ eventType: UsageLogEventType,
        targetId: String,
        positionSeconds: Double = 0
    ) {
        guard let usageLogRecorder,
              let userId = session.authenticatedUserId,
              let idToken = session.authenticationToken else { return }
        Task {
            _ = try? await usageLogRecorder.record(
                userId: userId,
                idToken: idToken,
                eventType: eventType,
                targetId: targetId,
                positionSeconds: positionSeconds
            )
        }
    }

    public func loadRepeatSetting(videoId: String) async {
        guard let repeatSettingRepository else { return }
        do {
            let setting = try await repeatSettingRepository.setting(videoId: videoId)
            if let setting {
                videoRepeatSettings[videoId] = setting
            } else {
                let userId = try localVideoSettingUserId()
                videoRepeatSettings[videoId] = VideoRepeatSetting(
                    userId: userId,
                    videoId: videoId,
                    isEnabled: false
                )
            }
        } catch {
            errorMessage = "リピート再生設定を読み込めませんでした。"
        }
    }

    public func isRepeatEnabled(videoId: String) -> Bool {
        videoRepeatSettings[videoId]?.isEnabled ?? false
    }

    public func setRepeatEnabled(videoId: String, isEnabled: Bool) async {
        guard let repeatSettingRepository else { return }
        do {
            let setting = VideoRepeatSetting(
                userId: try localVideoSettingUserId(),
                videoId: videoId,
                isEnabled: isEnabled,
                mode: .full,
                repeatStartSeconds: nil,
                repeatEndSeconds: nil
            )
            try await repeatSettingRepository.save(setting)
            videoRepeatSettings[videoId] = setting
        } catch {
            errorMessage = "リピート再生設定を保存できませんでした。"
        }
    }

    private func localVideoSettingUserId() throws -> String {
        if let authenticatedUserId = session.authenticatedUserId {
            return authenticatedUserId
        }
        return try guestUserIdProvider?.guestUserId() ?? "guest-local"
    }

    public func load() async {
        guard let communityId = session.selectedCommunityId,
              let memberUid = session.authenticatedUserId else {
            videos = []
            videoQuestions = []
            errorMessage = nil
            hasPendingVideoMemoSync = false
            hasPendingVideoQuestionSync = false
            return
        }
        videoQuestions = questionStore.questions(communityId: communityId, memberUid: memberUid)
        updatePendingVideoQuestionSyncState(communityId: communityId, memberUid: memberUid)
        guard let token = session.authenticationToken else {
            videos = []
            errorMessage = nil
            return
        }
        isLoading = true
        errorMessage = nil

        await synchronizePendingVideoQuestions(
            communityId: communityId,
            memberUid: memberUid,
            token: token
        )

        do {
            let allowed = canViewMembersOnlyVideo(communityId)
            let videosResult = try await repository.communityVideos(
                communityId: communityId,
                idToken: token
            )
            let questionsResult = try await repository.videoQuestions(
                communityId: communityId,
                memberUid: memberUid,
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
            let mergedQuestions = mergeVideoQuestions(
                local: questionStore.questions(communityId: communityId, memberUid: memberUid),
                remote: questionsResult
            )
            questionStore.replaceQuestions(
                communityId: communityId,
                memberUid: memberUid,
                with: mergedQuestions
            )
            videoQuestions = mergedQuestions
        } catch {
            errorMessage = "動画を取得できませんでした。"
            videoQuestions = questionStore.questions(communityId: communityId, memberUid: memberUid)
        }
        updatePendingVideoMemoSyncState()
        updatePendingVideoQuestionSyncState(communityId: communityId, memberUid: memberUid)
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

    public var unansweredQuestions: [VideoQuestion] {
        videoQuestions.filter { !$0.isAnswered }
    }

    public var answeredQuestions: [VideoQuestion] {
        videoQuestions.filter { $0.isAnswered }
    }

    @discardableResult
    public func submitVideoQuestion(
        _ video: DistributedVideo,
        memo: String,
        question: String,
        playbackSeconds: Double
    ) async -> Bool {
        let normalizedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuestion.isEmpty else {
            errorMessage = "質問を入力してください。"
            return false
        }
        guard
            let memberUid = session.authenticatedUserId,
            let communityId = session.selectedCommunityId
        else {
            return false
        }
        let clientRequestId = UUID().uuidString.lowercased()
        let draft = VideoQuestion(
            id: clientRequestId,
            communityId: communityId,
            memberUid: memberUid,
            videoId: video.id,
            videoTitle: video.title,
            playbackSeconds: playbackSeconds,
            memoText: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            questionText: normalizedQuestion,
            answerText: "",
            createdAt: Date(),
            answeredAt: nil,
            syncStatus: .draft,
            clientRequestId: clientRequestId
        )
        questionStore.save(draft)
        refreshLocalVideoQuestions(communityId: communityId, memberUid: memberUid)

        guard let token = session.authenticationToken else {
            questionStore.save(copyQuestion(draft, syncStatus: .failed))
            refreshLocalVideoQuestions(communityId: communityId, memberUid: memberUid)
            errorMessage = "オフラインのため質問を端末内に保存しました。"
            return true
        }
        let sent = await syncVideoQuestion(draft, token: token, reportResult: true)
        errorMessage = sent
            ? "質問を送信しました。"
            : "オフラインのため質問を端末内に保存しました。"
        return true
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

    private func synchronizePendingVideoQuestions(
        communityId: String,
        memberUid: String,
        token: String
    ) async {
        let pending = questionStore.pendingQuestions(
            communityId: communityId,
            memberUid: memberUid
        )
        for question in pending {
            _ = await syncVideoQuestion(question, token: token, reportResult: false)
        }
    }

    private func syncVideoQuestion(
        _ question: VideoQuestion,
        token: String,
        reportResult: Bool
    ) async -> Bool {
        let requestId = question.clientRequestId.isEmpty ? question.id : question.clientRequestId
        guard !syncingVideoQuestionRequestIds.contains(requestId) else { return true }
        syncingVideoQuestionRequestIds.insert(requestId)
        defer { syncingVideoQuestionRequestIds.remove(requestId) }

        let sending = copyQuestion(question, syncStatus: .sending)
        questionStore.save(sending)
        refreshLocalVideoQuestions(communityId: question.communityId, memberUid: question.memberUid)
        do {
            try await repository.saveVideoQuestion(
                communityId: question.communityId,
                memberUid: question.memberUid,
                video: questionVideo(question),
                memoText: question.memoText,
                questionText: question.questionText,
                playbackSeconds: question.playbackSeconds,
                clientRequestId: requestId,
                idToken: token
            )
            questionStore.save(copyQuestion(sending, syncStatus: .synced))
            refreshLocalVideoQuestions(communityId: question.communityId, memberUid: question.memberUid)
            return true
        } catch {
            questionStore.save(copyQuestion(sending, syncStatus: .failed))
            refreshLocalVideoQuestions(communityId: question.communityId, memberUid: question.memberUid)
            if reportResult {
                errorMessage = "オフラインのため質問を端末内に保存しました。"
            }
            return false
        }
    }

    private func refreshLocalVideoQuestions(communityId: String, memberUid: String) {
        videoQuestions = questionStore.questions(communityId: communityId, memberUid: memberUid)
        updatePendingVideoQuestionSyncState(communityId: communityId, memberUid: memberUid)
    }

    private func mergeVideoQuestions(
        local: [VideoQuestion],
        remote: [VideoQuestion]
    ) -> [VideoQuestion] {
        let remoteIdentities = Set(remote.map(questionIdentity))
        return (remote + local.filter { !remoteIdentities.contains(questionIdentity($0)) })
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    private func questionIdentity(_ question: VideoQuestion) -> String {
        question.clientRequestId.isEmpty ? question.id : question.clientRequestId
    }

    private func questionVideo(_ question: VideoQuestion) -> DistributedVideo {
        DistributedVideo(
            id: question.videoId,
            communityId: question.communityId,
            videoTitle: question.videoTitle,
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
            sortOrder: 0
        )
    }

    private func copyQuestion(
        _ question: VideoQuestion,
        syncStatus: VideoQuestionSyncStatus
    ) -> VideoQuestion {
        VideoQuestion(
            id: question.id,
            communityId: question.communityId,
            memberUid: question.memberUid,
            videoId: question.videoId,
            videoTitle: question.videoTitle,
            playbackSeconds: question.playbackSeconds,
            memoText: question.memoText,
            questionText: question.questionText,
            answerText: question.answerText,
            createdAt: question.createdAt,
            answeredAt: question.answeredAt,
            syncStatus: syncStatus,
            clientRequestId: question.clientRequestId
        )
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

    private func updatePendingVideoQuestionSyncState(communityId: String, memberUid: String) {
        hasPendingVideoQuestionSync = !questionStore.pendingQuestions(
            communityId: communityId,
            memberUid: memberUid
        ).isEmpty
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
