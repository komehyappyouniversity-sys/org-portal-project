import CryptoKit
import Foundation
import Model

public enum FavoriteBookmarkBackupError: Error, Equatable {
    case invalidFormat
    case unsupportedVersion
}

public struct AppBackupImportSummary: Equatable, Sendable {
    public let schedules: Int
    public let diaries: Int
    public let cashDistributions: Int
    public let meetingMinutes: Int
    public let snsLinks: Int
    public let favorites: Int

    public var total: Int {
        schedules + diaries + cashDistributions + meetingMinutes + snsLinks + favorites
    }
}

public struct AppBackupExportResult: Equatable, Sendable {
    public let data: Data
    public let skippedMeetingMinutes: Int
}

public enum AppBackupError: LocalizedError, Equatable {
    case invalidFormat
    case unsupportedVersion
    case missingRecording
    case invalidAttachment

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "バックアップファイルを読み込めませんでした。"
        case .unsupportedVersion:
            "このバージョンでは読み込めないバックアップです。"
        case .missingRecording:
            "保存済み議事録の録音ファイルが見つからないため、バックアップできませんでした。"
        case .invalidAttachment:
            "バックアップ内の写真または録音ファイルが破損しています。"
        }
    }
}

private struct AppBackupEnvelope: Codable {
    let format: String
    let version: Int
    let exportedAtEpochMillis: Int64
    let diaryBackupBase64: String
    let cashDistributionBackupBase64: String
    let favoriteBookmarkBackupBase64: String
    let schedules: [AppBackupSchedule]
    let meetingMinutes: [AppBackupMeetingMinutes]
    let snsCustomLinks: [AppBackupSnsLink]
}

private struct AppBackupSchedule: Codable {
    let value: AppBackupScheduleValue
}

private struct AppBackupScheduleValue: Codable {
    let id: String
    let userId: String
    let title: String
    let startDateTime: Int64
    let endDateTime: Int64
    let location: String
    let timeOfDay: String
    let memo: String
    let isCompleted: Bool
    let recurrenceRule: AppBackupRecurrenceRule?
    let reminderSetting: AppBackupReminderSetting?
    let category: AppBackupScheduleCategory?
    let createdAt: Int64
    let updatedAt: Int64
}

private struct AppBackupRecurrenceRule: Codable {
    let frequency: String
    let interval: Int
    let endDate: Int64?
}

private struct AppBackupReminderSetting: Codable {
    let notifyBeforeMinutes: Int
    let isEnabled: Bool
}

private struct AppBackupScheduleCategory: Codable {
    let id: String
    let userId: String
    let name: String
    let colorHex: String
}

private struct AppBackupMeetingMinutes: Codable {
    let id: String
    let userId: String
    let title: String
    let recordingStartAtEpochMillis: Int64
    let recordingEndAtEpochMillis: Int64
    let recordingDurationSeconds: Int
    let transcriptText: String
    let createdAtEpochMillis: Int64
    let updatedAtEpochMillis: Int64
    let audioDataBase64: String
    let audioSha256: String
    let pdfDataBase64: String?
    let pdfSha256: String?
}

private struct AppBackupSnsLink: Codable {
    let value: SnsCustomLink
}

/// 端末内データを、アプリ削除前に1つのファイルへまとめるバックアップです。
/// Firebase上の会員・コミュニティ情報は対象外です。
@MainActor
public final class AppBackupService {
    public static let formatIdentifier = "org-portal-app-backup"
    public static let currentVersion = 1

    private let scheduleRepository: ScheduleRepository
    private let diaryService: DiaryBackupService
    private let cashService: CashDistributionBackupService
    private let meetingRepository: MeetingMinutesRepository
    private let recordingStore: LocalMeetingRecordingStore
    private let snsRepository: SnsCustomLinkRepository
    private let favoriteService: FavoriteBookmarkBackupService
    private let fileManager: FileManager

    public init(
        scheduleRepository: ScheduleRepository,
        diaryRepository: DiaryRepository,
        photoStore: DiaryPhotoStoring,
        cashDistributionRepository: CashDistributionRepository,
        meetingMinutesRepository: MeetingMinutesRepository,
        recordingStore: LocalMeetingRecordingStore,
        snsCustomLinkRepository: SnsCustomLinkRepository,
        favoriteBookmarkRepository: FavoriteBookmarkRepository,
        fileManager: FileManager = .default
    ) {
        self.scheduleRepository = scheduleRepository
        diaryService = DiaryBackupService(
            repository: diaryRepository,
            photoStore: photoStore
        )
        cashService = CashDistributionBackupService(
            repository: cashDistributionRepository
        )
        meetingRepository = meetingMinutesRepository
        self.recordingStore = recordingStore
        snsRepository = snsCustomLinkRepository
        favoriteService = FavoriteBookmarkBackupService(
            repository: favoriteBookmarkRepository
        )
        self.fileManager = fileManager
    }

