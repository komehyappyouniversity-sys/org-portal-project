import Foundation
import Model

public enum FavoriteBookmarkBackupError: Error, Equatable {
    case invalidFormat
    case unsupportedVersion
}

private struct FavoriteBookmarkBackupEnvelope: Codable {
    let format: String
    let version: Int
    let exportedAtEpochMillis: Int64
    let favorites: [FavoriteBookmarkBackupEntry]
}

private struct FavoriteBookmarkBackupEntry: Codable {
    let id: String
    let userId: String
    let title: String
    let url: String
    let note: String
    let category: String
    let categoryPrimary: String?
    let categorySecondary: String?
    let categoryTertiary: String?
    let createdAtEpochMillis: Int64
    let updatedAtEpochMillis: Int64
}

@MainActor
public final class FavoriteBookmarkBackupService {
    public static let formatIdentifier = "org-portal-favorites-backup"
    public static let currentVersion = 2

    private let repository: FavoriteBookmarkRepository

    public init(repository: FavoriteBookmarkRepository) {
        self.repository = repository
    }

    public func exportData(now: Date = .now) async throws -> Data {
        let entries = try await repository.fetchAll().map { favorite in
            FavoriteBookmarkBackupEntry(
                id: favorite.id.uuidString,
                userId: favorite.userId,
                title: favorite.title,
                url: favorite.url,
                note: favorite.note,
                category: favorite.category,
                categoryPrimary: favorite.category,
                categorySecondary: favorite.secondaryCategory,
                categoryTertiary: favorite.tertiaryCategory,
                createdAtEpochMillis: Self.epochMillis(favorite.createdAt),
                updatedAtEpochMillis: Self.epochMillis(favorite.updatedAt)
            )
        }
        let envelope = FavoriteBookmarkBackupEnvelope(
            format: Self.formatIdentifier,
            version: Self.currentVersion,
            exportedAtEpochMillis: Self.epochMillis(now),
            favorites: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    @discardableResult
    public func importData(_ data: Data) async throws -> Int {
        let envelope: FavoriteBookmarkBackupEnvelope
        do {
            envelope = try JSONDecoder().decode(
                FavoriteBookmarkBackupEnvelope.self,
                from: data
            )
        } catch {
            throw FavoriteBookmarkBackupError.invalidFormat
        }
        guard envelope.format == Self.formatIdentifier else {
            throw FavoriteBookmarkBackupError.invalidFormat
        }
        guard (1...Self.currentVersion).contains(envelope.version) else {
            throw FavoriteBookmarkBackupError.unsupportedVersion
        }

        var restoredCount = 0
        for entry in envelope.favorites {
            guard let id = UUID(uuidString: entry.id) else {
                throw FavoriteBookmarkBackupError.invalidFormat
            }
            let value = FavoriteBookmark(
                id: id,
                userId: entry.userId,
                title: entry.title,
                url: entry.url,
                note: entry.note,
                category: entry.categoryPrimary ?? entry.category,
                secondaryCategory: entry.categorySecondary ?? "",
                tertiaryCategory: entry.categoryTertiary ?? "",
                createdAt: Self.date(entry.createdAtEpochMillis),
                updatedAt: Self.date(entry.updatedAtEpochMillis)
            )
            do {
                try await repository.save(try value.validated())
            } catch is FavoriteBookmarkValidationError {
                throw FavoriteBookmarkBackupError.invalidFormat
            }
            restoredCount += 1
        }
        return restoredCount
    }

    private static func epochMillis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    private static func date(_ epochMillis: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1_000)
    }
}
