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

public struct PersonalVideo: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var userId: String
    public var providerVideoId: String
    public var title: String
    public var originalURL: String
    public var note: String
    public var savedPositionSeconds: Int
    public var category: String
    public var secondaryCategory: String
    public var tertiaryCategory: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: String = "guest-local",
        providerVideoId: String,
        title: String,
        originalURL: String,
        note: String = "",
        savedPositionSeconds: Int = 0,
        category: String = FavoriteBookmark.uncategorized,
        secondaryCategory: String = "",
        tertiaryCategory: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.providerVideoId = providerVideoId
        self.title = title
        self.originalURL = originalURL
        self.note = note
        self.savedPositionSeconds = savedPositionSeconds
        self.category = category
        self.secondaryCategory = secondaryCategory
        self.tertiaryCategory = tertiaryCategory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var canonicalURL: URL {
        URL(string: "https://www.youtube.com/watch?v=\(providerVideoId)")!
    }

    public var timestampedURL: URL {
        guard savedPositionSeconds > 0 else { return canonicalURL }
        return URL(string: "\(canonicalURL.absoluteString)&t=\(savedPositionSeconds)s")!
    }

    public var thumbnailURL: URL {
        URL(string: "https://img.youtube.com/vi/\(providerVideoId)/hqdefault.jpg")!
    }

    public var categoryPath: String {
        [category, secondaryCategory, tertiaryCategory]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    public func validated(now: Date? = nil) throws -> PersonalVideo {
        var value = self
        value.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        value.originalURL = originalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        value.providerVideoId = providerVideoId.trimmingCharacters(in: .whitespacesAndNewlines)
        value.savedPositionSeconds = max(0, savedPositionSeconds)
        let primary = category.trimmingCharacters(in: .whitespacesAndNewlines)
        value.category = primary.isEmpty ? FavoriteBookmark.uncategorized : primary
        value.secondaryCategory = secondaryCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        value.tertiaryCategory = tertiaryCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.secondaryCategory.isEmpty { value.tertiaryCategory = "" }
        if let now { value.updatedAt = now }
        guard !value.title.isEmpty else { throw PersonalVideoValidationError.titleRequired }
        guard YouTubeVideoParser.isValidVideoId(value.providerVideoId) else {
            throw PersonalVideoValidationError.invalidYouTubeURL
        }
        return value
    }
}

public struct VideoMemo: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var userId: String
    public var videoId: UUID
    public var positionSeconds: Int
    public var text: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: String = "guest-local",
        videoId: UUID,
        positionSeconds: Int = 0,
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.videoId = videoId
        self.positionSeconds = max(0, positionSeconds)
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validated(now: Date? = nil) throws -> VideoMemo {
        var value = self
        value.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        value.positionSeconds = max(0, positionSeconds)
        if let now { value.updatedAt = now }
        guard !value.text.isEmpty else { throw PersonalVideoValidationError.memoRequired }
        return value
    }
}

public enum YouTubeVideoParser {
    public static func videoId(from input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidVideoId(value) { return value }
        guard let components = URLComponents(string: value),
              let host = components.host?.lowercased()
        else { return nil }
        var candidate: String?
        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            candidate = components.path.split(separator: "/").first.map(String.init)
        } else if host == "youtube.com" || host.hasSuffix(".youtube.com") {
            let parts = components.path.split(separator: "/").map(String.init)
            if components.path == "/watch" {
                candidate = components.queryItems?.first(where: { $0.name == "v" })?.value
            } else if let marker = parts.first, ["shorts", "embed"].contains(marker) {
                candidate = parts.dropFirst().first
            }
        }
        return candidate.flatMap { isValidVideoId($0) ? $0 : nil }
    }

    public static func isValidVideoId(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil
    }
}

public enum PersonalVideoValidationError: LocalizedError, Equatable {
    case titleRequired
    case invalidYouTubeURL
    case memoRequired

    public var errorDescription: String? {
        switch self {
        case .titleRequired: "タイトルを入力してください。"
        case .invalidYouTubeURL: "正しいYouTube URLまたは11文字の動画IDを入力してください。"
        case .memoRequired: "メモを入力してください。"
        }
    }
}

public enum VideoQuestionStatus: String, Codable, Sendable {
    case unanswered
    case answered

    public var label: String {
        switch self {
        case .unanswered: "未回答"
        case .answered: "回答済"
        }
    }

    static func parse(_ raw: String?) -> VideoQuestionStatus {
        guard let value = raw else { return .unanswered }
        if value == VideoQuestionStatus.answered.rawValue { return .answered }
        return .unanswered
    }
}

public struct VideoQuestion: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var organizationId: String
    public var videoId: String
    public var videoType: String
    public var videoTitle: String
    public var memberUid: String
    public var memberName: String
    public var memberEmail: String
    public var noteText: String
    public var questionText: String
    public var answerText: String
    public var status: VideoQuestionStatus
    public var seconds: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var answeredAt: Date?

    public init(
        id: String = UUID().uuidString,
        organizationId: String,
        videoId: String,
        videoType: String = "personal_youtube",
        videoTitle: String,
        memberUid: String,
        memberName: String,
        memberEmail: String,
        noteText: String = "",
        questionText: String,
        answerText: String = "",
        status: VideoQuestionStatus = .unanswered,
        seconds: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        answeredAt: Date? = nil
    ) {
        self.id = id
        self.organizationId = organizationId
        self.videoId = videoId
        self.videoType = videoType
        self.videoTitle = videoTitle
        self.memberUid = memberUid
        self.memberName = memberName
        self.memberEmail = memberEmail
        self.noteText = noteText
        self.questionText = questionText
        self.answerText = answerText
        self.status = status
        self.seconds = seconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.answeredAt = answeredAt
    }

    public var formattedSeconds: String {
        let safe = max(0, seconds)
        let minute = safe / 60
        let second = safe % 60
        let hour = minute / 60
        let remainingMinute = minute % 60
        if hour > 0 {
            return String(format: "%d:%02d:%02d", hour, remainingMinute, second)
        }
        return String(format: "%d:%02d", minute, second)
    }
}
