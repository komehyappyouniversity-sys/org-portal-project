import Foundation
import SwiftData
import XCTest
@testable import DataLayer
import Model

@MainActor
final class DiaryBackupServiceTests: XCTestCase {
    func testBackupRestoresDiaryAndPhoto() async throws {
        let sourceContainer = try inMemoryContainer()
        let sourceRepository = SwiftDataDiaryRepository(modelContainer: sourceContainer)
        let sourceDirectory = temporaryDirectory("source")
        let sourcePhotos = LocalDiaryPhotoStore(rootDirectory: sourceDirectory)
        let id = UUID()
        let photoData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let photoReference = try sourcePhotos.saveJPEGData(photoData, diaryId: id)
        try await sourceRepository.save(
            Diary(
                id: id,
                userId: "guest",
                title: "バックアップ対象",
                body: "写真を含みます",
                mood: .veryGood,
                photoUrls: [photoReference],
                createdAt: Date(timeIntervalSince1970: 100),
                updatedAt: Date(timeIntervalSince1970: 200)
            )
        )
        let backup = try await DiaryBackupService(
            repository: sourceRepository,
            photoStore: sourcePhotos
        ).exportData(now: Date(timeIntervalSince1970: 300))

        let destinationContainer = try inMemoryContainer()
        let destinationRepository = SwiftDataDiaryRepository(
            modelContainer: destinationContainer
        )
        let destinationPhotos = LocalDiaryPhotoStore(
            rootDirectory: temporaryDirectory("destination")
        )
        let restoredCount = try await DiaryBackupService(
            repository: destinationRepository,
            photoStore: destinationPhotos
        ).importData(backup)

        XCTAssertEqual(restoredCount, 1)
        let restoredDiaries = try await destinationRepository.fetchAll()
        let restored = try XCTUnwrap(restoredDiaries.first)
        XCTAssertEqual(restored.id, id)
        XCTAssertEqual(restored.title, "バックアップ対象")
        XCTAssertEqual(restored.mood, .veryGood)
        XCTAssertEqual(restored.photoUrls.count, 1)
        XCTAssertEqual(
            try destinationPhotos.loadData(reference: restored.photoUrls[0]),
            photoData
        )
    }

    func testInvalidPhotoHashIsRejected() async throws {
        let repository = StubDiaryRepository()
        let photos = LocalDiaryPhotoStore(rootDirectory: temporaryDirectory("invalid"))
        let invalidJSON = """
        {
          "format": "org-portal-diary-backup",
          "version": 1,
          "exportedAtEpochMillis": 0,
          "diaries": [{
            "id": "\(UUID().uuidString)",
            "userId": "guest",
            "title": "改ざんデータ",
            "body": "",
            "mood": "neutral",
            "createdAtEpochMillis": 0,
            "updatedAtEpochMillis": 0,
            "photos": [{
              "dataBase64": "/9j/2Q==",
              "sha256": "incorrect"
            }]
          }]
        }
        """

        do {
            _ = try await DiaryBackupService(
                repository: repository,
                photoStore: photos
            ).importData(Data(invalidJSON.utf8))
            XCTFail("Invalid photo hash must be rejected")
        } catch {
            XCTAssertEqual(error as? DiaryBackupError, .invalidPhoto)
        }
    }

    func testImportKeepsUnrelatedLocalDiary() async throws {
        let sourceRepository = StubDiaryRepository()
        try await sourceRepository.save(
            Diary(userId: "guest", title: "バックアップ内の日記")
        )
        let sourcePhotos = LocalDiaryPhotoStore(
            rootDirectory: temporaryDirectory("merge-source")
        )
        let backup = try await DiaryBackupService(
            repository: sourceRepository,
            photoStore: sourcePhotos
        ).exportData()

        let destinationRepository = StubDiaryRepository()
        let unrelated = Diary(userId: "guest", title: "端末に残す日記")
        try await destinationRepository.save(unrelated)
        let destinationPhotos = LocalDiaryPhotoStore(
            rootDirectory: temporaryDirectory("merge-destination")
        )

        _ = try await DiaryBackupService(
            repository: destinationRepository,
            photoStore: destinationPhotos
        ).importData(backup)

        let restored = try await destinationRepository.fetchAll()
        XCTAssertEqual(Set(restored.map(\.title)), ["バックアップ内の日記", "端末に残す日記"])
    }

    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: DiaryRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func temporaryDirectory(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DiaryBackupTests-\(name)-\(UUID().uuidString)")
    }
}

@MainActor
private final class StubDiaryRepository: DiaryRepository {
    private var diaries: [Diary] = []

    func fetchAll() async throws -> [Diary] {
        diaries
    }

    func save(_ diary: Diary) async throws {
        diaries.removeAll { $0.id == diary.id }
        diaries.append(diary)
    }

    func delete(id: UUID) async throws {
        diaries.removeAll { $0.id == id }
    }
}
