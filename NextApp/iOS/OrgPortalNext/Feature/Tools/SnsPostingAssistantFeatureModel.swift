import DataLayer
import Foundation
import Model

@MainActor
public final class SnsPostingAssistantFeatureModel: ObservableObject {
    @Published public private(set) var customLinks: [SnsCustomLink] = []
    @Published public private(set) var notice: String?
    @Published public private(set) var errorMessage: String?

    private let repository: SnsCustomLinkRepository

    public init(repository: SnsCustomLinkRepository) {
        self.repository = repository
    }

    public func load() async {
        do {
            customLinks = try await repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func save(
        existing: SnsCustomLink?,
        title: String,
        url: String
    ) async -> Bool {
        do {
            if existing == nil, customLinks.count >= 2 {
                throw SnsCustomLinkValidationError.maximumLinksReached
            }
            let sortOrder = existing?.sortOrder ?? customLinks.count
            let value = try SnsCustomLink(
                id: existing?.id ?? UUID(),
                userId: existing?.userId ?? "guest-local",
                title: title,
                url: url,
                sortOrder: sortOrder
            ).validated()
            try await repository.save(value)
            await load()
            notice = existing == nil ? "独自リンクを追加しました。" : "独自リンクを更新しました。"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func delete(_ link: SnsCustomLink) async {
        do {
            try await repository.delete(id: link.id)
            await load()
            notice = "独自リンクを削除しました。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func showNotice(_ message: String) {
        notice = message
    }

    public func clearNotice() {
        notice = nil
    }

    public func clearError() {
        errorMessage = nil
    }
}
