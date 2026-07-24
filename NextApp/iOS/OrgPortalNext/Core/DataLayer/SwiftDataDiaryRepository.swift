import Foundation
import Model
import SwiftData

@Model
public final class DiaryRecord {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var title: String
    public var bodyText: String
    public var moodRaw: String
    public var photoUrlsData: Data
    public var createdAt: Date
    public var updatedAt: Date

    public init(diary: Diary) {
        id = diary.id
        userId = diary.userId
        title = diary.title
        bodyText = diary.body
        moodRaw = diary.mood.rawValue
        photoUrlsData = Self.encodePhotoUrls(diary.photoUrls)
        createdAt = diary.createdAt
        updatedAt = diary.updatedAt
    }

    public func update(from diary: Diary) {
        userId = diary.userId
        title = diary.title
        bodyText = diary.body
        moodRaw = diary.mood.rawValue
        photoUrlsData = Self.encodePhotoUrls(diary.photoUrls)
        updatedAt = diary.updatedAt
    }

    public func domainModel() -> Diary {
        Diary(
            id: id,
            userId: userId,
            title: title,
            body: bodyText,
            mood: DiaryMood(rawValue: moodRaw) ?? .neutral,
            photoUrls: Self.decodePhotoUrls(photoUrlsData),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func encodePhotoUrls(_ values: [String]) -> Data {
        (try? JSONEncoder().encode(values)) ?? Data("[]".utf8)
    }

    private static func decodePhotoUrls(_ data: Data) -> [String] {
        (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

@MainActor
public final class SwiftDataDiaryRepository: DiaryRepository {
    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        context = modelContainer.mainContext
    }

    public func fetchAll() async throws -> [Diary] {
        let descriptor = FetchDescriptor<DiaryRecord>(
            sortBy: [
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.title)
            ]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func save(_ diary: Diary) async throws {
        let validated = try diary.validated(now: diary.updatedAt)
        let id = validated.id
        let descriptor = FetchDescriptor<DiaryRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(DiaryRecord(diary: validated))
        }
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<DiaryRecord>(
            predicate: #Predicate { $0.id == id }
        )
        for record in try context.fetch(descriptor) {
            context.delete(record)
        }
        try context.save()
    }
}
