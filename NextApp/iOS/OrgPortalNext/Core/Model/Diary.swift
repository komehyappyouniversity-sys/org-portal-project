import Foundation

public enum DiaryMood: String, CaseIterable, Codable, Sendable {
    case veryGood
    case good
    case neutral
    case slightlyBad
    case bad

    public var localizationKey: String {
        switch self {
        case .veryGood: "diary.mood.very_good"
        case .good: "diary.mood.good"
        case .neutral: "diary.mood.neutral"
        case .slightlyBad: "diary.mood.slightly_bad"
        case .bad: "diary.mood.bad"
        }
    }
}

public struct Diary: Identifiable, Equatable, Codable, Sendable {
    public static let maximumPhotoCount = 5

    public var id: UUID
    public var userId: String
    public var title: String
    public var body: String
    public var mood: DiaryMood
    public var photoUrls: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        userId: String,
        title: String,
        body: String = "",
        mood: DiaryMood = .neutral,
        photoUrls: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.body = body
        self.mood = mood
        self.photoUrls = photoUrls
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validated(now: Date = .now) throws -> Diary {
        var result = self
        result.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        result.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        result.updatedAt = now

        guard !result.title.isEmpty else {
            throw DiaryValidationError.titleRequired
        }
        guard result.photoUrls.count <= Self.maximumPhotoCount else {
            throw DiaryValidationError.tooManyPhotos
        }
        return result
    }
}

public enum DiaryValidationError: Error, Equatable, Sendable {
    case titleRequired
    case tooManyPhotos

    public var localizationKey: String {
        switch self {
        case .titleRequired: "error.diary.title_required"
        case .tooManyPhotos: "error.diary.too_many_photos"
        }
    }
}
