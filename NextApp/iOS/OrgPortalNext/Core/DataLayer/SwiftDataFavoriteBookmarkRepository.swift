import Foundation
import Model
import SwiftData

@Model
public final class FavoriteBookmarkRecord {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var title: String
    public var url: String
    public var note: String
    public var category: String
    public var secondaryCategory: String?
    public var tertiaryCategory: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(favorite: FavoriteBookmark) {
        id = favorite.id
        userId = favorite.userId
        title = favorite.title
        url = favorite.url
        note = favorite.note
        category = favorite.category
        secondaryCategory = favorite.secondaryCategory
        tertiaryCategory = favorite.tertiaryCategory
        createdAt = favorite.createdAt
        updatedAt = favorite.updatedAt
    }

    public func update(from favorite: FavoriteBookmark) {
        userId = favorite.userId
        title = favorite.title
        url = favorite.url
        note = favorite.note
        category = favorite.category
        secondaryCategory = favorite.secondaryCategory
        tertiaryCategory = favorite.tertiaryCategory
        createdAt = favorite.createdAt
        updatedAt = favorite.updatedAt
    }

    public func domainModel() -> FavoriteBookmark {
        FavoriteBookmark(
            id: id,
            userId: userId,
            title: title,
            url: url,
            note: note,
            category: category,
            secondaryCategory: secondaryCategory ?? "",
            tertiaryCategory: tertiaryCategory ?? "",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@MainActor
public final class SwiftDataFavoriteBookmarkRepository: FavoriteBookmarkRepository {
    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        context = modelContainer.mainContext
    }

    public func fetchAll() async throws -> [FavoriteBookmark] {
        let descriptor = FetchDescriptor<FavoriteBookmarkRecord>(
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.title),
            ]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func save(_ favorite: FavoriteBookmark) async throws {
        let validated = try favorite.validated()
        let id = validated.id
        let descriptor = FetchDescriptor<FavoriteBookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(FavoriteBookmarkRecord(favorite: validated))
        }
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<FavoriteBookmarkRecord>(
            predicate: #Predicate { $0.id == id }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }
}

@Model
public final class PersonalVideoRecord {
    @Attribute(.unique) public var id: UUID
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

    public init(video: PersonalVideo) {
        id = video.id
        userId = video.userId
        providerVideoId = video.providerVideoId
        title = video.title
        originalURL = video.originalURL
        note = video.note
        savedPositionSeconds = video.savedPositionSeconds
        category = video.category
        secondaryCategory = video.secondaryCategory
        tertiaryCategory = video.tertiaryCategory
        createdAt = video.createdAt
        updatedAt = video.updatedAt
    }

    public func update(from video: PersonalVideo) {
        userId = video.userId
        providerVideoId = video.providerVideoId
        title = video.title
        originalURL = video.originalURL
        note = video.note
        savedPositionSeconds = video.savedPositionSeconds
        category = video.category
        secondaryCategory = video.secondaryCategory
        tertiaryCategory = video.tertiaryCategory
        createdAt = video.createdAt
        updatedAt = video.updatedAt
    }

    public func domainModel() -> PersonalVideo {
        PersonalVideo(
            id: id, userId: userId, providerVideoId: providerVideoId, title: title,
            originalURL: originalURL, note: note, savedPositionSeconds: savedPositionSeconds,
            category: category, secondaryCategory: secondaryCategory,
            tertiaryCategory: tertiaryCategory, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

@Model
public final class VideoMemoRecord {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var videoId: UUID
    public var positionSeconds: Int
    public var text: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(memo: VideoMemo) {
        id = memo.id
        userId = memo.userId
        videoId = memo.videoId
        positionSeconds = memo.positionSeconds
        text = memo.text
        createdAt = memo.createdAt
        updatedAt = memo.updatedAt
    }

    public func update(from memo: VideoMemo) {
        userId = memo.userId
        videoId = memo.videoId
        positionSeconds = memo.positionSeconds
        text = memo.text
        createdAt = memo.createdAt
        updatedAt = memo.updatedAt
    }

    public func domainModel() -> VideoMemo {
        VideoMemo(
            id: id, userId: userId, videoId: videoId, positionSeconds: positionSeconds,
            text: text, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

@MainActor
public final class SwiftDataPersonalVideoRepository: PersonalVideoRepository {
    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        context = modelContainer.mainContext
    }

    public func fetchVideos() async throws -> [PersonalVideo] {
        try context.fetch(
            FetchDescriptor<PersonalVideoRecord>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).map { $0.domainModel() }
    }

    public func fetchMemos(videoId: UUID) async throws -> [VideoMemo] {
        let id = videoId
        return try context.fetch(
            FetchDescriptor<VideoMemoRecord>(
                predicate: #Predicate { $0.videoId == id },
                sortBy: [SortDescriptor(\.positionSeconds), SortDescriptor(\.createdAt)]
            )
        ).map { $0.domainModel() }
    }

    public func saveVideo(_ video: PersonalVideo) async throws {
        let value = try video.validated()
        let id = value.id
        let providerId = value.providerVideoId
        let descriptor = FetchDescriptor<PersonalVideoRecord>(
            predicate: #Predicate { $0.id == id || $0.providerVideoId == providerId }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: value)
        } else {
            context.insert(PersonalVideoRecord(video: value))
        }
        try context.save()
    }

    public func saveMemo(_ memo: VideoMemo) async throws {
        let value = try memo.validated()
        let id = value.id
        let descriptor = FetchDescriptor<VideoMemoRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: value)
        } else {
            context.insert(VideoMemoRecord(memo: value))
        }
        try context.save()
    }

    public func deleteVideo(id: UUID) async throws {
        for memo in try context.fetch(
            FetchDescriptor<VideoMemoRecord>(predicate: #Predicate { $0.videoId == id })
        ) { context.delete(memo) }
        for video in try context.fetch(
            FetchDescriptor<PersonalVideoRecord>(predicate: #Predicate { $0.id == id })
        ) { context.delete(video) }
        try context.save()
    }

    public func deleteMemo(id: UUID) async throws {
        for memo in try context.fetch(
            FetchDescriptor<VideoMemoRecord>(predicate: #Predicate { $0.id == id })
        ) { context.delete(memo) }
        try context.save()
    }
}
