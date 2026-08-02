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
    public let personalVideos: Int
    public let personalVideoMemos: Int
    public let friendContacts: Int
    public let friendHistories: Int

    public var total: Int {
        schedules + diaries + cashDistributions + meetingMinutes + snsLinks + favorites
            + personalVideos + personalVideoMemos
            + friendContacts + friendHistories
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
    let friendContacts: [AppBackupFriendContact]?
    let friendInteractionHistories: [AppBackupFriendInteractionHistory]?
    let personalVideoBackupBase64: String?
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

private struct AppBackupFriendContact: Codable {
    let id: String
    let userId: String
    let name: String
    let postalCode: String
    let prefecture: String
    let city: String
    let addressLine: String
    let birthDate: String?
    let phoneNumber: String
    let email: String
    let createdAtEpochMillis: Int64
    let updatedAtEpochMillis: Int64
}

private struct AppBackupFriendInteractionHistory: Codable {
    let id: String
    let friendId: String
    let interactionDateEpochMillis: Int64
    let memo: String
    let photoUrls: [String]
    let isPhoneCall: Bool
    let phoneNumber: String
    let createdAtEpochMillis: Int64
    let updatedAtEpochMillis: Int64
}

private struct AppBackupPersonalVideo: Codable {
    let id: String
    let userId: String
    let providerVideoId: String
    let title: String
    let originalUrl: String
    let note: String
    let savedPositionSeconds: Int
    let category: String
    let secondaryCategory: String
    let tertiaryCategory: String
    let createdAtEpochMillis: Int64
    let updatedAtEpochMillis: Int64
}

private struct AppBackupVideoMemo: Codable {
    let id: String
    let userId: String
    let videoId: String
    let positionSeconds: Int
    let memoText: String
    let createdAtEpochMillis: Int64
    let updatedAtEpochMillis: Int64
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
    private let personalVideoService: PersonalVideoBackupService
    private let friendExchangeRepository: FriendExchangeRepository
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
        personalVideoRepository: PersonalVideoRepository,
        friendExchangeRepository: FriendExchangeRepository,
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
        personalVideoService = PersonalVideoBackupService(repository: personalVideoRepository)
        self.friendExchangeRepository = friendExchangeRepository
        self.fileManager = fileManager
    }

    public func exportData(now: Date = .now) async throws -> AppBackupExportResult {
        let minutes = try await meetingRepository.fetchAll()
        let friendContacts = try await friendExchangeRepository.fetchContacts()
        var friendHistories: [FriendInteractionHistory] = []
        for contact in friendContacts {
            friendHistories += try await friendExchangeRepository.fetchHistories(friendId: contact.id)
        }
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
            personalVideoBackupBase64: try await personalVideoService.exportData(now: now)
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
            snsCustomLinks: try await snsRepository.fetchAll().map(AppBackupSnsLink.init),
            friendContacts: friendContacts.map {
                AppBackupFriendContact(
                    id: $0.id.uuidString,
                    userId: $0.userId,
                    name: $0.name,
                    postalCode: $0.postalCode,
                    prefecture: $0.prefecture,
                    city: $0.city,
                    addressLine: $0.addressLine,
                    birthDate: $0.birthDate.map(Self.dateOnlyString),
                    phoneNumber: $0.phoneNumber,
                    email: $0.email,
                    createdAtEpochMillis: Self.epochMillis($0.createdAt),
                    updatedAtEpochMillis: Self.epochMillis($0.updatedAt)
                )
            },
            friendInteractionHistories: friendHistories.map {
                AppBackupFriendInteractionHistory(
                    id: $0.id.uuidString,
                    friendId: $0.friendId.uuidString,
                    interactionDateEpochMillis: Self.epochMillis($0.interactionDate),
                    memo: $0.memo,
                    photoUrls: $0.photoUrls,
                    isPhoneCall: $0.isPhoneCall,
                    phoneNumber: $0.phoneNumber,
                    createdAtEpochMillis: Self.epochMillis($0.createdAt),
                    updatedAtEpochMillis: Self.epochMillis($0.updatedAt)
                )
            }
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

        let personalData = envelope.personalVideoBackupBase64.flatMap { Data(base64Encoded: $0) }
        if envelope.personalVideoBackupBase64 != nil && personalData == nil {
            throw AppBackupError.invalidFormat
        }

        let diaryCount = try await diaryService.importData(diaryData)
        let cashCount = try await cashService.importData(cashData)
        let favoriteCount = try await favoriteService.importData(favoriteData)
        let personalSummary = if let personalData {
            try await personalVideoService.importData(personalData)
        } else {
            PersonalVideoBackupImportSummary(videos: 0, memos: 0)
        }
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
        let friendContacts = envelope.friendContacts ?? []
        let friendHistories = envelope.friendInteractionHistories ?? []
        var importedFriendIDs = Set<UUID>()
        for entry in friendContacts {
            guard let id = UUID(uuidString: entry.id) else {
                throw AppBackupError.invalidFormat
            }
            let birthDate: Date?
            if let birthDateValue = entry.birthDate {
                birthDate = try Self.dateOnly(birthDateValue)
            } else {
                birthDate = nil
            }
            let updatedAt = Self.date(entry.updatedAtEpochMillis)
            let contact = FriendContact(
                id: id,
                userId: entry.userId,
                name: entry.name,
                postalCode: entry.postalCode,
                prefecture: entry.prefecture,
                city: entry.city,
                addressLine: entry.addressLine,
                birthDate: birthDate,
                phoneNumber: entry.phoneNumber,
                email: entry.email,
                createdAt: Self.date(entry.createdAtEpochMillis),
                updatedAt: updatedAt
            )
            let restored = try contact.validated(
                now: updatedAt,
                calendar: Self.backupCalendar
            )
            try await friendExchangeRepository.save(restored)
            importedFriendIDs.insert(id)
        }
        for entry in friendHistories {
            guard
                let id = UUID(uuidString: entry.id),
                let friendID = UUID(uuidString: entry.friendId),
                importedFriendIDs.contains(friendID)
            else {
                throw AppBackupError.invalidFormat
            }
            let updatedAt = Self.date(entry.updatedAtEpochMillis)
            let history = FriendInteractionHistory(
                id: id,
                friendId: friendID,
                interactionDate: Self.date(entry.interactionDateEpochMillis),
                memo: entry.memo,
                photoUrls: entry.photoUrls,
                isPhoneCall: entry.isPhoneCall,
                phoneNumber: entry.phoneNumber,
                createdAt: Self.date(entry.createdAtEpochMillis),
                updatedAt: updatedAt
            )
            try await friendExchangeRepository.save(try history.validated(now: updatedAt))
        }
        return AppBackupImportSummary(
            schedules: envelope.schedules.count,
            diaries: diaryCount,
            cashDistributions: cashCount,
            meetingMinutes: envelope.meetingMinutes.count,
            snsLinks: envelope.snsCustomLinks.count,
            favorites: favoriteCount,
            personalVideos: personalSummary.videos,
            personalVideoMemos: personalSummary.memos,
            friendContacts: friendContacts.count,
            friendHistories: friendHistories.count
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

    private static var backupCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func dateOnlyString(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    private static func dateOnly(_ value: String) throws -> Date {
        guard let date = dateOnlyFormatter.date(from: value) else {
            throw AppBackupError.invalidFormat
        }
        return date
    }

    private static var dateOnlyFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = backupCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

    private struct FavoriteBookmarkBackupEnvelope: Codable {
    let format: String
    let version: Int
    let exportedAtEpochMillis: Int64
    let favorites: [FavoriteBookmarkBackupEntry]
}

@MainActor
public final class PersonalVideoBackupService {
    public static let formatIdentifier = "org-portal-personal-videos-backup"
    public static let currentVersion = 1

    private let repository: PersonalVideoRepository

    public init(repository: PersonalVideoRepository) {
        self.repository = repository
    }

    public func exportData(now: Date = .now) async throws -> Data {
        let videos = try await repository.fetchVideos()
        let backupVideos = videos.map { video in
            AppBackupPersonalVideo(
                id: video.id.uuidString,
                userId: video.userId,
                providerVideoId: video.providerVideoId,
                title: video.title,
                originalUrl: video.originalURL,
                note: video.note,
                savedPositionSeconds: video.savedPositionSeconds,
                category: video.category,
                secondaryCategory: video.secondaryCategory,
                tertiaryCategory: video.tertiaryCategory,
                createdAtEpochMillis: Self.epochMillis(video.createdAt),
                updatedAtEpochMillis: Self.epochMillis(video.updatedAt)
            )
        }
        var memos: [AppBackupVideoMemo] = []
        for video in videos {
            memos += try await repository.fetchMemos(videoId: video.id).map {
                AppBackupVideoMemo(
                    id: $0.id.uuidString,
                    userId: $0.userId,
                    videoId: $0.videoId.uuidString,
                    positionSeconds: $0.positionSeconds,
                    memoText: $0.text,
                    createdAtEpochMillis: Self.epochMillis($0.createdAt),
                    updatedAtEpochMillis: Self.epochMillis($0.updatedAt)
                )
            }
        }
        let envelope = PersonalVideoBackupEnvelope(
            format: Self.formatIdentifier,
            version: Self.currentVersion,
            exportedAtEpochMillis: Self.epochMillis(now),
            videos: backupVideos,
            memos: memos
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    public func importData(_ data: Data) async throws -> PersonalVideoBackupImportSummary {
        let envelope: PersonalVideoBackupEnvelope
        do {
            envelope = try JSONDecoder().decode(PersonalVideoBackupEnvelope.self, from: data)
        } catch {
            throw AppBackupError.invalidFormat
        }
        guard envelope.format == Self.formatIdentifier else {
            throw AppBackupError.invalidFormat
        }
        guard (1...Self.currentVersion).contains(envelope.version) else {
            throw AppBackupError.unsupportedVersion
        }

        for entry in envelope.videos {
            guard let id = UUID(uuidString: entry.id) else {
                throw AppBackupError.invalidFormat
            }
            let video = PersonalVideo(
                id: id,
                userId: entry.userId,
                providerVideoId: entry.providerVideoId,
                title: entry.title,
                originalURL: entry.originalUrl,
                note: entry.note,
                savedPositionSeconds: entry.savedPositionSeconds,
                category: entry.category,
                secondaryCategory: entry.secondaryCategory,
                tertiaryCategory: entry.tertiaryCategory,
                createdAt: Self.date(entry.createdAtEpochMillis),
                updatedAt: Self.date(entry.updatedAtEpochMillis)
            )
            try await repository.saveVideo(video.validated())
        }
        var memoCount = 0
        for entry in envelope.memos {
            guard let id = UUID(uuidString: entry.id),
                  let videoId = UUID(uuidString: entry.videoId) else {
                throw AppBackupError.invalidFormat
            }
            let memo = VideoMemo(
                id: id,
                userId: entry.userId,
                videoId: videoId,
                positionSeconds: entry.positionSeconds,
                text: entry.memoText,
                createdAt: Self.date(entry.createdAtEpochMillis),
                updatedAt: Self.date(entry.updatedAtEpochMillis)
            )
            try await repository.saveMemo(memo.validated())
            memoCount += 1
        }
        return PersonalVideoBackupImportSummary(videos: envelope.videos.count, memos: memoCount)
    }
}

private struct PersonalVideoBackupEnvelope: Codable {
    let format: String
    let version: Int
    let exportedAtEpochMillis: Int64
    let videos: [AppBackupPersonalVideo]
    let memos: [AppBackupVideoMemo]
}

public struct PersonalVideoBackupImportSummary: Equatable, Sendable {
    public let videos: Int
    public let memos: Int
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
