import CryptoKit
import Foundation
import Model

public enum DiaryBackupError: Error, Equatable {
    case invalidFormat
    case unsupportedVersion
    case invalidPhoto
}

private struct DiaryBackupEnvelope: Codable {
    let format: String
    let version: Int
    let exportedAtEpochMillis: Int64
    let diaries: [DiaryBackupEntry]
}

private struct DiaryBackupEntry: Codable {
    let id: String
    let userId: String
    let title: String
    let body: String
    let mood: String
    let createdAtEpochMillis: Int64
    let updatedAtEpochMillis: Int64
    let photos: [DiaryBackupPhoto]
}

private struct DiaryBackupPhoto: Codable {
    let dataBase64: String
    let sha256: String
}

@MainActor
public final class DiaryBackupService {
    public static let formatIdentifier = "org-portal-diary-backup"
    public static let currentVersion = 1

    private let repository: DiaryRepository
    private let photoStore: DiaryPhotoStoring

    public init(repository: DiaryRepository, photoStore: DiaryPhotoStoring) {
        self.repository = repository
        self.photoStore = photoStore
    }

    public func exportData(now: Date = .now) async throws -> Data {
        let diaries = try await repository.fetchAll()
        let entries = try diaries.map { diary in
            let photos = try diary.photoUrls.map { reference in
                let data = try photoStore.loadData(reference: reference)
                return DiaryBackupPhoto(
                    dataBase64: data.base64EncodedString(),
                    sha256: Self.sha256(data)
                )
            }
            return DiaryBackupEntry(
                id: diary.id.uuidString,
                userId: diary.userId,
                title: diary.title,
                body: diary.body,
                mood: diary.mood.rawValue,
                createdAtEpochMillis: Self.epochMillis(diary.createdAt),
                updatedAtEpochMillis: Self.epochMillis(diary.updatedAt),
                photos: photos
            )
        }
        let envelope = DiaryBackupEnvelope(
            format: Self.formatIdentifier,
            version: Self.currentVersion,
            exportedAtEpochMillis: Self.epochMillis(now),
            diaries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    @discardableResult
    public func importData(_ data: Data) async throws -> Int {
        let envelope: DiaryBackupEnvelope
        do {
            envelope = try JSONDecoder().decode(DiaryBackupEnvelope.self, from: data)
        } catch {
            throw DiaryBackupError.invalidFormat
        }
        guard envelope.format == Self.formatIdentifier else {
            throw DiaryBackupError.invalidFormat
        }
        guard envelope.version == Self.currentVersion else {
            throw DiaryBackupError.unsupportedVersion
        }

        let existingById = Dictionary(
            uniqueKeysWithValues: try await repository.fetchAll().map { ($0.id, $0) }
        )
        var restoredCount = 0
        for entry in envelope.diaries {
            guard let id = UUID(uuidString: entry.id),
                  let mood = DiaryMood(rawValue: entry.mood),
                  entry.photos.count <= Diary.maximumPhotoCount else {
                throw DiaryBackupError.invalidFormat
            }

            let decodedPhotos = try entry.photos.map { photo -> Data in
                guard let photoData = Data(base64Encoded: photo.dataBase64),
                      photoData.count <= 10 * 1_024 * 1_024,
                      Self.sha256(photoData) == photo.sha256 else {
                    throw DiaryBackupError.invalidPhoto
                }
                return photoData
            }

            var newReferences: [String] = []
            do {
                for photoData in decodedPhotos {
                    newReferences.append(
                        try photoStore.saveJPEGData(photoData, diaryId: id)
                    )
                }
                let diary = Diary(
                    id: id,
                    userId: entry.userId,
                    title: entry.title,
                    body: entry.body,
                    mood: mood,
                    photoUrls: newReferences,
                    createdAt: Self.date(entry.createdAtEpochMillis),
                    updatedAt: Self.date(entry.updatedAtEpochMillis)
                )
                try await repository.save(diary)
                for oldReference in existingById[id]?.photoUrls ?? [] {
                    try? photoStore.delete(reference: oldReference)
                }
                restoredCount += 1
            } catch {
                for reference in newReferences {
                    try? photoStore.delete(reference: reference)
                }
                throw error
            }
        }
        return restoredCount
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func epochMillis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    private static func date(_ epochMillis: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1_000)
    }
}
