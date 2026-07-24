import DataLayer
import Foundation
import Model

@MainActor
public final class DiaryFeatureModel: ObservableObject {
    @Published public private(set) var diaries: [Diary] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let repository: DiaryRepository
    private let photoStore: DiaryPhotoStoring
    private let backupService: DiaryBackupService

    public init(
        repository: DiaryRepository,
        photoStore: DiaryPhotoStoring
    ) {
        self.repository = repository
        self.photoStore = photoStore
        backupService = DiaryBackupService(
            repository: repository,
            photoStore: photoStore
        )
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            diaries = try await repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func save(
        _ diary: Diary,
        newPhotoData: [Data],
        removedPhotoReferences: Set<String>
    ) async throws {
        let remainingReferences = diary.photoUrls.filter {
            !removedPhotoReferences.contains($0)
        }
        guard remainingReferences.count + newPhotoData.count <= Diary.maximumPhotoCount else {
            throw DiaryValidationError.tooManyPhotos
        }

        var createdReferences: [String] = []
        do {
            for data in newPhotoData {
                createdReferences.append(
                    try photoStore.saveJPEGData(data, diaryId: diary.id)
                )
            }
            var value = diary
            value.photoUrls = remainingReferences + createdReferences
            value.updatedAt = .now
            try await repository.save(value)
            for reference in removedPhotoReferences {
                try? photoStore.delete(reference: reference)
            }
            await load()
        } catch {
            for reference in createdReferences {
                try? photoStore.delete(reference: reference)
            }
            throw error
        }
    }

    public func delete(_ diary: Diary) async {
        do {
            try await repository.delete(id: diary.id)
            for reference in diary.photoUrls {
                try? photoStore.delete(reference: reference)
            }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func photoData(reference: String) throws -> Data {
        try photoStore.loadData(reference: reference)
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
}
