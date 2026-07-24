import Foundation
import Model

@MainActor
public protocol DiaryRepository: AnyObject {
    func fetchAll() async throws -> [Diary]
    func save(_ diary: Diary) async throws
    func delete(id: UUID) async throws
}

public protocol DiaryPhotoStoring: Sendable {
    func saveJPEGData(_ data: Data, diaryId: UUID) throws -> String
    func loadData(reference: String) throws -> Data
    func delete(reference: String) throws
}
