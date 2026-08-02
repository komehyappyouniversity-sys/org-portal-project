import DataLayer
import Foundation
import Model
import Session

@MainActor
public final class FavoriteBookmarkFeatureModel: ObservableObject {
    @Published public private(set) var favorites: [FavoriteBookmark] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var notice: String?
    @Published public private(set) var errorMessage: String?

    private let repository: FavoriteBookmarkRepository
    private let backupService: FavoriteBookmarkBackupService

    public init(repository: FavoriteBookmarkRepository) {
        self.repository = repository
        backupService = FavoriteBookmarkBackupService(repository: repository)
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            favorites = try await repository.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func save(
        existing: FavoriteBookmark?,
        title: String,
        url: String,
        note: String,
        category: String,
        secondaryCategory: String,
        tertiaryCategory: String
    ) async -> Bool {
        do {
            let now = Date()
            let value = try FavoriteBookmark(
                id: existing?.id ?? UUID(),
                userId: existing?.userId ?? "guest-local",
                title: title,
                url: url,
                note: note,
                category: category,
                secondaryCategory: secondaryCategory,
                tertiaryCategory: tertiaryCategory,
                createdAt: existing?.createdAt ?? now,
                updatedAt: now
            ).validated()
            try await repository.save(value)
            await load()
            notice = existing == nil ? "お気に入りを追加しました。" : "お気に入りを更新しました。"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func delete(_ favorite: FavoriteBookmark) async {
        do {
            try await repository.delete(id: favorite.id)
            await load()
            notice = "お気に入りを削除しました。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func exportBackup() async throws -> Data {
        try await backupService.exportData()
    }

    @discardableResult
    public func importBackup(_ data: Data) async throws -> Int {
        let count = try await backupService.importData(data)
        await load()
        return count
    }

    public func clearNotice() {
        notice = nil
    }

    public func clearError() {
        errorMessage = nil
    }
}

@MainActor
public final class FriendExchangeFeatureModel: ObservableObject {
    @Published public private(set) var contacts: [FriendContact] = []
    @Published public private(set) var histories: [UUID: [FriendInteractionHistory]] = [:]
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?

    private let repository: FriendExchangeRepository

    public init(repository: FriendExchangeRepository) {
        self.repository = repository
    }

    public func loadContacts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            contacts = try await repository.fetchContacts()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadHistories(friendId: UUID) async {
        do {
            histories[friendId] = try await repository.fetchHistories(friendId: friendId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveContact(_ contact: FriendContact) async -> Bool {
        do {
            try await repository.save(try contact.validated())
            await loadContacts()
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    public func saveHistory(_ history: FriendInteractionHistory) async -> Bool {
        do {
            try await repository.save(try history.validated())
            await loadHistories(friendId: history.friendId)
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    public func deleteContact(_ contact: FriendContact) async {
        do {
            try await repository.deleteContact(id: contact.id)
            histories[contact.id] = nil
            await loadContacts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteHistory(_ history: FriendInteractionHistory) async {
        do {
            try await repository.deleteHistory(id: history.id)
            await loadHistories(friendId: history.friendId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearError() {
        errorMessage = nil
    }

    private func message(for error: Error) -> String {
        guard let validation = error as? FriendExchangeValidationError else {
            return error.localizedDescription
        }
        switch validation {
        case .nameRequired:
            return "名前を入力してください。"
        case .historyContentRequired:
            return "メモ・写真・電話記録のいずれかを入力してください。"
        case .tooManyPhotos:
            return "写真は2枚まで登録できます。"
        }
    }
}

@MainActor
public final class PersonalVideoFeatureModel: ObservableObject {
    @Published public private(set) var videos: [PersonalVideo] = []
    @Published public private(set) var memosByVideo: [UUID: [VideoMemo]] = [:]
    @Published public private(set) var isLoading = false
    @Published public private(set) var notice: String?
    @Published public var errorMessage: String?

    private let repository: PersonalVideoRepository

    public init(repository: PersonalVideoRepository) {
        self.repository = repository
    }

    public func loadVideos() async {
        isLoading = true
        defer { isLoading = false }
        do {
            videos = try await repository.fetchVideos()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadMemos(videoId: UUID) async {
        do {
            memosByVideo[videoId] = try await repository.fetchMemos(videoId: videoId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveVideo(
        existing: PersonalVideo?,
        title: String,
        urlOrId: String,
        note: String,
        savedPositionSeconds: Int,
        category: String,
        secondaryCategory: String,
        tertiaryCategory: String
    ) async -> Bool {
        guard let providerVideoId = YouTubeVideoParser.videoId(from: urlOrId) else {
            errorMessage = "YouTubeのURLまたは動画IDを確認してください。"
            return false
        }
        do {
            let now = Date()
            let video = try PersonalVideo(
                id: existing?.id ?? UUID(),
                userId: existing?.userId ?? "guest-local",
                providerVideoId: providerVideoId,
                title: title,
                originalURL: "https://www.youtube.com/watch?v=\(providerVideoId)",
                note: note,
                savedPositionSeconds: max(0, savedPositionSeconds),
                category: category,
                secondaryCategory: secondaryCategory,
                tertiaryCategory: tertiaryCategory,
                createdAt: existing?.createdAt ?? now,
                updatedAt: now
            ).validated()
            try await repository.saveVideo(video)
            await loadVideos()
            notice = existing == nil ? "動画を登録しました。" : "動画を更新しました。"
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    public func saveMemo(videoId: UUID, text: String, positionSeconds: Int) async -> Bool {
        do {
            let now = Date()
            let memo = try VideoMemo(
                id: UUID(),
                userId: "guest-local",
                videoId: videoId,
                positionSeconds: max(0, positionSeconds),
                text: text,
                createdAt: now,
                updatedAt: now
            ).validated()
            try await repository.saveMemo(memo)
            await loadMemos(videoId: videoId)
            notice = "時間メモを保存しました。"
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    public func deleteVideo(_ video: PersonalVideo) async {
        do {
            try await repository.deleteVideo(id: video.id)
            memosByVideo[video.id] = nil
            await loadVideos()
            notice = "動画を削除しました。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteMemo(_ memo: VideoMemo) async {
        do {
            try await repository.deleteMemo(id: memo.id)
            await loadMemos(videoId: memo.videoId)
            notice = "時間メモを削除しました。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearNotice() { notice = nil }
    public func clearError() { errorMessage = nil }

    private func message(for error: Error) -> String {
        guard let validation = error as? PersonalVideoValidationError else {
            return error.localizedDescription
        }
        switch validation {
        case .titleRequired:
            return "タイトルを入力してください。"
        case .invalidYouTubeURL:
            return "YouTubeのURLまたは動画IDを確認してください。"
        case .memoRequired:
            return "メモを入力してください。"
        }
    }
}

@MainActor
public final class VideoQuestionFeatureModel: ObservableObject {
    @Published public private(set) var questions: [VideoQuestion] = []
    @Published public private(set) var currentCommunityId: String = ""
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSaving = false
    @Published public private(set) var notice: String?
    @Published public var errorMessage: String?
    @Published public var message: String?

    private let repository: VideoQuestionRepository
    private let session: AppSession

    public init(repository: VideoQuestionRepository, session: AppSession) {
        self.repository = repository
        self.session = session
    }

    public var cannotSend: Bool {
        session.authenticationToken == nil || (session.selectedCommunityId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    public func load() async {
        let communityIdRaw = session.selectedCommunityId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !communityIdRaw.isEmpty else {
            currentCommunityId = ""
            questions = []
            message = "コミュニティを選択すると質問一覧を確認できます。"
            isLoading = false
            return
        }
        guard let token = session.authenticationToken, !token.isEmpty else {
            currentCommunityId = communityIdRaw
            questions = []
            message = "質問一覧の取得にはログインが必要です。"
            isLoading = false
            return
        }

        currentCommunityId = communityIdRaw
        isLoading = true
        message = nil
        errorMessage = nil
        do {
            let list = try await repository.myQuestions(
                communityId: communityIdRaw,
                memberUid: session.authenticatedUserId ?? "",
                idToken: token
            )
            questions = list.sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.createdAt > $1.createdAt
            }
            isLoading = false
        } catch {
            isLoading = false
            questions = []
            message = "質問一覧を取得できませんでした。"
            errorMessage = error.localizedDescription
        }
    }

    public func sendQuestion(
        videoId: String,
        videoTitle: String,
        noteText: String,
        questionText: String,
        playbackSecondsText: String
    ) async {
        let trimmedVideoId = videoId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuestion = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMemberUid = session.authenticatedUserId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let communityId = session.selectedCommunityId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !communityId.isEmpty else {
            message = "先にコミュニティを選択してください。"
            return
        }
        guard let token = session.authenticationToken, !token.isEmpty else {
            message = "先にログインしてください。"
            return
        }
        guard !trimmedVideoId.isEmpty else {
            message = "動画IDを入力してください。"
            return
        }
        guard !trimmedQuestion.isEmpty else {
            message = "質問内容を入力してください。"
            return
        }
        guard !trimmedMemberUid.isEmpty else {
            message = "利用者情報が不足しています。再度ログインしてください。"
            return
        }

        let seconds = Int(playbackSecondsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        isSaving = true
        message = nil
        notice = nil
        errorMessage = nil

        do {
            try await repository.createQuestion(
                communityId: communityId,
                videoId: trimmedVideoId,
                videoType: "personal_youtube",
                videoTitle: videoTitle.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("動画"),
                memberUid: trimmedMemberUid,
                memberName: trimmedMemberUid,
                memberEmail: "",
                questionText: trimmedQuestion,
                noteText: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
                seconds: seconds,
                idToken: token
            )
            await load()
            notice = "質問を送信しました。"
            isSaving = false
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }

    public func clearNotice() {
        notice = nil
    }

    public func clearError() {
        errorMessage = nil
        message = nil
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
