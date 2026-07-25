import Foundation

public struct FavoriteBookmark: Identifiable, Codable, Equatable, Sendable {
    public static let uncategorized = "未分類"

    public var id: UUID
    public var userId: String
    public var title: String
    public var url: String
    public var note: String
    public var category: String
    public var secondaryCategory: String
    public var tertiaryCategory: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: String = "guest-local",
        title: String,
        url: String,
        note: String = "",
        category: String = FavoriteBookmark.uncategorized,
        secondaryCategory: String = "",
        tertiaryCategory: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.url = url
        self.note = note
        self.category = category
        self.secondaryCategory = secondaryCategory
        self.tertiaryCategory = tertiaryCategory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var categoryPath: String {
        [category, secondaryCategory, tertiaryCategory]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    public func validated(now: Date? = nil) throws -> FavoriteBookmark {
        var value = self
        value.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        value.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        value.category = trimmedCategory.isEmpty ? Self.uncategorized : trimmedCategory
        value.secondaryCategory = secondaryCategory.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        value.tertiaryCategory = tertiaryCategory.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if value.secondaryCategory.isEmpty {
            value.tertiaryCategory = ""
        }
        if let now {
            value.updatedAt = now
        }

        guard !value.title.isEmpty else {
            throw FavoriteBookmarkValidationError.titleRequired
        }
        guard
            let components = URLComponents(string: value.url),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host?.isEmpty == false
        else {
            throw FavoriteBookmarkValidationError.invalidURL
        }
        return value
    }
}

public enum FavoriteBookmarkValidationError: LocalizedError, Equatable {
    case titleRequired
    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .titleRequired:
            "タイトルを入力してください。"
        case .invalidURL:
            "https:// または http:// で始まる正しいURLを入力してください。"
        }
    }
}