    public func exportData(now: Date = .now) async throws -> AppBackupExportResult {
        let minutes = try await meetingRepository.fetchAll()
        var skippedMeetingMinutes = 0
        let minuteEntries = minutes.compactMap { value -> AppBackupMeetingMinutes? in
            let audioURL = URL(fileURLWithPath: value.audioFileLocalPath)
            guard
                fileManager.fileExists(atPath: audioURL.path),
                let audio = try? Data(contentsOf: audioURL),
                !audio.isEmpty,
                audio.count <= 500 * 1_024 * 1_024
            else {
                skippedMeetingMinutes += 1
                return nil
            }
            let pdf = value.pdfFileLocalPath.flatMap { path -> Data? in
                guard fileManager.fileExists(atPath: path) else { return nil }
                guard
                    let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                    !data.isEmpty,
                    data.count <= 100 * 1_024 * 1_024
                else {
                    return nil
                }
                return data
            }
            return AppBackupMeetingMinutes(
                id: value.id.uuidString,
                userId: value.userId,
                title: value.title,
                recordingStartAtEpochMillis: Self.epochMillis(value.recordingStartAt),
                recordingEndAtEpochMillis: Self.epochMillis(value.recordingEndAt),
                recordingDurationSeconds: value.recordingDurationSeconds,
                transcriptText: value.transcriptText,
                createdAtEpochMillis: Self.epochMillis(value.createdAt),
                updatedAtEpochMillis: Self.epochMillis(value.updatedAt),
                audioDataBase64: audio.base64EncodedString(),
                audioSha256: Self.sha256(audio),
                pdfDataBase64: pdf?.base64EncodedString(),
                pdfSha256: pdf.map { Self.sha256($0) }
            )
        }
        let envelope = AppBackupEnvelope(
            format: Self.formatIdentifier,
            version: Self.currentVersion,
            exportedAtEpochMillis: Self.epochMillis(now),
            diaryBackupBase64: try await diaryService.exportData(now: now)
                .base64EncodedString(),
            cashDistributionBackupBase64: try await cashService.exportData(now: now)
                .base64EncodedString(),
            favoriteBookmarkBackupBase64: try await favoriteService.exportData(now: now)
                .base64EncodedString(),
            schedules: try await scheduleRepository.fetchAll().map { schedule in
                AppBackupSchedule(
                    value: AppBackupScheduleValue(
                        id: schedule.id.uuidString,
                        userId: schedule.userId,
                        title: schedule.title,
                        startDateTime: Self.epochMillis(schedule.startDateTime),
                        endDateTime: Self.epochMillis(schedule.endDateTime),
                        location: schedule.location,
                        timeOfDay: schedule.timeOfDay.rawValue,
                        memo: schedule.memo,
                        isCompleted: schedule.isCompleted,
                        recurrenceRule: schedule.recurrenceRule.map {
                            AppBackupRecurrenceRule(
                                frequency: $0.frequency.rawValue,
                                interval: $0.interval,
                                endDate: $0.endDate.map(Self.epochMillis)
                            )
                        },
                        reminderSetting: schedule.reminderSetting.map {
                            AppBackupReminderSetting(
                                notifyBeforeMinutes: $0.notifyBeforeMinutes,
                                isEnabled: $0.isEnabled
                            )
                        },
                        category: schedule.category.map {
                            AppBackupScheduleCategory(
                                id: $0.id.uuidString,
                                userId: $0.userId,
                                name: $0.name,
                                colorHex: $0.colorHex
                            )
                        },
                        createdAt: Self.epochMillis(schedule.createdAt),
                        updatedAt: Self.epochMillis(schedule.updatedAt)
                    )
                )
            },
            meetingMinutes: minuteEntries,
            snsCustomLinks: try await snsRepository.fetchAll().map(AppBackupSnsLink.init)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return AppBackupExportResult(
            data: try encoder.encode(envelope),
            skippedMeetingMinutes: skippedMeetingMinutes
        )
    }

    public func importData(_ data: Data) async throws -> AppBackupImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        guard let envelope = try? decoder.decode(AppBackupEnvelope.self, from: data),
              envelope.format == Self.formatIdentifier else {
            throw AppBackupError.invalidFormat
        }
        guard envelope.version == Self.currentVersion else {
            throw AppBackupError.unsupportedVersion
        }
        guard
            let diaryData = Data(base64Encoded: envelope.diaryBackupBase64),
            let cashData = Data(base64Encoded: envelope.cashDistributionBackupBase64),
            let favoriteData = Data(base64Encoded: envelope.favoriteBookmarkBackupBase64)
        else {
            throw AppBackupError.invalidFormat
        }

        let diaryCount = try await diaryService.importData(diaryData)
        let cashCount = try await cashService.importData(cashData)
        let favoriteCount = try await favoriteService.importData(favoriteData)
        for schedule in envelope.schedules {
            let value = schedule.value
            guard
                let id = UUID(uuidString: value.id),
                let timeOfDay = ScheduleTimeOfDay(rawValue: value.timeOfDay)
            else {
                throw AppBackupError.invalidFormat
            }
            let recurrenceRule: RecurrenceRule?
            if let source = value.recurrenceRule {
                guard let frequency = RecurrenceFrequency(rawValue: source.frequency) else {
                    throw AppBackupError.invalidFormat
                }
                recurrenceRule = RecurrenceRule(
                    frequency: frequency,
                    interval: source.interval,
                    endDate: source.endDate.map(Self.date)
                )
            } else {
                recurrenceRule = nil
            }
            let category: ScheduleCategory?
            if let source = value.category {
                guard let categoryID = UUID(uuidString: source.id) else {
                    throw AppBackupError.invalidFormat
                }
                category = ScheduleCategory(
                    id: categoryID,
                    userId: source.userId,
                    name: source.name,
                    colorHex: source.colorHex
                )
            } else {
                category = nil
            }
            let restored = Schedule(
                id: id,
                userId: value.userId,
                title: value.title,
                startDateTime: Self.date(value.startDateTime),
                endDateTime: Self.date(value.endDateTime),
                location: value.location,
                timeOfDay: timeOfDay,
                memo: value.memo,
                isCompleted: value.isCompleted,
                recurrenceRule: recurrenceRule,
                reminderSetting: value.reminderSetting.map {
                    ReminderSetting(
                        notifyBeforeMinutes: $0.notifyBeforeMinutes,
                        isEnabled: $0.isEnabled
                    )
                },
                category: category,
                createdAt: Self.date(value.createdAt),
                updatedAt: Self.date(value.updatedAt)
            )
            try await scheduleRepository.save(try restored.validated())
        }
        for link in envelope.snsCustomLinks {
            try await snsRepository.save(try link.value.validated())
        }
        for entry in envelope.meetingMinutes {
            guard let id = UUID(uuidString: entry.id),
                  let audio = Data(base64Encoded: entry.audioDataBase64),
                  audio.count <= 500 * 1_024 * 1_024,
                  Self.sha256(audio) == entry.audioSha256 else {
                throw AppBackupError.invalidAttachment
            }
            let audioURL = try recordingStore.permanentAudioURL(id: id)
            try audio.write(to: audioURL, options: .atomic)

            var pdfPath: String?
            if let encodedPDF = entry.pdfDataBase64 {
                guard let pdf = Data(base64Encoded: encodedPDF),
                      pdf.count <= 100 * 1_024 * 1_024,
                      Self.sha256(pdf) == entry.pdfSha256 else {
                    throw AppBackupError.invalidAttachment
                }
                let pdfURL = audioURL.deletingLastPathComponent()
                    .appendingPathComponent("\(id.uuidString).pdf")
                try pdf.write(to: pdfURL, options: .atomic)
                pdfPath = pdfURL.path
            }
            try await meetingRepository.save(
                MeetingMinutes(
                    id: id,
                    userId: entry.userId,
                    title: entry.title,
                    recordingStartAt: Self.date(entry.recordingStartAtEpochMillis),
                    recordingEndAt: Self.date(entry.recordingEndAtEpochMillis),
                    recordingDurationSeconds: entry.recordingDurationSeconds,
                    audioFileLocalPath: audioURL.path,
                    transcriptText: entry.transcriptText,
                    pdfFileLocalPath: pdfPath,
                    createdAt: Self.date(entry.createdAtEpochMillis),
                    updatedAt: Self.date(entry.updatedAtEpochMillis)
                )
            )
        }
        return AppBackupImportSummary(
            schedules: envelope.schedules.count,
            diaries: diaryCount,
            cashDistributions: cashCount,
            meetingMinutes: envelope.meetingMinutes.count,
            snsLinks: envelope.snsCustomLinks.count,
            favorites: favoriteCount
        )
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func epochMillis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    private static func date(_ value: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(value) / 1_000)
    }
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
