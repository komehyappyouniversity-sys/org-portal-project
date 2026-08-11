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
