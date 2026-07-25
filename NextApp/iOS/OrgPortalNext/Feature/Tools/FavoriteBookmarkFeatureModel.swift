import DataLayer
import Foundation
import Model

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
