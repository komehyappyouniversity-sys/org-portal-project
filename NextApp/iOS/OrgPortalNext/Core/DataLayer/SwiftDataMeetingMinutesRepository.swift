import Foundation
import Model
import SwiftData

@Model
public final class MeetingMinutesRecord {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var title: String
    public var recordingStartAt: Date
    public var recordingEndAt: Date
    public var recordingDurationSeconds: Int
    public var audioFileLocalPath: String
    public var transcriptText: String
    public var pdfFileLocalPath: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(minutes: MeetingMinutes) {
        id = minutes.id
        userId = minutes.userId
        title = minutes.title
        recordingStartAt = minutes.recordingStartAt
        recordingEndAt = minutes.recordingEndAt
        recordingDurationSeconds = minutes.recordingDurationSeconds
        audioFileLocalPath = minutes.audioFileLocalPath
        transcriptText = minutes.transcriptText
        pdfFileLocalPath = minutes.pdfFileLocalPath
        createdAt = minutes.createdAt
        updatedAt = minutes.updatedAt
    }

    public func update(from minutes: MeetingMinutes) {
        userId = minutes.userId
        title = minutes.title
        recordingStartAt = minutes.recordingStartAt
        recordingEndAt = minutes.recordingEndAt
        recordingDurationSeconds = minutes.recordingDurationSeconds
        audioFileLocalPath = minutes.audioFileLocalPath
        transcriptText = minutes.transcriptText
        pdfFileLocalPath = minutes.pdfFileLocalPath
        updatedAt = minutes.updatedAt
    }

    public func domainModel() -> MeetingMinutes {
        MeetingMinutes(
            id: id,
            userId: userId,
            title: title,
            recordingStartAt: recordingStartAt,
            recordingEndAt: recordingEndAt,
            recordingDurationSeconds: recordingDurationSeconds,
            audioFileLocalPath: audioFileLocalPath,
            transcriptText: transcriptText,
            pdfFileLocalPath: pdfFileLocalPath,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@MainActor
public final class SwiftDataMeetingMinutesRepository: MeetingMinutesRepository {
    private let context: ModelContext
    private let fileManager: FileManager

    public init(modelContainer: ModelContainer, fileManager: FileManager = .default) {
        context = modelContainer.mainContext
        self.fileManager = fileManager
    }

    public func fetchAll() async throws -> [MeetingMinutes] {
        let descriptor = FetchDescriptor<MeetingMinutesRecord>(
            sortBy: [SortDescriptor(\.recordingStartAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.domainModel() }
    }

    public func save(_ minutes: MeetingMinutes) async throws {
        let validated = try minutes.validated(now: minutes.updatedAt)
        let id = validated.id
        let descriptor = FetchDescriptor<MeetingMinutesRecord>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: validated)
        } else {
            context.insert(MeetingMinutesRecord(minutes: validated))
        }
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<MeetingMinutesRecord>(
            predicate: #Predicate { $0.id == id }
        )
        for record in try context.fetch(descriptor) {
            try? fileManager.removeItem(atPath: record.audioFileLocalPath)
            if let pdfPath = record.pdfFileLocalPath {
                try? fileManager.removeItem(atPath: pdfPath)
            }
            context.delete(record)
        }
        try context.save()
    }
}

public final class LocalMeetingRecordingStore: MeetingRecordingDraftStoring, @unchecked Sendable {
    private let fileManager: FileManager
    private let rootURL: URL
    private let draftURL: URL

    public init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        let base = rootURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.rootURL = base.appendingPathComponent("MeetingRecordings", isDirectory: true)
        draftURL = self.rootURL.appendingPathComponent("recording-draft.json")
        try? fileManager.createDirectory(
            at: self.rootURL,
            withIntermediateDirectories: true
        )
    }

    public func newTemporaryAudioURL(id: UUID = UUID()) throws -> URL {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL.appendingPathComponent("draft-\(id.uuidString).caf")
    }

    public func permanentAudioURL(id: UUID) throws -> URL {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL.appendingPathComponent("\(id.uuidString).caf")
    }

    public func moveAudio(from source: URL, minutesId: UUID) throws -> URL {
        let destination = try permanentAudioURL(id: minutesId)
        if source.standardizedFileURL != destination.standardizedFileURL {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: source, to: destination)
        }
        return destination
    }

    public func load() throws -> MeetingRecordingDraft? {
        guard fileManager.fileExists(atPath: draftURL.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            MeetingRecordingDraft.self,
            from: Data(contentsOf: draftURL)
        )
    }

    public func save(_ draft: MeetingRecordingDraft) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(draft)
        try data.write(to: draftURL, options: .atomic)
    }

    public func delete() throws {
        if fileManager.fileExists(atPath: draftURL.path) {
            try fileManager.removeItem(at: draftURL)
        }
    }

    public func discard(_ draft: MeetingRecordingDraft) throws {
        try? fileManager.removeItem(atPath: draft.audioFileLocalPath)
        try delete()
    }
}
