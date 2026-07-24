import Foundation

public struct SnsCustomLink: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var userId: String
    public var title: String
    public var url: String
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        userId: String = "guest-local",
        title: String,
        url: String,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.url = url
        self.sortOrder = sortOrder
    }

    public func validated() throws -> SnsCustomLink {
        var value = self
        value.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.url = url.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.title.isEmpty else {
            throw SnsCustomLinkValidationError.titleRequired
        }
        guard
            let components = URLComponents(string: value.url),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host?.isEmpty == false
        else {
            throw SnsCustomLinkValidationError.invalidURL
        }
        guard value.sortOrder >= 0 else {
            throw SnsCustomLinkValidationError.invalidSortOrder
        }
        return value
    }
}

public enum SnsCustomLinkValidationError: LocalizedError, Equatable {
    case titleRequired
    case invalidURL
    case invalidSortOrder
    case maximumLinksReached

    public var errorDescription: String? {
        switch self {
        case .titleRequired:
            "リンク名を入力してください。"
        case .invalidURL:
            "https:// または http:// で始まる正しいURLを入力してください。"
        case .invalidSortOrder:
            "表示順を正しく設定してください。"
        case .maximumLinksReached:
            "独自リンクは2件まで登録できます。"
        }
    }
}
